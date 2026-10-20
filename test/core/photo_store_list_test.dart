import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/looks/specs/identity.dart';

import '../support/fake_codec_channel.dart';

void main() {
  late Directory tempDir;
  late String renderedPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('photo_store_list_test');
    renderedPath = '${tempDir.path}/rendered_input.jpg';
    File(renderedPath).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  PhotoStore buildStore() {
    return PhotoStore(
      codec: FakeCodecChannel(),
      documentsDirectory: () async => tempDir,
      saveToGallery: (path, {album}) async {},
    );
  }

  test('listAll returns saved photos newest first', () async {
    final store = buildStore();

    final first = await store.save(
      originalCapturePath: 'a.jpg',
      renderedPath: renderedPath,
      spec: identityLook,
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final second = await store.save(
      originalCapturePath: 'b.jpg',
      renderedPath: renderedPath,
      spec: identityLook,
    );

    final all = await store.listAll();

    expect(all.map((p) => p.meta.id).toList(), [second.id, first.id]);
    expect(all.every((p) => File(p.photoPath).existsSync()), isTrue);
    expect(all.every((p) => p.hasOriginal), isTrue);
  });

  test('deletePhoto removes photos/originals/meta for that id', () async {
    final store = buildStore();
    final meta = await store.save(
      originalCapturePath: 'a.jpg',
      renderedPath: renderedPath,
      spec: identityLook,
    );

    await store.deletePhoto(meta.id);

    final all = await store.listAll();
    expect(all, isEmpty);
  });

  test('hasOriginal is false once originals are cleared', () async {
    final store = buildStore();
    final meta = await store.save(
      originalCapturePath: 'a.jpg',
      renderedPath: renderedPath,
      spec: identityLook,
    );

    await store.clearOriginals();

    final all = await store.listAll();
    expect(all.single.meta.id, meta.id);
    expect(all.single.hasOriginal, isFalse);
  });

  test('a trashed photo leaves the list and comes back on restore', () async {
    final store = buildStore();
    final meta = await store.save(
      originalCapturePath: 'a.jpg',
      renderedPath: renderedPath,
      spec: identityLook,
    );

    await store.trashPhoto(meta.id);
    expect(await store.listAll(), isEmpty);

    await store.restorePhoto(meta.id);
    final back = await store.listAll();
    expect(back.single.meta.id, meta.id);
    expect(File(back.single.photoPath).existsSync(), isTrue);
    expect(back.single.hasOriginal, isTrue);
  });

  test('emptying the trash makes a delete permanent', () async {
    final store = buildStore();
    final meta = await store.save(
      originalCapturePath: 'a.jpg',
      renderedPath: renderedPath,
      spec: identityLook,
    );

    await store.trashPhoto(meta.id);
    await store.emptyTrash();
    await store.restorePhoto(meta.id);

    expect(await store.listAll(), isEmpty);
  });
}
