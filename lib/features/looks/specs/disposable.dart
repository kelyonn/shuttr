import 'package:shuttr/features/looks/look_spec.dart';

/// Disposable — single-use film camera with built-in flash. Free.
/// docs/LOOKS.md "Disposable". STARTING VALUES ONLY — see digi03.dart's
/// header comment; the same caveat applies to every spec in this folder.
const disposableLook = LookSpec(
  id: 'disposable',
  version: 1,
  displayName: 'Disposable',
  isFree: true,
  aspectWidth: 3,
  aspectHeight: 2,
  outputLongEdge: 2400,
  jpegQuality: 85,
  flashStrength: 0.7,
  flashRadius: 0.45,
  flashFalloff: 3,
  exposure: 0.05,
  contrast: 0.9,
  blackLift: 0.1,
  highlightClip: 0.9,
  saturation: 1.05,
  bloomThreshold: 0.75,
  bloomStrength: 0.3,
  halationStrength: 0.15,
  vignette: 0.5,
  chromaticAberration: 0.2,
  softness: 0.2,
  grainAmount: 0.14,
  grainSize: 2,
  chromaNoise: 0.02,
  sharpenAmount: 0.2,
  lightLeakStrength: 0.3,
);
