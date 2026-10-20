import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/happy_accidents.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/asset_image_cache.dart';
import 'package:shuttr/features/looks/render/develop.dart';
import 'package:shuttr/features/looks/render/face_finder.dart';
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
/// native decode (downsampled) → develop (per-shot levels + tint, applied
/// in the crop pass) → crop to aspect → two cheap blur passes
/// (small blur for sharpen/softness, a bright/heavy blur approximating
/// bloom) → the look.frag uber-shader → frame + date stamp composited on a
/// Canvas (docs/LOOKS.md stage 10) → native JPEG encode.
class LookRenderer {
  new({required this._codec, this._faceFinder});

  /// The real device pipeline: native codec + on-device face detection.
  factory device() {
    final codec = MethodChannelCodec();
    return LookRenderer(
      codec: codec,
      faceFinder: MlKitFaceFinder(codec: codec),
    );
  }

  final CodecChannel _codec;
  final FaceFinder? _faceFinder;

  static ui.FragmentProgram? _lookProgramCache;

  /// Whether the camera says its flash fired for [path] (EXIF); null if
  /// unknown.
  Future<bool?> readFlashFired(String path) => _codec.readFlashFired(path);

  Future<RenderResult> render({
    required String sourcePath,
    required LookSpec spec,
    required String outPath,
    bool flashFired = false,
    double? seed,
    DateStampSettings? dateStamp,
    DateTime? captureDate,
    bool mirror = false,
    bool happyAccidents = false,
    bool develop = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    final effectiveSeed = seed ?? math.Random().nextDouble() * 1000;
    final accidents = happyAccidents
        ? accidentsFor(effectiveSeed, flashFired: flashFired)
        : Accidents.none;
    final look = applyAccidents(spec, accidents);
    final flash = flashFired && !accidents.flashMisfired;

    final decoded = await _codec.decodeForRender(
      sourcePath,
      look.outputLongEdge,
    );
    final source = await _imageFromRgba(
      decoded.rgba,
      decoded.width,
      decoded.height,
    );

    // Formats are specified landscape (4:3, 3:2); a photo shot upright
    // keeps its orientation, like turning the real camera on its side.
    final portrait = source.height > source.width;
    final correction = develop
        ? DevelopCorrection.measure(
            await _thumbnail(source),
            awbBias: look.awbBias,
          )
        : DevelopCorrection.identity;
    final cropped = _cropToAspect(
      source,
      portrait ? 1 / look.aspectRatio : look.aspectRatio,
      mirror: mirror,
      correction: correction,
    );
    source.dispose();

    final blurSmall = await _blur(cropped, sigma: 2.5);
    // Bloom source: a bright-pass (only what's above `bloomThreshold`
    // survives) then a heavy blur at quarter resolution, so bloom and
    // halation come from real highlights rather than a veil over the frame.
    final bloomSource = await _blur(
      cropped,
      sigma: 16,
      downscale: 4,
      brightPass: look.bloomThreshold,
    );

    // Develop stage: a cheap quarter-res wide blur for blotchy chroma noise.
    // The same blur drives the de-HDR stage's regional brightness.
    final chroma =
        (develop && look.developDenoise > 0) ||
            look.hdrUndo > 0 ||
            look.glow > 0
        ? await _blur(cropped, sigma: 10, downscale: 4)
        : null;

    final lut = await AssetImageCache.load(
      look.lutAsset ?? 'assets/luts/identity.png',
    );
    final leak = LeakPlacement.forShot(look, effectiveSeed);
    final leakImage = await AssetImageCache.load(
      leak.strength > 0 ? leak.asset : 'assets/textures/leak_00.png',
    );

    final smear = look.ccdSmear > 0 ? await _smearMap(cropped) : _blackPixel();

    // Faces only matter for flash: the hotspot lands on the face, and some
    // cameras give red-eye. Skipped entirely for non-flash shots.
    FaceHint? face;
    var redEye = false;
    if (flash && look.flashStrength > 0 && _faceFinder != null) {
      face = await _faceFinder.find(cropped);
      redEye =
          face != null &&
          math.Random(effectiveSeed.round() + 31).nextDouble() <
              look.redEyeChance;
    }

    final graded = await _applyLookShader(
      image: cropped,
      blurSmall: blurSmall,
      bloom: bloomSource,
      lut: lut,
      leakImage: leakImage,
      leak: leak,
      smear: smear,
      face: face,
      redEye: redEye,
      spec: look,
      flashFired: flash,
      seed: effectiveSeed,
      chroma: chroma,
      denoise: develop ? look.developDenoise : 0,
    );

    cropped.dispose();
    smear.dispose();
    blurSmall.dispose();
    bloomSource.dispose();
    chroma?.dispose();

    final composed = await _compositeOverlays(
      graded,
      spec: look,
      dateStamp: dateStamp,
      captureDate: captureDate ?? DateTime.now(),
    );
    if (!identical(composed, graded)) {
      graded.dispose();
    }

    final byteData = await composed.toByteData();
    var width = composed.width;
    var height = composed.height;
    composed.dispose();

    if (byteData == null) {
      throw StateError('Failed to read rendered image bytes');
    }
    var rgba = byteData.buffer.asUint8List();

    // Cheap cameras compressed hard at the sensor, so the damage (8x8
    // blocking, smeared chroma) is baked into the picture itself, not just
    // the file. Round-trip once at the camera's quality, then save normally.
    if (look.jpegPreQuality > 0) {
      final prePath = '$outPath.pre.jpg';
      await _codec.encodeJpeg(
        rgba: rgba,
        width: width,
        height: height,
        quality: look.jpegPreQuality,
        outPath: prePath,
      );
      final damaged = await _codec.decodeForRender(
        prePath,
        math.max(width, height),
      );
      rgba = damaged.rgba;
      width = damaged.width;
      height = damaged.height;
      unawaited(File(prePath).delete().catchError((Object _) => File(prePath)));
    }

    await _codec.encodeJpeg(
      rgba: rgba,
      width: width,
      height: height,
      quality: look.jpegQuality,
      outPath: outPath,
    );

    stopwatch.stop();
    return RenderResult(
      outputPath: outPath,
      renderMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// CCD smear map: one row, one texel per 4 source columns. Red = how much
  /// blown-out light that column holds (a bigger or brighter light smears
  /// harder), green = the row it's centred on (the streak is a touch
  /// stronger near its source).
  Future<ui.Image> _smearMap(ui.Image src) async {
    final w = math.max(1, src.width ~/ 4);
    final h = math.max(1, src.height ~/ 4);
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final small = recorder.endRecording().toImageSync(w, h);
    final data = await small.toByteData();
    small.dispose();
    final px = data!.buffer.asUint8List();

    final row = Uint8List(w * 4);
    for (var x = 0; x < w; x++) {
      var sum = 0.0;
      var weightedY = 0.0;
      for (var y = 0; y < h; y++) {
        final i = (y * w + x) * 4;
        final luma =
            (px[i] * 0.2126 + px[i + 1] * 0.7152 + px[i + 2] * 0.0722) / 255;
        final over = (luma - 0.96) / 0.04;
        if (over > 0) {
          sum += over;
          weightedY += over * y;
        }
      }
      // Smear comes from small, extremely bright sources (lamps, the sun).
      // A big white area (a window, a wall) already fills its column and
      // would only draw a wide pale band, so it fades out.
      final cover = sum / h;
      final intensity =
          ((sum / (h * 0.02)).clamp(0.0, 1.0) *
                  (1 - (cover - 0.03) / 0.1).clamp(0.0, 1.0))
              .toDouble();
      row[x * 4] = (intensity * 255).round();
      row[x * 4 + 1] = sum > 0 ? (weightedY / sum / h * 255).round() : 128;
      row[x * 4 + 3] = 255;
    }
    return await _imageFromRgba(row, w, 1);
  }

  /// A 64 px-long-edge copy of [src] as RGBA bytes, for per-shot stats.
  Future<Uint8List> _thumbnail(ui.Image src) async {
    final scale = 64 / math.max(src.width, src.height);
    final w = math.max(1, (src.width * scale).round());
    final h = math.max(1, (src.height * scale).round());
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      src,
      ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final small = recorder.endRecording().toImageSync(w, h);
    final data = await small.toByteData();
    small.dispose();
    return data!.buffer.asUint8List();
  }

  ui.Image _blackPixel() {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );
    return recorder.endRecording().toImageSync(1, 1);
  }

  Future<ui.Image> _imageFromRgba(Uint8List rgba, int width, int height) {
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

  ui.Image _cropToAspect(
    ui.Image src,
    double aspectRatio, {
    bool mirror = false,
    DevelopCorrection correction = DevelopCorrection.identity,
  }) {
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
    // "Mirror front photos" (Settings, S17): save the selfie the way it
    // looked in the viewfinder rather than how others see it.
    if (mirror) {
      canvas
        ..translate(cropW, 0)
        ..scale(-1, 1);
    }
    final srcRect = ui.Rect.fromLTWH(left, top, cropW, cropH);
    final dstRect = ui.Rect.fromLTWH(0, 0, cropW, cropH);
    final paint = ui.Paint();
    if (!correction.isIdentity) {
      paint.colorFilter = ui.ColorFilter.matrix(correction.colorMatrix);
    }
    canvas.drawImageRect(src, srcRect, dstRect, paint);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(cropW.round(), cropH.round());
    picture.dispose();
    return image;
  }

  Future<ui.Image> _blur(
    ui.Image src, {
    required double sigma,
    int downscale = 1,
    double? brightPass,
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
    if (brightPass != null && brightPass < 1) {
      // Keep only what's above the threshold, rescaled back to 0-1. The
      // matrix offset column is in 0-255 units.
      final gain = 1 / (1 - brightPass);
      final offset = -brightPass * gain * 255;
      paint.colorFilter = ui.ColorFilter.matrix(<double>[
        gain, 0, 0, 0, offset, //
        0, gain, 0, 0, offset,
        0, 0, gain, 0, offset,
        0, 0, 0, 1, 0,
      ]);
    }
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
      frame = await AssetImageCache.load(frameAsset);
      canvasSize = frameCanvasSize(photoWidth: photoW, photoHeight: photoH);
      windowRect = frameWindowRect(photoWidth: photoW, photoHeight: photoH);
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    if (frame != null) {
      canvas.drawImageRect(
        frame,
        ui.Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
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
    required ui.Image leakImage,
    required LeakPlacement leak,
    required ui.Image smear,
    required FaceHint? face,
    required bool redEye,
    required LookSpec spec,
    required bool flashFired,
    required double seed,
    ui.Image? chroma,
    double denoise = 0,
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
      leak: leak,
      face: face,
      redEye: redEye,
      denoise: denoise,
    );
    bindLookSamplers(
      shader,
      image: image,
      blurSmall: blurSmall,
      bloom: bloom,
      lut: lut,
      leak: leakImage,
      smear: smear,
      chroma: chroma,
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
