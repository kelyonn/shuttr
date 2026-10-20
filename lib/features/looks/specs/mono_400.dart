import 'package:shuttr/features/looks/look_spec.dart';

/// Mono 400 — black-and-white 400-speed point-and-shoot: punchy contrast,
/// visible silver grain, hard flash. Paid.
///
/// Authentic traits modelled: panchromatic channel response (the LUT mixes
/// channels rather than just desaturating, so reds/skin lighten and blue sky
/// darkens), a very slightly warm base, mid-tone-weighted grain, dust.
/// STARTING VALUES ONLY — a grade built from the documented character of the real thing (tool/lut/make_grade_lut.py), not fitted to reference shots. Tune per docs/LOOKS.md, then freeze + golden.
const mono400Look = LookSpec(
  id: 'mono_400',
  version: 2,
  displayName: 'Mono 400',
  isFree: false,
  aspectWidth: 3,
  aspectHeight: 2,
  outputLongEdge: 2400,
  jpegQuality: 88,
  lutAsset: 'assets/luts/mono_400.png',
  flashStrength: 0.8,
  flashRadius: 0.5,
  flashFalloff: 2.4,
  contrast: 1.3,
  blackLift: 0.03,
  highlightClip: 0.85,
  bloomStrength: 0.2,
  vignette: 0.4,
  softness: 0.05,
  grainAmount: 0.2,
  grainSize: 1.8,
  sharpenAmount: 0.45,
  dustAmount: 0.2,
  flashShadow: 0.4,
  hdrUndo: 0.55,
  shadowCrush: 0.04,
  highlightBlow: 0.04,
  developDenoise: 0.5,
  flashAmbientDrop: 0.6,
);
