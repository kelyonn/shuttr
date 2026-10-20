import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/core/storage/photo_meta.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/look_spec.dart';

/// Bumped when a photo comes back from the trash, so an open gallery can
/// refresh itself.
final ValueNotifier<int> photoStoreRevision = ValueNotifier<int>(0);

/// A stored photo's [PhotoMeta] plus the on-disk paths the gallery (S18)
/// needs to actually display and act on it. `originalPath` may not exist —
/// Settings' "Clear originals" (S17) removes those files without touching
/// `meta/`.
class StoredPhoto {
  const new({
    required this.meta,
    required this.photoPath,
    required this.originalPath,
  });

  final PhotoMeta meta;
  final String photoPath;
  final String originalPath;

  bool get hasOriginal => File(originalPath).existsSync();
}

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
    bool flashFired = false,
    bool accidents = false,
    bool developed = true,
    DateTime? capturedAt,
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
      capturedAt: capturedAt ?? DateTime.now(),
      source: source,
      seed: seed,
      dateStamp: dateStamp,
      flashFired: flashFired,
      accidents: accidents,
      developed: developed,
    );
    await _writeMeta(meta);

    // A frame on an unfinished roll stays out of the phone gallery until
    // the roll is developed (Roll mode).
    if (developed) await _saveToGallery(photoPath, album: 'Shuttr');

    return meta;
  }

  Future<void> _writeMeta(PhotoMeta meta) async {
    final metaDir = await _dir('meta');
    await File('${metaDir.path}/${meta.id}.json')
        .writeAsString(jsonEncode(meta.toJson()));
  }

  /// Develops the roll: every frame still on it becomes visible and goes to
  /// the phone gallery, oldest first. Returns how many were developed.
  Future<int> developRoll() async {
    final onRoll = (await listAll(includeUndeveloped: true))
        .where((p) => !p.meta.developed)
        .toList()
        .reversed;
    var n = 0;
    for (final photo in onRoll) {
      await _saveToGallery(photo.photoPath, album: 'Shuttr');
      await _writeMeta(photo.meta.copyWith(developed: true));
      n++;
    }
    return n;
  }

  /// How many frames are exposed on the current (undeveloped) roll.
  Future<int> exposuresOnRoll() async =>
      (await listAll(includeUndeveloped: true))
          .where((p) => !p.meta.developed)
          .length;

  /// Every stored photo, newest first, for the in-app gallery (S18).
  /// Frames on an undeveloped roll are hidden unless [includeUndeveloped].
  Future<List<StoredPhoto>> listAll({bool includeUndeveloped = false}) async {
    final metaDir = await _dir('meta');
    final photosDir = await _dir('photos');
    final originalsDir = await _dir('originals');

    final photos = <StoredPhoto>[];
    await for (final entity in metaDir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final meta = PhotoMeta.fromJson(
        jsonDecode(await entity.readAsString()) as Map<String, dynamic>,
      );
      if (!meta.developed && !includeUndeveloped) continue;
      photos.add(
        StoredPhoto(
          meta: meta,
          photoPath: '${photosDir.path}/${meta.id}.jpg',
          originalPath: '${originalsDir.path}/${meta.id}.jpg',
        ),
      );
    }
    photos.sort((a, b) => b.meta.capturedAt.compareTo(a.meta.capturedAt));
    return photos;
  }

  /// Deletes a photo's `photos/`, `originals/` and `meta/` entries. The
  /// gallery's own copy only — a photo saved to the OS gallery via `gal`
  /// has no delete API and is untouched.
  Future<void> deletePhoto(String id) async {
    for (final dirName in ['photos', 'originals', 'meta']) {
      final dir = await _dir(dirName);
      final ext = dirName == 'meta' ? 'json' : 'jpg';
      final file = File('${dir.path}/$id.$ext');
      if (file.existsSync()) await file.delete();
    }
  }

  static const _kinds = {'photos': 'jpg', 'originals': 'jpg', 'meta': 'json'};

  /// Moves a photo to the trash instead of deleting it, so a delete can be
  /// undone. The previous trash is emptied first.
  Future<void> trashPhoto(String id) async {
    await emptyTrash();
    for (final entry in _kinds.entries) {
      final dir = await _dir(entry.key);
      final file = File('${dir.path}/$id.${entry.value}');
      if (!file.existsSync()) continue;
      final trash = await _dir('trash/${entry.key}');
      await file.copy('${trash.path}/$id.${entry.value}');
      await file.delete();
    }
  }

  /// Puts a trashed photo back.
  Future<void> restorePhoto(String id) async {
    for (final entry in _kinds.entries) {
      final trash = await _dir('trash/${entry.key}');
      final file = File('${trash.path}/$id.${entry.value}');
      if (!file.existsSync()) continue;
      final dir = await _dir(entry.key);
      await file.copy('${dir.path}/$id.${entry.value}');
      await file.delete();
    }
    photoStoreRevision.value++;
  }

  /// Permanently removes whatever is in the trash.
  Future<void> emptyTrash() async {
    final docs = await _documentsDirectory();
    final trash = Directory('${docs.path}/trash');
    if (trash.existsSync()) await trash.delete(recursive: true);
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
