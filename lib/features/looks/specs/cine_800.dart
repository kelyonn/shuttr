import 'package:shuttr/features/looks/look_spec.dart';

/// Cine 800T — tungsten-balanced motion-picture negative used for stills.
/// Paid.
///
/// Authentic traits modelled: cool cyan cast in daylight (tungsten stock
/// under the wrong light), teal shadows with orange highlights, strong
/// red-orange halation around bright lights,
/// heavy grain, soft contrast.
/// STARTING VALUES ONLY — a grade built from the documented character of the real thing (tool/lut/make_grade_lut.py), not fitted to reference shots. Tune per docs/LOOKS.md, then freeze + golden.
const cine800Look = LookSpec(
  id: 'cine_800',
  version: 5,
  displayName: 'Cine 800T',
  isFree: false,
  aspectWidth: 3,
  aspectHeight: 2,
  outputLongEdge: 2400,
  jpegQuality: 88,
  lutAsset: 'assets/luts/cine_800.png',
  flashStrength: 0.4,
  flashRadius: 0.5,
  flashWarmth: -0.1,
  contrast: 1.15,
  exposure: -0.1,
  glow: 0.08,
  highlightClip: 0.8,
  bloomThreshold: 0.6,
  bloomStrength: 0.3,
  halationStrength: 0.9,
  vignette: 0.32,
  chromaticAberration: 0.15,
  softness: 0.15,
  grainAmount: 0.1,
  grainSize: 2,
  sharpenAmount: 0.15,
  dustAmount: 0.2,
  hdrUndo: 0.5,
  shadowCrush: 0.02,
  developDenoise: 0.5,
  awbBias: 0.2,
  flashAmbientDrop: 0.35,
);
