import 'package:shuttr/features/looks/look_spec.dart';

/// Point & Shoot 35 — 35mm compact film camera, lab-scanned consumer colour
/// negative. Paid. docs/LOOKS.md "Point & Shoot 35".
///
/// Authentic traits modelled: warm flattering skin, restrained greens, wide
/// highlight latitude (soft shoulder), the red-orange halation around bright
/// lights that colour negative shows (the signature), fine organic grain,
/// scan-resolution output.
/// STARTING VALUES ONLY — a grade built from the documented character of the real thing (tool/lut/make_grade_lut.py), not fitted to reference shots. Tune per docs/LOOKS.md, then freeze + golden.
const pointAndShoot35Look = LookSpec(
  id: 'point_and_shoot_35',
  version: 3,
  displayName: 'Point & Shoot 35',
  isFree: false,
  aspectWidth: 3,
  aspectHeight: 2,
  outputLongEdge: 3000,
  jpegQuality: 88,
  lutAsset: 'assets/luts/point_and_shoot_35.png',
  flashStrength: 0.7,
  flashRadius: 0.55,
  flashFalloff: 1.5,
  flashWarmth: 0.05,
  exposure: 0.1,
  blackLift: 0.03,
  highlightClip: 0.78,
  bloomThreshold: 0.7,
  bloomStrength: 0.5,
  halationStrength: 0.8,
  vignette: 0.18,
  chromaticAberration: 0.2,
  softness: 0.12,
  grainAmount: 0.07,
  grainSize: 1.3,
  sharpenAmount: 0.25,
  dustAmount: 0.04,
  flashShadow: 0.3,
  redEyeChance: 0.15,
  hdrUndo: 0.3,
  contrast: 1.12,
  shadowCrush: 0.02,
  highlightBlow: 0.01,
  developDenoise: 0.5,
  awbBias: 0.25,
  flashAmbientDrop: 0.4,
);
