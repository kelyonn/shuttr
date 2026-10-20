import 'package:flutter/services.dart';

/// Result of a native decode: raw RGBA8888 pixels plus dimensions.
class DecodedImage {
  const new({required this.rgba, required this.width, required this.height});

  final Uint8List rgba;
  final int width;
  final int height;
}

/// Native image decode/encode, kept off the Dart JPEG path because pure-Dart
/// encoding is too slow on budget phones (docs/ARCHITECTURE.md D-021).
///
/// Decode downsamples during decode (`inSampleSize` on Android) so a 50 MP
/// source file is never fully decoded in memory, then applies EXIF rotation.
abstract class CodecChannel {
  /// Decodes [path] to RGBA8888, downsampled so its long edge is at most
  /// [maxLongEdge], oriented per EXIF.
  Future<DecodedImage> decodeForRender(String path, int maxLongEdge);

  /// Encodes RGBA8888 [rgba] ([width]x[height]) as a JPEG at [quality]
  /// (0-100) and writes it to [outPath].
  Future<void> encodeJpeg({
    required Uint8List rgba,
    required int width,
    required int height,
    required int quality,
    required String outPath,
  });

  /// When the photo at [path] was taken, from its EXIF `DateTimeOriginal`
  /// (falling back to `DateTime`). Null if the file has no such tag.
  Future<DateTime?> readCaptureDate(String path);

  /// Whether the camera reports that its flash fired for the photo at
  /// [path] (EXIF `Flash` tag, bit 0). Null if the file has no such tag.
  Future<bool?> readFlashFired(String path);
}

/// Real implementation backed by the `shuttr/codec` platform channel.
class MethodChannelCodec implements CodecChannel {
  new({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('shuttr/codec');

  final MethodChannel _channel;

  @override
  Future<DecodedImage> decodeForRender(String path, int maxLongEdge) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'decodeForRender',
      {'path': path, 'maxLongEdge': maxLongEdge},
    );
    if (result == null) {
      throw PlatformException(
        code: 'decode_failed',
        message: 'Native decodeForRender returned null for $path',
      );
    }
    return DecodedImage(
      rgba: result['rgba']! as Uint8List,
      width: result['width']! as int,
      height: result['height']! as int,
    );
  }

  @override
  Future<void> encodeJpeg({
    required Uint8List rgba,
    required int width,
    required int height,
    required int quality,
    required String outPath,
  }) {
    return _channel.invokeMethod<void>('encodeJpeg', {
      'rgba': rgba,
      'width': width,
      'height': height,
      'quality': quality,
      'outPath': outPath,
    });
  }

  @override
  Future<DateTime?> readCaptureDate(String path) async {
    final millis = await _channel.invokeMethod<int>('readCaptureDate', {
      'path': path,
    });
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<bool?> readFlashFired(String path) {
    return _channel.invokeMethod<bool>('readFlashFired', {'path': path});
  }
}
