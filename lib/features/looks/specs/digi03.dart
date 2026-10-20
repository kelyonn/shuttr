import 'package:shuttr/features/looks/look_spec.dart';

/// Digi '03 — 2000s CCD compact digicam. Free. docs/LOOKS.md "Digi '03".
///
/// Authentic traits modelled: cool xenon flash on a bright hotspot with a
/// fast fall to black, hard highlight clip (no roll-off), strong in-camera
/// sharpening halos, purple fringing (chromatic aberration), shadow-weighted
/// chroma noise, a bloom veil off bright areas, ~4 MP output at JPEG q80.
/// STARTING VALUES ONLY — a grade built from the documented character of the real thing (tool/lut/make_grade_lut.py), not fitted to reference shots. Tune per docs/LOOKS.md, then freeze + golden.
const digi03Look = LookSpec(
  id: 'digi03',
  version: 6,
  displayName: "Digi '03",
  isFree: true,
  aspectWidth: 4,
  aspectHeight: 3,
  outputLongEdge: 2272,
  jpegQuality: 70,
  lutAsset: 'assets/luts/digi03.png',
  dateStampDefaultOn: true,
  flashStrength: 0.75,
  flashRadius: 0.5,
  flashWarmth: -0.5,
  bloomStrength: 0.25,
  vignette: 0.3,
  chromaticAberration: 0.25,
  softness: 0.18,
  grainAmount: 0.07,
  chromaNoise: 0.16,
  sharpenAmount: 0.5,
  ccdSmear: 0.06,
  flashShadow: 0.5,
  redEyeChance: 0.25,
  viewfinder: ViewfinderKind.clean,
  soundSet: SoundSet.digicam,
  jpegPreQuality: 55,
  sensorLongEdge: 2272,
  hdrUndo: 0.2,
  highlightBlow: 0.03,
  noiseSize: 3,
  developDenoise: 0.3,
  awbBias: 0.3,
  flashAmbientDrop: 0.5,
  saturation: 1.12,
  blackLift: 0.02,
  bloomThreshold: 0.68,
  glow: 0.06,
  exposure: -0.35,
  contrast: 1.12,
  shadowCrush: 0.02,
);
