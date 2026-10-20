import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/camera/body/camera_catalog.dart';
import 'package:shuttr/features/camera/body/camera_dash.dart';
import 'package:shuttr/features/looks/look_registry.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/render/shader_uniforms.dart';

Future<(int, int)> _pngSize(String path) async {
  final bytes = Uint8List.fromList(File(path).readAsBytesSync());
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return (frame.image.width, frame.image.height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('look ids are unique and lookById finds every look', () {
    final ids = looks.map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final look in looks) {
      expect(lookById(look.id), same(look));
    }
  });

  test('pre-launch: nothing is locked (kAllLooksFree)', () {
    expect(kAllLooksFree, isTrue);
    expect(looks.where((l) => l.isLocked), isEmpty);
  });

  test('exactly the launch free looks are free', () {
    expect(
      looks.where((l) => l.isFree).map((l) => l.id),
      unorderedEquals(['digi03', 'disposable']),
    );
  });

  test('every camera has a card and its own name mark', () {
    for (final l in looks) {
      final info = cameraInfo(l.id);
      expect(info.story, isNotEmpty, reason: l.id);
      expect(info.bestFor, isNotEmpty, reason: l.id);
      expect(cameraMark(l).name, isNotEmpty, reason: l.id);
    }
  });

  test('every look survives a JSON round trip unchanged', () {
    for (final look in looks) {
      expect(LookSpec.fromJson(look.toJson()).toJson(), look.toJson());
    }
  });

  test('every look has sane, in-range parameters', () {
    for (final l in looks) {
      final reason = l.id;
      expect(l.aspectRatio, inInclusiveRange(0.5, 2.5), reason: reason);
      expect(l.outputLongEdge, inInclusiveRange(512, 4096), reason: reason);
      expect(l.jpegQuality, inInclusiveRange(30, 100), reason: reason);
      expect(l.highlightClip, inInclusiveRange(0.5, 1), reason: reason);
      expect(l.flashWarmth, inInclusiveRange(-1, 1), reason: reason);
      expect(l.lightLeakChance, inInclusiveRange(0, 1), reason: reason);
      expect(l.dustAmount, inInclusiveRange(0, 1), reason: reason);
      expect(l.vignette, inInclusiveRange(0, 1), reason: reason);
    }
  });

  test('no real brand names in look ids or display names (rule 4)', () {
    final banned = RegExp(
      'kodak|fuji|polaroid|portra|canon|sony|nikon|instax|ilford|agfa|leica',
      caseSensitive: false,
    );
    for (final l in looks) {
      expect(banned.hasMatch(l.id), isFalse, reason: l.id);
      expect(banned.hasMatch(l.displayName), isFalse, reason: l.displayName);
    }
  });

  test('every LUT is a 33^3 strip (1089x33) and exists', () async {
    for (final l in looks.where((l) => l.lutAsset != null)) {
      final (w, h) = await _pngSize(l.lutAsset!);
      expect((w, h), (33 * 33, 33), reason: l.id);
    }
  });

  test('photo LUTs actually grade: not near-identity (heavy looks)', () async {
    // Regression guard: the grades were once ~9/255 from identity and the
    // looks read as a phone photo. Mono is judged by its own tests.
    for (final id in [
      'digi03',
      'disposable',
      'instant',
      'point_and_shoot_35',
    ]) {
      final look = lookById(id);
      final bytes = File(look.lutAsset!).readAsBytesSync();
      final frame = await (await ui.instantiateImageCodec(bytes))
          .getNextFrame();
      final data = (await frame.image.toByteData())!.buffer.asUint8List();
      const n = 33;
      var total = 0.0;
      var count = 0;
      for (var b = 0; b < n; b += 4) {
        for (var g = 0; g < n; g += 4) {
          for (var r = 0; r < n; r += 4) {
            final i = (g * n * n + b * n + r) * 4;
            total +=
                ((data[i] - r * 255 / 32).abs() +
                    (data[i + 1] - g * 255 / 32).abs() +
                    (data[i + 2] - b * 255 / 32).abs()) /
                3;
            count++;
          }
        }
      }
      // Digi '03 is deliberately subtle now (natural colour, D-045).
      expect(total / count, greaterThan(id == 'digi03' ? 4 : 12), reason: id);
    }
  });

  test('every frame asset exists', () {
    for (final l in looks.where((l) => l.frameAsset != null)) {
      expect(File(l.frameAsset!).existsSync(), isTrue, reason: l.id);
    }
  });

  test('every leak texture the pipeline can pick exists', () {
    for (var i = 0; i < LeakPlacement.textureCount; i++) {
      final leak = LeakPlacement(textureIndex: i, strength: 1);
      expect(File(leak.asset).existsSync(), isTrue, reason: leak.asset);
    }
  });

  group('LeakPlacement', () {
    const leaky = LookSpec(
      id: 'x',
      version: 1,
      displayName: 'X',
      isFree: true,
      aspectWidth: 3,
      aspectHeight: 2,
      outputLongEdge: 1000,
      jpegQuality: 90,
      lightLeakStrength: 0.5,
      lightLeakChance: 1,
    );

    test('no leak when the look has none', () {
      expect(
        LeakPlacement.forShot(leaky.copyWith(lightLeakStrength: 0), 3).strength,
        0,
      );
    });

    test('same seed gives the same leak (re-develop is stable)', () {
      final a = LeakPlacement.forShot(leaky, 42);
      final b = LeakPlacement.forShot(leaky, 42);
      expect(a.textureIndex, b.textureIndex);
      expect(a.strength, b.strength);
      expect(a.flipX, b.flipX);
      expect(a.flipY, b.flipY);
    });

    test('chance 1 always leaks, chance 0 never does', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(
          LeakPlacement.forShot(leaky, seed.toDouble()).strength,
          greaterThan(0),
        );
        expect(
          LeakPlacement.forShot(
            leaky.copyWith(lightLeakChance: 0),
            seed.toDouble(),
          ).strength,
          0,
        );
      }
    });

    test('the chance is roughly honoured across many shots', () {
      final spec = leaky.copyWith(lightLeakChance: 0.3);
      var hits = 0;
      for (var seed = 0; seed < 1000; seed++) {
        if (LeakPlacement.forShot(spec, seed.toDouble()).strength > 0) hits++;
      }
      expect(hits, inInclusiveRange(220, 380));
    });
  });
}
