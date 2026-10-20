import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttr/features/looks/render/develop.dart';

/// Thumbnail made of [pixels] (r, g, b) values, repeated to fill 64x48.
Uint8List _thumb(List<(int, int, int)> pixels) {
  const n = 64 * 48;
  final out = Uint8List(n * 4);
  for (var i = 0; i < n; i++) {
    final (r, g, b) = pixels[i % pixels.length];
    out
      ..[i * 4] = r
      ..[i * 4 + 1] = g
      ..[i * 4 + 2] = b
      ..[i * 4 + 3] = 255;
  }
  return out;
}

(int, int, int) _grey(int v) => (v, v, v);

void main() {
  test('a flat swatch is left alone', () {
    final c = DevelopCorrection.measure(_thumb([(200, 90, 40)]));
    expect(c.isIdentity, isTrue);
  });

  test('a well-exposed neutral scene is left alone', () {
    final c = DevelopCorrection.measure(
      _thumb([for (var v = 0; v <= 255; v += 5) _grey(v)]),
    );
    expect(c.black, 0);
    expect(c.white, 1);
    expect(c.gains.$2, closeTo(1, 0.001));
  });

  test('hazy blacks come down, dim whites go up, partway and capped', () {
    // Range 0.2 .. 0.6: a foggy, underexposed phone shot.
    final c = DevelopCorrection.measure(
      _thumb([for (var v = 51; v <= 153; v += 3) _grey(v)]),
    );
    expect(c.black, greaterThan(0));
    expect(c.black, lessThanOrEqualTo(0.06));
    expect(c.white, lessThan(1));
    expect(c.white, greaterThanOrEqualTo(0.8)); // at most +25% gain
  });

  test('a green cast is pulled back, a warm cast is not', () {
    final scene = [for (var v = 40; v <= 220; v += 10) v];
    final green = DevelopCorrection.measure(
      _thumb([for (final v in scene) (v, (v * 1.06).round(), v)]),
    );
    expect(green.gains.$2, lessThan(green.gains.$1));

    final warm = DevelopCorrection.measure(
      _thumb([
        for (final v in scene) ((v * 1.06).round(), v, (v * 0.94).round()),
      ]),
    );
    // Red and blue move together: the warm/cool axis is untouched.
    expect(warm.gains.$1, closeTo(warm.gains.$3, 0.001));
  });
}
