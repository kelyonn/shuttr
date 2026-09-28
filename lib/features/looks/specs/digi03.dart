import 'package:shuttr/features/looks/look_spec.dart';

/// Digi '03 — 2000s CCD digicam. Free. docs/LOOKS.md "Digi '03".
///
/// STARTING VALUES ONLY. These are a first guess from the qualitative
/// description in docs/LOOKS.md, not the result of tuning against a real
/// reference camera. Tune with the debug tuning screen (S5) against
/// reference/digi03/ once those shots exist, then this becomes the frozen,
/// golden-tested version (docs/BUILD_PLAN.md M3, Gate 0 in docs/ROADMAP.md).
/// `lutAsset` stays null (falls back to the neutral identity LUT) until a
/// real LUT is built from reference shots (tool/lut/build_lut.py).
const digi03Look = LookSpec(
  id: 'digi03',
  version: 1,
  displayName: "Digi '03",
  isFree: true,
  aspectWidth: 4,
  aspectHeight: 3,
  outputLongEdge: 2272, // ~4MP, matches an early-2000s CCD compact
  jpegQuality: 80,
  dateStampDefaultOn: true,
  flashStrength: 0.75,
  flashRadius: 0.55,
  flashFalloff: 2.2,
  exposure: 0.1,
  contrast: 1.2,
  blackLift: 0.02,
  highlightClip: 0.82,
  saturation: 1.15,
  bloomThreshold: 0.85,
  bloomStrength: 0.25,
  vignette: 0.25,
  chromaticAberration: 0.4,
  softness: 0.08,
  grainAmount: 0.03,
  chromaNoise: 0.06,
  sharpenAmount: 0.7,
);
