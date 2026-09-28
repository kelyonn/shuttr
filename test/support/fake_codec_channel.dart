import 'dart:io';
import 'dart:typed_data';

import 'package:shuttr/core/platform/codec_channel.dart';

/// In-memory fake for [CodecChannel] so render-pipeline logic can be unit
/// tested without a device. Produces a left-dark/right-light gradient of
/// the requested size (not flat, so a horizontal mirror is observable in
/// tests) rather than decoding a real file, and "encodes" by writing a tiny
/// placeholder file (not a real JPEG) so callers can assert a file exists.
class FakeCodecChannel implements CodecChannel {
  new();

  final List<String> decodedPaths = [];
  final List<String> encodedPaths = [];
  final List<(int width, int height)> encodedSizes = [];
  final List<Uint8List> encodedRgba = [];

  @override
  Future<DecodedImage> decodeForRender(String path, int maxLongEdge) async {
    decodedPaths.add(path);
    const width = 64;
    const height = 48;
    final rgba = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final value = (x * 255 / (width - 1)).round();
        rgba[i] = value;
        rgba[i + 1] = value;
        rgba[i + 2] = value;
        rgba[i + 3] = 255;
      }
    }
    return DecodedImage(rgba: rgba, width: width, height: height);
  }

  @override
  Future<void> encodeJpeg({
    required Uint8List rgba,
    required int width,
    required int height,
    required int quality,
    required String outPath,
  }) async {
    encodedPaths.add(outPath);
    encodedSizes.add((width, height));
    encodedRgba.add(rgba);
    await File(outPath).writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
  }
}
