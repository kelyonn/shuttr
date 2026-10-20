import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/looks/look_spec.dart';
import 'package:shuttr/features/looks/specs/identity.dart';

void main() {
  group('LookSpec', () {
    test('new character params default to neutral', () {
      expect(identityLook.hdrUndo, 0);
      expect(identityLook.shadowCrush, 0);
      expect(identityLook.highlightBlow, 0);
      expect(identityLook.awbBias, 0);
      expect(identityLook.jpegPreQuality, 0);
    });

    test('round-trips through JSON', () {
      final spec = identityLook.copyWith(
        flashStrength: 0.8,
        grainAmount: 0.3,
        hdrUndo: 0.7,
        jpegPreQuality: 55,
      );

      final decoded = LookSpec.fromJson(spec.toJson());

      expect(decoded.id, spec.id);
      expect(decoded.version, spec.version);
      expect(decoded.aspectRatio, spec.aspectRatio);
      expect(decoded.flashStrength, spec.flashStrength);
      expect(decoded.hdrUndo, 0.7);
      expect(decoded.jpegPreQuality, 55);
      expect(decoded.grainAmount, spec.grainAmount);
      expect(decoded.toJson(), spec.toJson());
    });

    test('fromJson fills defaults for missing optional fields', () {
      final minimal = LookSpec.fromJson({
        'id': 'x',
        'version': 1,
        'displayName': 'X',
        'isFree': true,
        'aspectWidth': 1,
        'aspectHeight': 1,
        'outputLongEdge': 1000,
        'jpegQuality': 90,
      });

      expect(minimal.flashStrength, 0);
      expect(minimal.contrast, 1);
      expect(minimal.lutAsset, isNull);
    });

    test('aspectRatio is width/height', () {
      expect(identityLook.aspectRatio, closeTo(4 / 3, 0.0001));
    });

    test('copyWith only changes the given fields', () {
      final changed = identityLook.copyWith(exposure: 0.5);
      expect(changed.exposure, 0.5);
      expect(changed.id, identityLook.id);
      expect(changed.outputLongEdge, identityLook.outputLongEdge);
    });
  });
}
