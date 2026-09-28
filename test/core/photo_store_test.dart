import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/core/storage/photo_meta.dart';
import 'package:shuttr/core/storage/photo_store.dart';
import 'package:shuttr/features/looks/specs/identity.dart';

import '../support/fake_codec_channel.dart';

void main() {
  late Directory tempDir;
  late String renderedPath;
  final galCalls = <(String path, String? album)>[];

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('photo_store_test');
    renderedPath = '${tempDir.path}/rendered_input.jpg';
    File(renderedPath).writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    galCalls.clear();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  PhotoStore buildStore() {
    return PhotoStore(
      codec: FakeCodecChannel(),
      documentsDirectory: () async => tempDir,
      saveToGallery: (path, {album}) async {
        galCalls.add((path, album));
      },
    );
  }

  test('writes photos/, originals/ and meta/ under the documents dir', () async {
    final store = buildStore();

    final meta = await store.save(
      originalCapturePath: 'fake_original.jpg',
      renderedPath: renderedPath,
      spec: identityLook,
      seed: 7,
    );

    expect(
      File('${tempDir.path}/photos/${meta.id}.jpg').existsSync(),
      isTrue,
    );
    expect(
      File('${tempDir.path}/originals/${meta.id}.jpg').existsSync(),
      isTrue,
    );
    final metaFile = File('${tempDir.path}/meta/${meta.id}.json');
    expect(metaFile.existsSync(), isTrue);

    final decoded = PhotoMeta.fromJson(
      jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>,
    );
    expect(decoded.lookId, identityLook.id);
    expect(decoded.seed, 7);
  });

  test('saves the rendered photo to the gallery Shuttr album', () async {
    final store = buildStore();

    final meta = await store.save(
      originalCapturePath: 'fake_original.jpg',
      renderedPath: renderedPath,
      spec: identityLook,
    );

    expect(galCalls, hasLength(1));
    expect(galCalls.single.$1, '${tempDir.path}/photos/${meta.id}.jpg');
    expect(galCalls.single.$2, 'Shuttr');
  });

  test('defaults to PhotoSource.capture', () async {
    final store = buildStore();

    final meta = await store.save(
      originalCapturePath: 'fake_original.jpg',
      renderedPath: renderedPath,
      spec: identityLook,
    );

    expect(meta.source, PhotoSource.capture);
  });
}
