// S4 risk spike 1 (docs/BUILD_PLAN.md): does a full-res render complete in
// a reasonable time with no crash on a real device? The build plan's bar is
// "≤3s, no OOM, on a budget phone (3-4GB RAM)". No budget phone was
// available when this spike was first run — see the printed device info
// and docs/PROGRESS.md for which device actually produced the timing below.
//
// Run with:
//   flutter test integration_test/render_perf_spike_test.dart -d <deviceId>

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full-res render of a 12MP photo completes quickly, no crash',
      (tester) async {
    // Simulate a 12MP phone-camera photo (4032x3008, a common sensor size)
    // with enough visual complexity (gradient + shapes) that the shader
    // isn't just processing flat colour.
    final sourcePath = await _writeSyntheticPhoto(4032, 3008);

    // A "heavy" spec: every stage that costs GPU/CPU time turned on, so
    // this is a worst case rather than a best case for render time.
    const heavySpec = LookSpec(
      id: 'spike-heavy',
      version: 1,
      displayName: 'Spike (heavy)',
      isFree: true,
      aspectWidth: 4,
      aspectHeight: 3,
      outputLongEdge: 2272, // Digi '03 target, docs/LOOKS.md
      jpegQuality: 80,
      flashStrength: 0.8,
      exposure: 0.2,
      contrast: 1.15,
      blackLift: 0.03,
      highlightClip: 0.85,
      saturation: 1.1,
      bloomStrength: 0.4,
      halationStrength: 0.3,
      vignette: 0.5,
      chromaticAberration: 0.6,
      softness: 0.15,
      grainAmount: 0.08,
      grainSize: 1.5,
      chromaNoise: 0.05,
      sharpenAmount: 0.6,
    );

    final renderer = LookRenderer(codec: MethodChannelCodec());
    final tempDir = await getTemporaryDirectory();
    final outPath = '${tempDir.path}/spike_render_out.jpg';

    final result = await renderer.render(
      sourcePath: sourcePath,
      spec: heavySpec,
      outPath: outPath,
      flashFired: true,
      seed: 42,
    );

    // Manual timing spike, not production code — this is how the result
    // reaches the terminal when run by hand on a device.
    // ignore: avoid_print
    print(
      'S4 spike 1 — render time: ${result.renderMs}ms on this device '
      '(no budget phone connected — treat as a proxy, not the final number)',
    );

    expect(File(outPath).existsSync(), isTrue);
    expect(
      File(outPath).lengthSync(),
      greaterThan(0),
      reason: 'Rendered JPEG should not be empty',
    );

    // The plan's bar is ≤3s on a BUDGET phone. This device is likely
    // faster, so we assert a generous upper bound here mainly to catch
    // catastrophic regressions (e.g. an accidental O(n^2) pass), not to
    // certify budget-phone performance.
    expect(
      result.renderMs,
      lessThan(8000),
      reason: 'Render took far longer than expected even as a proxy result',
    );
  });
}

Future<String> _writeSyntheticPhoto(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  final gradient = ui.Gradient.linear(
    ui.Offset.zero,
    ui.Offset(width.toDouble(), height.toDouble()),
    [const ui.Color(0xFFFFC080), const ui.Color(0xFF203050)],
  );
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..shader = gradient,
  );

  // A grid of circles gives the shader real edges to sharpen/alias against,
  // closer to a real photo than a flat gradient.
  final circlePaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  for (var y = 0; y < height; y += 160) {
    for (var x = 0; x < width; x += 160) {
      canvas.drawCircle(
        ui.Offset(x.toDouble(), y.toDouble()),
        40,
        circlePaint,
      );
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/spike_source_photo.png');
  await file.writeAsBytes(pngBytes!.buffer.asUint8List());
  return file.path;
}
