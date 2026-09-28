import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/core/storage/photo_meta.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/gallery/redevelop_service.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';
import 'package:shuttr/features/looks/specs/digi03.dart';
import 'package:shuttr/features/looks/specs/identity.dart';

import '../support/fake_codec_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('redevelop_service_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('throws when the original was cleared', () async {
    final service = RedevelopService(
      renderer: LookRenderer(codec: FakeCodecChannel()),
      photoStore: PhotoStore(
        codec: FakeCodecChannel(),
        documentsDirectory: () async => tempDir,
        saveToGallery: (path, {album}) async {},
      ),
    );
    final missingOriginal = StoredPhoto(
      meta: PhotoMeta(
        id: '1',
        lookId: identityLook.id,
        lookVersion: identityLook.version,
        capturedAt: DateTime.now(),
        source: PhotoSource.capture,
      ),
      photoPath: '${tempDir.path}/photos/1.jpg',
      originalPath: '${tempDir.path}/originals/1.jpg',
    );

    expect(
      () => service.redevelop(photo: missingOriginal, newSpec: digi03Look),
      throwsA(isA<RedevelopException>()),
    );
  });

  test('re-renders the original and saves a new photo entry', () async {
    final photoStore = PhotoStore(
      codec: FakeCodecChannel(),
      documentsDirectory: () async => tempDir,
      saveToGallery: (path, {album}) async {},
    );
    final service = RedevelopService(
      renderer: LookRenderer(codec: FakeCodecChannel()),
      photoStore: photoStore,
      temporaryDirectory: () async => tempDir,
    );

    final originalPath = '${tempDir.path}/existing_original.jpg';
    File(originalPath).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    final existing = StoredPhoto(
      meta: PhotoMeta(
        id: 'orig-id',
        lookId: identityLook.id,
        lookVersion: identityLook.version,
        capturedAt: DateTime.now(),
        source: PhotoSource.capture,
        seed: 12.5,
      ),
      photoPath: '${tempDir.path}/unused.jpg',
      originalPath: originalPath,
    );

    final newMeta = await service.redevelop(
      photo: existing,
      newSpec: digi03Look,
    );

    expect(newMeta.id, isNot(existing.meta.id));
    expect(newMeta.lookId, digi03Look.id);
    expect(newMeta.seed, 12.5);

    final all = await photoStore.listAll();
    expect(all.single.meta.id, newMeta.id);
  });
}
