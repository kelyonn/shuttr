import 'dart:io';
import 'dart:ui' as ui;

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shuttr/core/platform/codec_channel.dart';

/// Carousel shape for a photo dump. Instagram carousels are 4:5 or 1:1.
enum DumpRatio {
  portrait(width: 1080, height: 1350, label: '4:5'),
  square(width: 1080, height: 1080, label: '1:1');

  new({required this.width, required this.height, required this.label});

  final int width;
  final int height;
  final String label;

  double get aspect => width / height;
}

/// Photo dump (S20): turns up to [maxPhotos] saved photos into a ready
/// carousel — every slide the same size, centre-cropped to fill (or fitted
/// on a white border) — saved to the gallery in order for sharing.
class DumpService {
  new({CodecChannel? codec, Future<Directory> Function()? temporaryDirectory})
    : _codec = codec ?? MethodChannelCodec(),
      _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const maxPhotos = 10;

  final CodecChannel _codec;
  final Future<Directory> Function() _temporaryDirectory;

  /// Composes each photo and saves it to the "Shuttr" gallery album, in
  /// order. Returns the composed files (for sharing); the caller deletes
  /// them afterwards.
  Future<List<String>> export({
    required List<String> photoPaths,
    required DumpRatio ratio,
    required bool fill,
    void Function(int done)? onProgress,
  }) async {
    final tempDir = await _temporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final outputs = <String>[];
    for (var i = 0; i < photoPaths.length; i++) {
      final outPath = '${tempDir.path}/shuttr_dump_${stamp}_$i.jpg';
      await _compose(photoPaths[i], ratio, fill: fill, outPath: outPath);
      await Gal.putImage(outPath, album: 'Shuttr');
      outputs.add(outPath);
      onProgress?.call(i + 1);
    }
    return outputs;
  }

  Future<void> _compose(
    String path,
    DumpRatio ratio, {
    required bool fill,
    required String outPath,
  }) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final target = ui.Rect.fromLTWH(
      0,
      0,
      ratio.width.toDouble(),
      ratio.height.toDouble(),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, target)
      ..drawRect(target, ui.Paint()..color = const ui.Color(0xFFFFFFFF));

    final imageAspect = image.width / image.height;
    final ui.Rect src;
    final ui.Rect dst;
    if (fill) {
      // Centre-crop the source to the target aspect.
      if (imageAspect > ratio.aspect) {
        final w = image.height * ratio.aspect;
        src = ui.Rect.fromLTWH(
          (image.width - w) / 2,
          0,
          w,
          image.height.toDouble(),
        );
      } else {
        final h = image.width / ratio.aspect;
        src = ui.Rect.fromLTWH(
          0,
          (image.height - h) / 2,
          image.width.toDouble(),
          h,
        );
      }
      dst = target;
    } else {
      // Whole photo, inset on a border.
      const inset = 0.92;
      final maxW = ratio.width * inset;
      final maxH = ratio.height * inset;
      final scale = imageAspect > maxW / maxH
          ? maxW / image.width
          : maxH / image.height;
      final w = image.width * scale;
      final h = image.height * scale;
      src = ui.Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      dst = ui.Rect.fromLTWH(
        (ratio.width - w) / 2,
        (ratio.height - h) / 2,
        w,
        h,
      );
    }
    canvas.drawImageRect(
      image,
      src,
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    image.dispose();

    final composed = await recorder.endRecording().toImage(
      ratio.width,
      ratio.height,
    );
    final data = await composed.toByteData();
    composed.dispose();
    await _codec.encodeJpeg(
      rgba: data!.buffer.asUint8List(),
      width: ratio.width,
      height: ratio.height,
      quality: 92,
      outPath: outPath,
    );
  }
}
