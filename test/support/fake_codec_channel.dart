import 'dart:io';
import 'dart:typed_data';

import 'package:shuttr/core/platform/codec_channel.dart';

/// In-memory fake for [CodecChannel] so render-pipeline logic can be unit
/// tested without a device. Produces a flat mid-grey image of the requested
/// size rather than decoding a real file, and "encodes" by writing a tiny
/// placeholder file (not a real JPEG) so callers can assert a file exists.
class FakeCodecChannel implements CodecChannel {
  new();

  final List<String> decodedPaths = [];
  final List<String> encodedPaths = [];

  @override
  Future<DecodedImage> decodeForRender(String path, int maxLongEdge) async {
    decodedPaths.add(path);
    const width = 64;
    const height = 48;
    final rgba = Uint8List(width * height * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = 128;
      rgba[i + 1] = 128;
      rgba[i + 2] = 128;
      rgba[i + 3] = 255;
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
    await File(outPath).writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
  }
}
