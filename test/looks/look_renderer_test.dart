import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/features/looks/date_stamp.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/face_finder.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';
import 'package:shuttr/features/looks/render/shader_uniforms.dart';
import 'package:shuttr/features/looks/specs/identity.dart';
import 'package:shuttr/features/looks/specs/instant.dart';
import 'package:shuttr/features/looks/specs/mono_400.dart';

import '../support/fake_codec_channel.dart';

/// A flat-colour "photo" so colour handling is observable (the standard fake
/// is grey, which can't reveal channel or LUT bugs).
class _ColourCodec extends FakeCodecChannel {
  new(this.r, this.g, this.b);
  final int r;
  final int g;
  final int b;

  @override
  Future<DecodedImage> decodeForRender(String path, int maxLongEdge) async {
    const w = 64;
    const h = 48;
    final rgba = Uint8List(w * h * 4);
    for (var i = 0; i < w * h; i++) {
      rgba[i * 4] = r;
      rgba[i * 4 + 1] = g;
      rgba[i * 4 + 2] = b;
      rgba[i * 4 + 3] = 255;
    }
    return DecodedImage(rgba: rgba, width: w, height: h);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('look_renderer_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('no date stamp and no frame leaves the output size untouched', () async {
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

    // Fake decode is 64x48; instantLook's 4:3 aspect keeps that 64x48
    // before the frame's side/top/bottom margins are added around it.
    final (width, height) = codec.encodedSizes.single;
    expect(width, greaterThan(64));
    expect(height, greaterThan(48));
    // Bottom margin is thicker than the sides: the extra height outgrows
    // the extra width.
    expect(height / 48, greaterThan(width / 64));
  });

  test(
    'identity look with the identity LUT reproduces the input colour',
    () async {
      // Guards the LUT lattice sampling (half-texel offset) and that no stage
      // leaks colour: a saturated mid colour must come back within dither.
      final codec = _ColourCodec(200, 90, 40);
      await LookRenderer(codec: codec).render(
        sourcePath: 'fake.jpg',
        spec: identityLook,
        outPath: '${tempDir.path}/id.jpg',
        seed: 1,
      );
      final px = codec.encodedRgba.single;
      const centre = ((48 ~/ 2) * 64 + 32) * 4;
      expect(px[centre], closeTo(200, 3));
      expect(px[centre + 1], closeTo(90, 3));
      expect(px[centre + 2], closeTo(40, 3));
    },
  );

  test('a mono look outputs neutral grey whatever the input colour', () async {
    final codec = _ColourCodec(255, 90, 30);
    await LookRenderer(codec: codec).render(
      sourcePath: 'fake.jpg',
      spec: mono400Look.copyWith(
        grainAmount: 0,
        vignette: 0,
        sharpenAmount: 0.5,
        softness: 0,
      ),
      outPath: '${tempDir.path}/mono.jpg',
      seed: 1,
    );
    final px = codec.encodedRgba.single;
    const centre = ((48 ~/ 2) * 64 + 32) * 4;
    // Bloom is on (bright red source): it must be graded too. The base is
    // very slightly warm; anything beyond that is leaked colour.
    expect((px[centre] - px[centre + 1]).abs(), lessThan(8));
    expect((px[centre + 1] - px[centre + 2]).abs(), lessThan(10));
  });

  test('CCD smear streaks a bright light up and down its column', () async {
    Future<Uint8List> render(double smear) async {
      final codec = _DotCodec();
      await LookRenderer(codec: codec).render(
        sourcePath: 'fake.jpg',
        spec: identityLook.copyWith(ccdSmear: smear),
        outPath: '${tempDir.path}/smear.jpg',
        seed: 1,
      );
      return codec.encodedRgba.single;
    }

    final plain = await render(0);
    final smeared = await render(1);
    // Column through the light, well above it.
    const above = (4 * 64 + 32) * 4;
    // A column far from the light stays untouched.
    const elsewhere = (4 * 64 + 5) * 4;
    expect(smeared[above], greaterThan(plain[above] + 40));
    expect(smeared[elsewhere], closeTo(plain[elsewhere], 3));
  });

  test('red-eye turns a dark pupil red on a flash shot with a face', () async {
    const spec = LookSpec(
      id: 'redeye',
      version: 1,
      displayName: 'R',
      isFree: true,
      aspectWidth: 4,
      aspectHeight: 3,
      outputLongEdge: 64,
      jpegQuality: 90,
      flashStrength: 0.01,
      redEyeChance: 1,
    );
    final codec = _ColourCodec(30, 30, 30);
    await LookRenderer(codec: codec, faceFinder: _FixedFace()).render(
      sourcePath: 'fake.jpg',
      spec: spec,
      outPath: '${tempDir.path}/re.jpg',
      seed: 1,
      flashFired: true,
    );
    final px = codec.encodedRgba.single;
    // Left eye centre: x = 0.3 * 64, y = 0.5 * 48.
    const eye = (24 * 64 + 19) * 4;
    expect(px[eye], greaterThan(px[eye + 1] + 80));
  });

  test('an upright photo stays upright (3:4, not a 4:3 slice)', () async {
    final codec = _PortraitCodec();
    await LookRenderer(codec: codec).render(
      sourcePath: 'fake.jpg',
      spec: identityLook,
      outPath: '${tempDir.path}/portrait.jpg',
      seed: 1,
    );
    expect(codec.encodedSizes.single, (48, 64));
  });

  test('happy accidents are reproducible from the seed', () async {
    Future<Uint8List> render() async {
      final codec = _ColourCodec(120, 120, 120);
      await LookRenderer(codec: codec).render(
        sourcePath: 'fake.jpg',
        spec: identityLook,
        outPath: '${tempDir.path}/acc.jpg',
        seed: 42,
        happyAccidents: true,
      );
      return codec.encodedRgba.single;
    }

    expect(await render(), await render());
  });
}

class _FixedFace implements FaceFinder {
  @override
  Future<FaceHint?> find(ui.Image frame) async => const FaceHint(
    centerX: 0.5,
    centerY: 0.5,
    leftEyeX: 0.3,
    leftEyeY: 0.5,
    rightEyeX: 0.7,
    rightEyeY: 0.5,
    eyeRadius: 0.1,
  );
}

/// An upright (portrait) phone photo.
class _PortraitCodec extends FakeCodecChannel {
  @override
  Future<DecodedImage> decodeForRender(String path, int maxLongEdge) async {
    const w = 48;
    const h = 64;
    final rgba = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 128);
    return DecodedImage(rgba: rgba, width: w, height: h);
  }
}

/// Dark frame with one small blown-out light in the middle.
class _DotCodec extends FakeCodecChannel {
  @override
  Future<DecodedImage> decodeForRender(String path, int maxLongEdge) async {
    const w = 64;
    const h = 48;
    final rgba = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final lit = (x - 32).abs() <= 3 && (y - 24).abs() <= 3;
        final v = lit ? 255 : 20;
        rgba[i] = v;
        rgba[i + 1] = v;
        rgba[i + 2] = v;
        rgba[i + 3] = 255;
      }
    }
    return DecodedImage(rgba: rgba, width: w, height: h);
  }
}
