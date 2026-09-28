import 'dart:convert';
import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/core/storage/photo_meta.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/look_spec.dart';

/// The app's permanent photo storage (docs/ARCHITECTURE.md "Storage"), all
/// under the app documents directory:
/// - `photos/<id>.jpg` — the rendered look, shown by the in-app gallery.
/// - `originals/<id>.jpg` — downscaled to 3000px long edge at q95, kept so
///   re-develop has real detail to work with without keeping full-sensor
///   files around forever.
/// - `meta/<id>.json` — a [PhotoMeta] sidecar.
///
/// Also saves the rendered photo to the OS gallery's "Shuttr" album via
/// `gal`, alongside keeping the app's own copy.
class PhotoStore {
  new({
    CodecChannel? codec,
    Future<void> Function(String path, {String? album})? saveToGallery,
    Future<Directory> Function()? documentsDirectory,
  }) : _codec = codec ?? MethodChannelCodec(),
       _saveToGallery = saveToGallery ?? Gal.putImage,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static const _originalLongEdge = 3000;
  static const _originalQuality = 95;

  final CodecChannel _codec;
  final Future<void> Function(String path, {String? album}) _saveToGallery;
  final Future<Directory> Function() _documentsDirectory;

  Future<Directory> _dir(String name) async {
    final docs = await _documentsDirectory();
    final dir = Directory('${docs.path}/$name');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Persists a rendered capture and returns its [PhotoMeta]. `renderedPath`
  /// is copied as-is (it's already been through [LookSpec]'s full
  /// pipeline); `originalCapturePath` is downscaled/recompressed on the way
  /// in, since a full-sensor JPEG is far more than re-develop ever needs.
  Future<PhotoMeta> save({
    required String originalCapturePath,
    required String renderedPath,
    required LookSpec spec,
    double? seed,
    DateStampSettings? dateStamp,
    PhotoSource source = PhotoSource.capture,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final originalsDir = await _dir('originals');
    final decoded = await _codec.decodeForRender(
      originalCapturePath,
      _originalLongEdge,
    );
    await _codec.encodeJpeg(
      rgba: decoded.rgba,
      width: decoded.width,
      height: decoded.height,
      quality: _originalQuality,
      outPath: '${originalsDir.path}/$id.jpg',
    );

    final photosDir = await _dir('photos');
    final photoPath = '${photosDir.path}/$id.jpg';
    await File(renderedPath).copy(photoPath);

    final meta = PhotoMeta(
      id: id,
      lookId: spec.id,
      lookVersion: spec.version,
      capturedAt: DateTime.now(),
      source: source,
      seed: seed,
      dateStamp: dateStamp,
    );
    final metaDir = await _dir('meta');
    await File(
      '${metaDir.path}/$id.json',
    ).writeAsString(jsonEncode(meta.toJson()));

    await _saveToGallery(photoPath, album: 'Shuttr');

    return meta;
  }

  /// Total size of everything in `originals/` — what "Clear originals" in
  /// Settings (S17) frees up. `photos/` and `meta/` are left alone; the
  /// gallery already has its own copy of the rendered photo via `gal`.
  Future<int> originalsSizeBytes() async {
    final dir = await _dir('originals');
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Deletes every file in `originals/`. Re-develop (S18) needs an original
  /// to work from, so this trades that away for the freed storage — the
  /// Settings copy makes that trade-off explicit to the user.
  Future<void> clearOriginals() async {
    final dir = await _dir('originals');
    await for (final entity in dir.list()) {
      if (entity is File) await entity.delete();
    }
  }
}
