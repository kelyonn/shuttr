import 'dart:math' as math;

import 'package:shuttr/features/looks/look_spec.dart';

/// What went "wrong" on one shot when Happy Accidents is on.
class Accidents {
  const new({
    this.exposureDrift = 0,
    this.flashMisfired = false,
    this.missedFocus = false,
  });

  static const none = Accidents();

  final double exposureDrift;
  final bool flashMisfired;
  final bool missedFocus;
}

/// Real cheap cameras were inconsistent: auto-exposure drifts a little
/// between frames, the flash sometimes doesn't recharge in time, and
/// fixed/zone focus misses now and then. Derived from the shot's seed, so a
/// re-develop reproduces exactly the same accident.
Accidents accidentsFor(double seed, {required bool flashFired}) {
  final rng = math.Random(seed.round() + 7919);
  return Accidents(
    // ±0.35 EV, biased toward small drifts.
    exposureDrift: (rng.nextDouble() - 0.5) * 0.7 * rng.nextDouble(),
    flashMisfired: flashFired && rng.nextDouble() < 1 / 12,
    missedFocus: rng.nextDouble() < 1 / 18,
  );
}

LookSpec applyAccidents(LookSpec spec, Accidents a) {
  if (identical(a, Accidents.none)) return spec;
  return spec.copyWith(
    exposure: spec.exposure + a.exposureDrift,
    softness: a.missedFocus ? math.min(1, spec.softness + 0.45) : spec.softness,
  );
}
