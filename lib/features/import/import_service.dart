import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/core/storage/photo_meta.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';

/// Import (S19): runs a photo from the phone's gallery through a look and
/// stores it like a captured one, tagged [PhotoSource.import].
class ImportService {
  new({
    LookRenderer? renderer,
    PhotoStore? photoStore,
    Future<Directory> Function()? temporaryDirectory,
    CodecChannel? codec,
  }) : _codec = codec ?? MethodChannelCodec(),
       _renderer = renderer ?? LookRenderer.device(),
       _photoStore = photoStore ?? PhotoStore(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final CodecChannel _codec;
  final LookRenderer _renderer;
  final PhotoStore _photoStore;
  final Future<Directory> Function() _temporaryDirectory;

  Future<PhotoMeta> importOne({
    required String sourcePath,
    required LookSpec spec,
    DateStampSettings? dateStampOverride,
  }) async {
    final tempDir = await _temporaryDirectory();
    final outPath =
        '${tempDir.path}/shuttr_import_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg';
    final dateStamp =
        dateStampOverride ??
        (spec.dateStampDefaultOn
            ? const DateStampSettings(enabled: true)
            : null);
    final seed = math.Random().nextDouble() * 1000;
    // The date the photo was really taken, so an old photo gets the right
    // year on its date stamp; file time is only a fallback.
    final taken =
        await _codec.readCaptureDate(sourcePath) ??
        File(sourcePath).lastModifiedSync();

    try {
      await _renderer.render(
        sourcePath: sourcePath,
        spec: spec,
        outPath: outPath,
        seed: seed,
        dateStamp: dateStamp,
        captureDate: taken,
      );
      return await _photoStore.save(
        originalCapturePath: sourcePath,
        renderedPath: outPath,
        spec: spec,
        seed: seed,
        dateStamp: dateStamp,
        source: PhotoSource.import,
        capturedAt: taken,
      );
    } finally {
      final temp = File(outPath);
      if (temp.existsSync()) await temp.delete();
    }
  }
}
