// Many sequential canvas draws read better uncascaded.
// ignore_for_file: cascade_invocations

// Manual visual check, not an assertion test: renders a synthetic scene
// (sky, skin-tone subject, point lights, colour patches, hard edges) through
// every look and writes PNGs so the looks can be eyeballed side by side.
//
//   SHEET_DIR=/tmp/sheet flutter test test/looks/look_contact_sheet_test.dart
//
// Skipped unless SHEET_DIR is set. Not a substitute for reference photos
// (docs/LOOKS.md); it only proves every look renders and lets you compare
// them against each other.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/core/platform/codec_channel.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/specs/identity.dart';
import 'package:shuttr/features/looks/render/look_renderer.dart';

class _SceneCodec implements CodecChannel {
  Uint8List? lastRgba;
  int lastW = 0;
  int lastH = 0;

  @override
  Future<DecodedImage> decodeForRender(String path, int maxLongEdge) async {
    // The JPEG round trip: this fake can't really compress, so hand back
    // what was just "encoded".
    if (path.endsWith('.pre.jpg') && lastRgba != null) {
      return DecodedImage(rgba: lastRgba!, width: lastW, height: lastH);
    }
    final img = Platform.environment['SCENE_IMG'];
    if (img != null) {
      // A real photo, when given, judges grades far better than the
      // synthetic scene.
      final codec = await ui.instantiateImageCodec(
        File(img).readAsBytesSync(),
        targetWidth: maxLongEdge.clamp(320, 1500),
      );
      final frame = (await codec.getNextFrame()).image;
      final bytes = (await frame.toByteData())!;
      return DecodedImage(
        rgba: bytes.buffer.asUint8List(),
        width: frame.width,
        height: frame.height,
      );
    }
    final long = maxLongEdge.clamp(320, 1500);
    final w = long;
    final h = (long * 2 / 3).round();
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec)..scale(w / 1200.0);
    // Sky → horizon gradient.
    c.drawRect(
      const Rect.fromLTWH(0, 0, 1200, 800),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(0, 800),
          [
            const Color(0xFF3F79C9),
            const Color(0xFFBFD7EE),
            const Color(0xFF6E8A4B),
            const Color(0xFF3B4F2A),
          ],
          [0, 0.45, 0.5, 1],
        ),
    );
    // Sun-lit wall + window light.
    c.drawRect(
      const Rect.fromLTWH(760, 120, 340, 380),
      Paint()..color = const Color(0xFFD8C6A5),
    );
    c.drawRect(
      const Rect.fromLTWH(820, 170, 120, 150),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    // Subject: skin-tone head + red jacket.
    c.drawOval(
      const Rect.fromLTWH(390, 200, 190, 240),
      Paint()..color = const Color(0xFFD9A07F),
    );
    c.drawRect(
      const Rect.fromLTWH(330, 450, 310, 350),
      Paint()..color = const Color(0xFFB02A2A),
    );
    c.drawOval(
      const Rect.fromLTWH(430, 300, 30, 16),
      Paint()..color = const Color(0xFF3A2A22),
    );
    c.drawOval(
      const Rect.fromLTWH(510, 300, 30, 16),
      Paint()..color = const Color(0xFF3A2A22),
    );
    // Point lights (bloom / halation test) on dark ground.
    for (var i = 0; i < 6; i++) {
      c.drawCircle(
        Offset(90.0 + i * 55, 620),
        10,
        Paint()..color = const Color(0xFFFFF3D0),
      );
    }
    // Colour patches: skin-ish, foliage, sky, red, yellow, grey ramp.
    const patches = [
      Color(0xFFC79A7E),
      Color(0xFF5E7A3F),
      Color(0xFF5D8FD0),
      Color(0xFFC8302E),
      Color(0xFFE6C22B),
      Color(0xFF7A3F8C),
    ];
    for (var i = 0; i < patches.length; i++) {
      c.drawRect(
        Rect.fromLTWH(700.0 + i * 80, 560, 76, 70),
        Paint()..color = patches[i],
      );
    }
    for (var i = 0; i < 8; i++) {
      final v = (i * 255 / 7).round();
      c.drawRect(
        Rect.fromLTWH(700.0 + i * 60, 650, 58, 60),
        Paint()..color = Color.fromARGB(255, v, v, v),
      );
    }
    // Hard black/white edges (sharpen halos, fringing).
    for (var i = 0; i < 8; i++) {
      c.drawRect(
        Rect.fromLTWH(60.0 + i * 24, 700, 12, 80),
        Paint()..color = const Color(0xFF000000),
      );
    }
    final image = rec.endRecording().toImageSync(w, h);
    final data = (await image.toByteData())!;
    return DecodedImage(rgba: data.buffer.asUint8List(), width: w, height: h);
  }

  @override
  Future<void> encodeJpeg({
    required Uint8List rgba,
    required int width,
    required int height,
    required int quality,
    required String outPath,
  }) async {
    lastRgba = rgba;
    lastW = width;
    lastH = height;
  }

  @override
  Future<DateTime?> readCaptureDate(String path) async => null;

  @override
  Future<bool?> readFlashFired(String path) async => null;
}

Future<void> _writePng(Uint8List rgba, int w, int h, String path) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    w,
    h,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dir = Platform.environment['SHEET_DIR'];

  test(
    'render every look for the contact sheet',
    () async {
      Directory(dir!).createSync(recursive: true);
      for (final flash in [false, true]) {
        for (final look in [
          ...looks,
          if (Platform.environment['WITH_ID'] != null) identityLook,
        ]) {
          final codec = _SceneCodec();
          await LookRenderer(codec: codec).render(
            sourcePath: 'scene',
            spec: look,
            outPath: 'unused',
            seed: 7,
            flashFired: flash,
            develop: Platform.environment['NO_DEVELOP'] == null,
          );
          await _writePng(
            codec.lastRgba!,
            codec.lastW,
            codec.lastH,
            '$dir/${look.id}${flash ? '_flash' : ''}.png',
          );
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: dir == null ? 'set SHEET_DIR to run' : false,
  );
}
