import 'package:shuttr/features/looks/look_spec.dart';

/// Instant — instant film print. Paid. docs/LOOKS.md "Instant".
/// STARTING VALUES ONLY — see digi03.dart's header comment.
///
/// `frameAsset` (the white border, thicker at the bottom) is added once
/// assets/frames/instant.png exists — see docs/BUILD_PLAN.md S10.
const instantLook = LookSpec(
  id: 'instant',
  version: 1,
  displayName: 'Instant',
  isFree: false,
  aspectWidth: 1,
  aspectHeight: 1,
  outputLongEdge: 2000,
  jpegQuality: 90,
  flashStrength: 0.4,
  flashRadius: 0.5,
  flashFalloff: 1.5,
  exposure: 0.15,
  contrast: 0.75,
  blackLift: 0.18,
  highlightClip: 0.7,
  saturation: 0.75,
  bloomThreshold: 0.7,
  bloomStrength: 0.35,
  vignette: 0.35,
  chromaticAberration: 0.15,
  softness: 0.35,
  grainAmount: 0.05,
  grainSize: 1.2,
);
