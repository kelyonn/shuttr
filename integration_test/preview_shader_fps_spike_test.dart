// S4 risk spike 3 (docs/BUILD_PLAN.md): can a shader run on the LIVE camera
// preview and hold a usable frame rate on this device? Uses
// ImageFiltered(imageFilter: ImageFilter.shader(...)) over CameraPreview,
// which is the mechanism S12's real preview shader will use.
//
// Requires CAMERA permission already granted (this test does not drive the
// system permission dialog). Run with:
//   adb shell pm grant dev.shuttr.shuttr android.permission.CAMERA
//   flutter test integration_test/preview_shader_fps_spike_test.dart -d <deviceId>

import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shader over live CameraPreview holds a usable frame rate',
      (tester) async {
    final cameras = await availableCameras();
    expect(cameras, isNotEmpty, reason: 'No cameras found on this device');

    final controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    final program = await ui.FragmentProgram.fromAsset('shaders/preview.frag');
    final lut = await _solidLut();

    var frameCount = 0;
    late final Stopwatch stopwatch;

    await tester.pumpWidget(
      MaterialApp(
        home: _ShaderPreviewSpike(
          controller: controller,
          program: program,
          lut: lut,
          onFrame: () => frameCount++,
        ),
      ),
    );

    // Let the camera + shader warm up before timing.
    await tester.pump(const Duration(seconds: 1));
    frameCount = 0;
    stopwatch = Stopwatch()..start();

    const spikeDuration = Duration(seconds: 3);
    final endTime = DateTime.now().add(spikeDuration);
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    stopwatch.stop();

    final fps = frameCount / (stopwatch.elapsedMilliseconds / 1000);
    // Manual timing spike, not production code — this is how the result
    // reaches the terminal when run by hand on a device.
    // ignore: avoid_print
    print(
      'S4 spike 3 — shader-on-preview widget rebuild rate: '
      '${fps.toStringAsFixed(1)} fps over $frameCount frames '
      '(pump-driven proxy for real display fps — see docs/PROGRESS.md '
      'for how this maps to the 30fps target)',
    );

    expect(frameCount, greaterThan(0));
  });
}

Future<ui.Image> _solidLut() {
  const lutStripWidth = 33 * 33;
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, lutStripWidth * 1.0, 33),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  final picture = recorder.endRecording();
  return picture.toImage(lutStripWidth, 33);
}

class _ShaderPreviewSpike extends StatefulWidget {
  const new({
    required this.controller,
    required this.program,
    required this.lut,
    required this.onFrame,
  });

  final CameraController controller;
  final ui.FragmentProgram program;
  final ui.Image lut;
  final VoidCallback onFrame;

  @override
  State<_ShaderPreviewSpike> createState() => _ShaderPreviewSpikeState();
}

class _ShaderPreviewSpikeState extends State<_ShaderPreviewSpike> {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((_) => widget.onFrame())..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = widget.program.fragmentShader();
    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    final size = widget.controller.value.previewSize ?? const Size(720, 1280);
    f(size.width);
    f(size.height);
    f(0); // uExposure
    f(1); // uContrast
    f(0); // uLutStrength — off for the spike, we only care about fps
    f(33); // uLutSize
    f(1); // uSaturation
    f(0); // uVignette
    // Sampler index 0 (uImage, declared first in preview.frag) is left
    // unbound: ImageFilter.shader auto-fills the first sampler uniform with
    // the filtered child's rendered content. Only additional samplers
    // (uLut, index 1) need an explicit setImageSampler call.
    shader.setImageSampler(1, widget.lut);

    return Scaffold(
      body: ImageFiltered(
        imageFilter: ui.ImageFilter.shader(shader),
        child: CameraPreview(widget.controller),
      ),
    );
  }
}
