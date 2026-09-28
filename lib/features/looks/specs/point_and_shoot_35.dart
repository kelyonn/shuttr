import 'package:shuttr/features/looks/look_spec.dart';

/// Point & Shoot 35 — 35mm compact film camera, lab-scanned colour negative
/// tones. Paid. docs/LOOKS.md "Point & Shoot 35". STARTING VALUES ONLY —
/// see digi03.dart's header comment.
const pointAndShoot35Look = LookSpec(
  id: 'point_and_shoot_35',
  version: 1,
  displayName: 'Point & Shoot 35',
  isFree: false,
  aspectWidth: 3,
  aspectHeight: 2,
  outputLongEdge: 3000,
  jpegQuality: 92,
  flashStrength: 0.55,
  flashRadius: 0.5,
  exposure: 0.1,
  contrast: 0.95,
  blackLift: 0.08,
  highlightClip: 0.88,
  saturation: 0.95,
  bloomThreshold: 0.65,
  bloomStrength: 0.4,
  halationStrength: 0.6,
  vignette: 0.15,
  chromaticAberration: 0.1,
  softness: 0.05,
  grainAmount: 0.06,
  sharpenAmount: 0.1,
);
