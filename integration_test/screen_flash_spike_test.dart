// S4 risk spike 4 (docs/BUILD_PLAN.md): does the front-camera "screen
// flash" (full-white overlay + max brightness) actually make captures
// brighter? This compares mean luma of a baseline front-camera capture
// against one taken with the screen-flash mechanism active, on whatever
// static scene is in front of the camera when the test runs — it's a
// relative brightness check, not a judgement of whether a lit face looks
// convincing (that needs a person and your own eyes — see docs/PROGRESS.md).
//
// Run with:
//   adb shell pm grant dev.shuttr.shuttr android.permission.CAMERA
//   flutter test integration_test/screen_flash_spike_test.dart -d <deviceId>

import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:screen_brightness/screen_brightness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screen-flash overlay measurably brightens a front capture',
      (tester) async {
    final cameras = await availableCameras();
    final front = cameras.where(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (front.isEmpty) {
      // Manual spike, not production code.
      // ignore: avoid_print
      print('S4 spike 4 — no front camera on this device, skipping.');
      return;
    }

    final controller = CameraController(
      front.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    // Baseline: no overlay, whatever the current screen brightness is.
    await tester.pump(const Duration(milliseconds: 300));
    final baseline = await controller.takePicture();
    final baselineLuma = _meanLuma(await File(baseline.path).readAsBytes());

    // Screen flash: full-white overlay + max brightness, matching the
    // mechanism docs/ARCHITECTURE.md "Flash" describes for the front
    // camera (no hardware flash on most Androids).
    double? originalBrightness;
    try {
      originalBrightness = await ScreenBrightness().application;
    } on Exception {
      // Some devices/emulators don't support reading brightness; proceed
      // without a restore step in that case.
    }
    await ScreenBrightness().setApplicationScreenBrightness(1);

    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredBox(color: Colors.white),
      ),
    );
    // Let the white frame actually hit the screen and eyes/subject adjust
    // before the shot, matching the real capture flow's intent.
    await tester.pump(const Duration(milliseconds: 400));

    final flashed = await controller.takePicture();
    final flashedLuma = _meanLuma(await File(flashed.path).readAsBytes());

    if (originalBrightness != null) {
      await ScreenBrightness().setApplicationScreenBrightness(
        originalBrightness,
      );
    }

    // Manual timing/brightness spike, not production code.
    // ignore: avoid_print
    print(
      'S4 spike 4 — mean luma baseline=$baselineLuma flashed=$flashedLuma '
      '(delta=${flashedLuma - baselineLuma})',
    );

    expect(
      flashedLuma,
      greaterThan(baselineLuma),
      reason:
          'Screen-flash capture should be measurably brighter than the '
          'baseline on the same static scene',
    );
  });
}

double _meanLuma(Uint8List jpegBytes) {
  final image = img.decodeJpg(jpegBytes);
  if (image == null) {
    throw StateError('Failed to decode captured JPEG for luma measurement');
  }
  var total = 0.0;
  var count = 0;
  // Sample every 8th pixel — plenty for a mean-brightness comparison and
  // much faster than every pixel on a full-res capture.
  for (var y = 0; y < image.height; y += 8) {
    for (var x = 0; x < image.width; x += 8) {
      final pixel = image.getPixel(x, y);
      total += 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
      count++;
    }
  }
  return total / count;
}
