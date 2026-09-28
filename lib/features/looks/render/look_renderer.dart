import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/frame_composite.dart';
import 'package:shuttr/features/looks/render/shader_uniforms.dart';

class RenderResult {
  const new({required this.outputPath, required this.renderMs});
  final String outputPath;
  final int renderMs;
}

/// Renders a captured/imported photo through a [LookSpec].
///
/// Pipeline (docs/ARCHITECTURE.md "Photo pipeline"):
/// native decode (downsampled) → crop to aspect → two cheap blur passes
/// (small blur for sharpen/softness, a bright/heavy blur approximating
/// bloom) → the look.frag uber-shader → frame + date stamp composited on a
/// Canvas (docs/LOOKS.md stage 10) → native JPEG encode.
class LookRenderer {
  new({required this._codec});

  final CodecChannel _codec;

  static ui.FragmentProgram? _lookProgramCache;
  static final Map<String, ui.Image> _lutCache = {};
  static final Map<String, ui.Image> _frameCache = {};

  Future<RenderResult> render({
    required String sourcePath,
    required LookSpec spec,
    required String outPath,
    bool flashFired = false,
    double? seed,
    DateStampSettings? dateStamp,
    DateTime? captureDate,
  }) async {
    final stopwatch = Stopwatch()..start();

    final decoded = await _codec.decodeForRender(
      sourcePath,
      spec.outputLongEdge,
    );
    final source = await _imageFromRgba(
      decoded.rgba,
      decoded.width,
      decoded.height,
    );

    final cropped = _cropToAspect(source, spec.aspectRatio);
    source.dispose();

    final blurSmall = await _blur(cropped, sigma: 2.5);
    // Bloom source: a heavy blur of the whole frame at quarter resolution.
    // This is a cheap approximation of a bright-pass + blur; refine with a
    // real threshold pass if bloom/halation don't read convincingly enough
    // once tuned against reference shots (docs/LOOKS.md).
    final bloomSource = await _blur(cropped, sigma: 16, downscale: 4);

    final lut = await _loadLut(spec.lutAsset);

    final graded = await _applyLookShader(
      image: cropped,
      blurSmall: blurSmall,
      bloom: bloomSource,
      lut: lut,
      spec: spec,
      flashFired: flashFired,
      seed: seed ?? math.Random().nextDouble() * 1000,
    );

    cropped.dispose();
    blurSmall.dispose();
    bloomSource.dispose();

    final composed = await _compositeOverlays(
      graded,
      spec: spec,
      dateStamp: dateStamp,
      captureDate: captureDate ?? DateTime.now(),
    );
    if (!identical(composed, graded)) {
      graded.dispose();
    }

    final byteData = await composed.toByteData();
    final width = composed.width;
    final height = composed.height;
    composed.dispose();

    if (byteData == null) {
      throw StateError('Failed to read rendered image bytes');
    }

    await _codec.encodeJpeg(
      rgba: byteData.buffer.asUint8List(),
      width: width,
      height: height,
      quality: spec.jpegQuality,
      outPath: outPath,
    );

    stopwatch.stop();
    return RenderResult(
      outputPath: outPath,
      renderMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<ui.Image> _imageFromRgba(
    Uint8List rgba,
    int width,
    int height,
  ) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  ui.Image _cropToAspect(ui.Image src, double aspectRatio) {
    final srcW = src.width.toDouble();
    final srcH = src.height.toDouble();
    final srcAspect = srcW / srcH;

    var cropW = srcW;
    var cropH = srcH;
    if (srcAspect > aspectRatio) {
      cropW = srcH * aspectRatio;
    } else {
      cropH = srcW / aspectRatio;
    }
    final left = (srcW - cropW) / 2;
    final top = (srcH - cropH) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final srcRect = ui.Rect.fromLTWH(left, top, cropW, cropH);
    final dstRect = ui.Rect.fromLTWH(0, 0, cropW, cropH);
    canvas.drawImageRect(src, srcRect, dstRect, ui.Paint());
    final picture = recorder.endRecording();
    final image = picture.toImageSync(cropW.round(), cropH.round());
    picture.dispose();
    return image;
  }

  Future<ui.Image> _blur(
    ui.Image src, {
    required double sigma,
    int downscale = 1,
  }) async {
    final w = (src.width / downscale).round().clamp(1, src.width);
    final h = (src.height / downscale).round().clamp(1, src.height);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma / downscale,
        sigmaY: sigma / downscale,
        tileMode: ui.TileMode.decal,
      );
    canvas.drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    return image;
  }

  Future<ui.Image> _loadLut(String? assetPath) async {
    final path = assetPath ?? 'assets/luts/identity.png';
    final cached = _lutCache[path];
    if (cached != null) return cached;

    final bytes = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
    );
    final frame = await codec.getNextFrame();
    _lutCache[path] = frame.image;
    return frame.image;
  }

  Future<ui.Image> _loadFrame(String assetPath) async {
    final cached = _frameCache[assetPath];
    if (cached != null) return cached;

    final bytes = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
    );
    final frame = await codec.getNextFrame();
    _frameCache[assetPath] = frame.image;
    return frame.image;
  }

  /// Composites the look's frame asset (if any) and date stamp (if enabled)
  /// onto [image]. Returns [image] itself, untouched, when neither applies
  /// — the common case (free looks, no date stamp by default) skips the
  /// extra canvas pass entirely.
  Future<ui.Image> _compositeOverlays(
    ui.Image image, {
    required LookSpec spec,
    required DateStampSettings? dateStamp,
    required DateTime captureDate,
  }) async {
    final needsDateStamp = dateStamp != null && dateStamp.enabled;
    final frameAsset = spec.frameAsset;
    if (frameAsset == null && !needsDateStamp) return image;

    final photoW = image.width.toDouble();
    final photoH = image.height.toDouble();

    ui.Image? frame;
    var canvasSize = ui.Size(photoW, photoH);
    var windowRect = ui.Rect.fromLTWH(0, 0, photoW, photoH);
    if (frameAsset != null) {
      frame = await _loadFrame(frameAsset);
      canvasSize = frameCanvasSize(photoWidth: photoW, photoHeight: photoH);
      windowRect = frameWindowRect(photoWidth: photoW, photoHeight: photoH);
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    if (frame != null) {
      canvas.drawImageRect(
        frame,
        ui.Rect.fromLTWH(
          0,
          0,
          frame.width.toDouble(),
          frame.height.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        ui.Paint(),
      );
    }
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, photoW, photoH),
      windowRect,
      ui.Paint(),
    );

    if (needsDateStamp) {
      paintDateStamp(canvas, canvasSize, captureDate, dateStamp);
    }

    final picture = recorder.endRecording();
    final result = picture.toImageSync(
      canvasSize.width.round(),
      canvasSize.height.round(),
    );
    picture.dispose();
    return result;
  }

  Future<ui.FragmentProgram> _loadLookProgram() {
    final cached = _lookProgramCache;
    if (cached != null) return Future.value(cached);
    return ui.FragmentProgram.fromAsset('shaders/look.frag').then((program) {
      _lookProgramCache = program;
      return program;
    });
  }

  Future<ui.Image> _applyLookShader({
    required ui.Image image,
    required ui.Image blurSmall,
    required ui.Image bloom,
    required ui.Image lut,
    required LookSpec spec,
    required bool flashFired,
    required double seed,
  }) async {
    final program = await _loadLookProgram();
    final shader = program.fragmentShader();

    bindLookUniforms(
      shader,
      spec: spec,
      width: image.width.toDouble(),
      height: image.height.toDouble(),
      flashFired: flashFired,
      seed: seed,
    );
    bindLookSamplers(
      shader,
      image: image,
      blurSmall: blurSmall,
      bloom: bloom,
      lut: lut,
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..shader = shader;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final result = picture.toImageSync(image.width, image.height);
    picture.dispose();
    shader.dispose();
    return result;
  }
}
