// S4 risk spike 2 (docs/BUILD_PLAN.md, D-022 in docs/DECISIONS.md):
// does `ui.FragmentProgram` render inside `flutter test` (headless), or do
// golden tests need to run as an on-device `integration_test` instead?
//
// Result of this spike is recorded in docs/DECISIONS.md when this file is
// first run successfully or found to fail.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/looks/render/shader_uniforms.dart';
import 'package:shuttr/features/looks/specs/identity.dart';

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

    bindLookUniforms(
      shader,
      spec: identityLook,
      width: 2,
      height: 2,
      flashFired: false,
      seed: 1,
    );
    bindLookSamplers(
      shader,
      image: source,
      blurSmall: source,
      bloom: source,
      lut: lut,
      leak: source,
      smear: source,
    );

    final recorder = ui.PictureRecorder();
    ui.Canvas(
      recorder,
    ).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint()..shader = shader);
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
