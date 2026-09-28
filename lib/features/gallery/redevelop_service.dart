import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/core/storage/photo_meta.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';

/// Thrown when a photo can't be re-developed — e.g. its original was
/// cleared via Settings' "Clear originals" (S17).
class RedevelopException implements Exception {
  const new(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Re-develop (S18): re-renders a stored original against a different
/// [LookSpec] and saves the result as a new photo, rather than overwriting
/// the original capture — so both versions stay in the gallery.
class RedevelopService {
  new({
    LookRenderer? renderer,
    PhotoStore? photoStore,
    Future<Directory> Function()? temporaryDirectory,
  }) : _renderer = renderer ?? LookRenderer(codec: MethodChannelCodec()),
       _photoStore = photoStore ?? PhotoStore(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final LookRenderer _renderer;
  final PhotoStore _photoStore;
  final Future<Directory> Function() _temporaryDirectory;

  Future<PhotoMeta> redevelop({
    required StoredPhoto photo,
    required LookSpec newSpec,
  }) async {
    if (!photo.hasOriginal) {
      throw const RedevelopException(
        "This photo's original was cleared in Settings, so it can't be "
        're-developed.',
      );
    }

    final tempDir = await _temporaryDirectory();
    final outPath =
        '${tempDir.path}/shuttr_redevelop_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg';

    // Reuse the original's seed so grain/light-leak placement stays
    // consistent across looks, and whatever date-stamp settings it had.
    await _renderer.render(
      sourcePath: photo.originalPath,
      spec: newSpec,
      outPath: outPath,
      seed: photo.meta.seed,
      dateStamp: photo.meta.dateStamp,
    );

    final meta = await _photoStore.save(
      originalCapturePath: photo.originalPath,
      renderedPath: outPath,
      spec: newSpec,
      seed: photo.meta.seed,
      dateStamp: photo.meta.dateStamp,
      source: photo.meta.source,
    );

    final tempFile = File(outPath);
    if (tempFile.existsSync()) await tempFile.delete();

    return meta;
  }
}
