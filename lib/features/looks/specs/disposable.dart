import 'package:shuttr/features/looks/look_spec.dart';

/// Disposable — single-use film camera with built-in flash. Free.
/// docs/LOOKS.md "Disposable".
///
/// Authentic traits modelled: plastic meniscus lens (heavy vignette, soft
/// edges, mild fringing), a warm on-camera flash that falls off fast,
/// cheap-lab-scan colour (warm, green-leaning shadows), visible film grain,
/// occasional light leaks and dust on the scan.
/// STARTING VALUES ONLY — a grade built from the documented character of the real thing (tool/lut/make_grade_lut.py), not fitted to reference shots. Tune per docs/LOOKS.md, then freeze + golden.
const disposableLook = LookSpec(
  id: 'disposable',
  version: 4,
  displayName: 'Disposable',
  isFree: true,
  aspectWidth: 3,
  aspectHeight: 2,
  outputLongEdge: 2400,
  jpegQuality: 82,
  lutAsset: 'assets/luts/disposable.png',
  flashStrength: 0.9,
  flashRadius: 0.55,
  flashFalloff: 2.4,
  flashWarmth: 0.1,
  exposure: 0.05,
  contrast: 1.15,
  blackLift: 0.11,
  highlightClip: 0.85,
  bloomThreshold: 0.75,
  bloomStrength: 0.18,
  halationStrength: 0.15,
  vignette: 0.6,
  chromaticAberration: 0.5,
  softness: 0.38,
  grainAmount: 0.14,
  grainSize: 2.2,
  chromaNoise: 0.03,
  sharpenAmount: 0.1,
  lightLeakStrength: 0.35,
  lightLeakChance: 0.3,
  dustAmount: 0.35,
  flashShadow: 0.5,
  redEyeChance: 0.2,
  soundSet: SoundSet.disposable,
  hdrUndo: 0.5,
  highlightBlow: 0.02,
  noiseSize: 2,
  developDenoise: 0.55,
  awbBias: 0.4,
  flashAmbientDrop: 0.7,
);
