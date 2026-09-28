// S4 risk spike 2 (docs/BUILD_PLAN.md, D-022 in docs/DECISIONS.md):
// does `ui.FragmentProgram` render inside `flutter test` (headless), or do
// golden tests need to run as an on-device `integration_test` instead?
//
// Result of this spike is recorded in docs/DECISIONS.md when this file is
// first run successfully or found to fail.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FragmentProgram loads and renders under flutter test', () async {
    final program = await ui.FragmentProgram.fromAsset('shaders/look.frag');
    final shader = program.fragmentShader();

    // Build a tiny 2x2 source image and a 1x33 LUT stand-in so the shader
    // has valid samplers bound; we're only checking that rendering doesn't
    // throw / hang here, not verifying pixel-perfect output (that's the
    // golden tests once a look is tuned).
    final source = await _solidImage(2, 2, 0xFFFF8800);
    final lut = await _solidImage(33 * 33, 33, 0xFFFFFFFF);

    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    f(2); // uSize.x
    f(2); // uSize.y
    f(0); // uFlashFired
    f(0); // uFlashStrength
    f(0.6); // uFlashRadius
    f(2); // uFlashFalloff
    f(0); // uExposure
    f(1); // uContrast
    f(0); // uBlackLift
    f(1); // uHighlightClip
    f(1); // uLutStrength
    f(33); // uLutSize
    f(1); // uSaturation
    f(0); // uBloomStrength
    f(0); // uHalationStrength
    f(0); // uVignette
    f(0); // uChromaticAberration
    f(0); // uSoftness
    f(0); // uGrainAmount
    f(1); // uGrainSize
    f(0); // uChromaNoise
    f(0); // uSharpenAmount
    f(1); // uSeed

    shader
      ..setImageSampler(0, source)
      ..setImageSampler(1, source)
      ..setImageSampler(2, source)
      ..setImageSampler(3, lut);

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 2, 2),
      ui.Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(2, 2);

    final bytes = await image.toByteData();
    expect(bytes, isNotNull);
    expect(bytes!.lengthInBytes, 2 * 2 * 4);
  });
}

Future<ui.Image> _solidImage(int width, int height, int argb) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = ui.Color(argb),
  );
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}
