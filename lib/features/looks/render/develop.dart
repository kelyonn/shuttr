import 'dart:math' as math;
import 'dart:typed_data';

/// The "develop" stage: evens out what different phones hand us before any
/// look is applied, so a ₹10k phone and a flagship feed the look the same
/// kind of image (docs/LOOK_RESEARCH.md §4).
///
/// Measured per shot on a small thumbnail, applied as one colour matrix
/// during the crop pass (no extra full-resolution pass):
/// - levels: pull a hazy black point down and lift a dim white point, both
///   partway, never inventing contrast in a genuinely flat scene;
/// - tint: correct only the green↔magenta axis of the neutral mid-tones.
///   Warm/cool is left alone: golden hour and tungsten are the scene.
class DevelopCorrection {
  const new({this.black = 0, this.white = 1, this.gains = const (1, 1, 1)});

  /// Measures [rgba] (a thumbnail, RGBA8888) and returns the correction.
  factory measure(Uint8List rgba, {double awbBias = 0}) {
    final n = rgba.length ~/ 4;
    if (n == 0) return identity;

    final hist = List<int>.filled(256, 0);
    var nr = 0.0;
    var ng = 0.0;
    var nb = 0.0;
    var neutral = 0;
    for (var i = 0; i < n; i++) {
      final r = rgba[i * 4];
      final g = rgba[i * 4 + 1];
      final b = rgba[i * 4 + 2];
      final y = (0.2126 * r + 0.7152 * g + 0.0722 * b).round().clamp(0, 255);
      hist[y]++;
      final chroma = math.max(r, math.max(g, b)) - math.min(r, math.min(g, b));
      if (y > 30 && y < 225 && chroma < 50) {
        nr += r;
        ng += g;
        nb += b;
        neutral++;
      }
    }

    double percentile(double p) {
      final target = n * p;
      var acc = 0;
      for (var v = 0; v < 256; v++) {
        acc += hist[v];
        if (acc >= target) return v / 255;
      }
      return 1;
    }

    final lo = percentile(0.005);
    final hi = percentile(0.995);

    var black = 0.0;
    var white = 1.0;
    // A flat scene (fog, a wall, a test swatch) stays flat.
    if (hi - lo >= 0.15) {
      black = (lo - 0.02).clamp(0.0, 0.10) * 0.6;
      if (hi < 0.95) {
        // Close 60% of the gap to white, at most +25% gain.
        white = math.max(hi + (1 - hi) * 0.4, 0.8);
      }
    }

    var gains = (1.0, 1.0, 1.0);
    if (neutral >= n * 0.05) {
      final r = nr / neutral;
      final g = ng / neutral;
      final b = nb / neutral;
      final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      final tint = (g - (r + b) / 2) / y;
      final gG = 1 - (tint * 0.5).clamp(-0.06, 0.06);
      // Keep the neutral's brightness where it was.
      final k = y / (0.2126 * r + 0.7152 * g * gG + 0.0722 * b);
      var gR = k;
      var gB = k;
      if (awbBias > 0) {
        // A cheap camera's auto white balance under-corrected: push the
        // scene's warm/cool cast further instead of removing it.
        final cast = ((r - b) / y).clamp(-0.5, 0.5);
        final amp = 1 + cast * awbBias * 0.6;
        gR *= amp;
        gB /= amp;
      }
      gains = (gR, gG * k, gB);
    }

    return DevelopCorrection(black: black, white: white, gains: gains);
  }

  static const identity = DevelopCorrection();

  final double black;
  final double white;
  final (double, double, double) gains;

  bool get isIdentity => black == 0 && white == 1 && gains == (1.0, 1.0, 1.0);

  /// As a `ColorFilter.matrix` (offsets in 0-255 units):
  /// out = gain * (in - black) / (white - black).
  List<double> get colorMatrix {
    final s = 1 / (white - black);
    final (gr, gg, gb) = gains;
    return <double>[
      gr * s, 0, 0, 0, -gr * s * black * 255, //
      0, gg * s, 0, 0, -gg * s * black * 255,
      0, 0, gb * s, 0, -gb * s * black * 255,
      0, 0, 0, 1, 0,
    ];
  }
}
