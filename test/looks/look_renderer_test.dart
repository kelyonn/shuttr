import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';
import 'package:shuttr/features/looks/specs/identity.dart';
import 'package:shuttr/features/looks/specs/instant.dart';

import '../support/fake_codec_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('look_renderer_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('no date stamp and no frame leaves the output size untouched',
      () async {
    final codec = FakeCodecChannel();
    final renderer = LookRenderer(codec: codec);

    await renderer.render(
      sourcePath: 'fake.jpg',
      spec: identityLook,
      outPath: '${tempDir.path}/out.jpg',
      seed: 1,
    );

    // Fake decode is 64x48 (4:3), matching identityLook's aspect, so
    // cropping is a no-op and there's no frame/date-stamp overlay to grow
    // the canvas.
    expect(codec.encodedSizes.single, (64, 48));
  });

  test('a date stamp changes the encoded pixels but not the size', () async {
    final plain = FakeCodecChannel();
    await LookRenderer(codec: plain).render(
      sourcePath: 'fake.jpg',
      spec: identityLook,
      outPath: '${tempDir.path}/plain.jpg',
      seed: 1,
    );

    final stamped = FakeCodecChannel();
    await LookRenderer(codec: stamped).render(
      sourcePath: 'fake.jpg',
      spec: identityLook,
      outPath: '${tempDir.path}/stamped.jpg',
      seed: 1,
      dateStamp: const DateStampSettings(enabled: true),
      captureDate: DateTime(2003, 10, 28),
    );

    expect(stamped.encodedSizes.single, plain.encodedSizes.single);
    expect(stamped.encodedRgba.single, isNot(plain.encodedRgba.single));
  });

  test('mirror flips the output relative to unmirrored', () async {
    final plain = FakeCodecChannel();
    await LookRenderer(codec: plain).render(
      sourcePath: 'fake.jpg',
      spec: identityLook,
      outPath: '${tempDir.path}/plain.jpg',
      seed: 1,
    );

    final mirrored = FakeCodecChannel();
    await LookRenderer(codec: mirrored).render(
      sourcePath: 'fake.jpg',
      spec: identityLook,
      outPath: '${tempDir.path}/mirrored.jpg',
      seed: 1,
      mirror: true,
    );

    expect(mirrored.encodedSizes.single, plain.encodedSizes.single);
    expect(mirrored.encodedRgba.single, isNot(plain.encodedRgba.single));
  });

  test('a frameAsset grows the canvas by the frame margins', () async {
    final codec = FakeCodecChannel();
    final renderer = LookRenderer(codec: codec);

    await renderer.render(
      sourcePath: 'fake.jpg',
      spec: instantLook,
      outPath: '${tempDir.path}/instant.jpg',
      seed: 1,
    );

    // Fake decode is 64x48; instantLook's 1:1 aspect crops that to 48x48
    // before the frame's side/top/bottom margins are added around it.
    final (width, height) = codec.encodedSizes.single;
    expect(width, greaterThan(48));
    expect(height, greaterThan(width)); // bottom margin > side margins
  });
}
