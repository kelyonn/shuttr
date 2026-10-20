import 'package:shuttr/features/looks/look_spec.dart';

/// One tunable slider on the tuning screen: reads a [LookSpec] field and
/// writes it back via [LookSpec.copyWith]. Adding a new tunable param is
/// one entry in [tuningParams] — see docs/BUILD_PLAN.md S5.
class ParamDescriptor {
  const new({
    required this.label,
    required this.get,
    required this.apply,
    required this.min,
    required this.max,
  });

  final String label;
  final double Function(LookSpec spec) get;
  final LookSpec Function(LookSpec spec, double value) apply;
  final double min;
  final double max;
}

final tuningParams = <ParamDescriptor>[
  ParamDescriptor(
    label: 'Flash strength',
    get: (s) => s.flashStrength,
    apply: (s, v) => s.copyWith(flashStrength: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Flash radius',
    get: (s) => s.flashRadius,
    apply: (s, v) => s.copyWith(flashRadius: v),
    min: 0.1,
    max: 1.5,
  ),
  ParamDescriptor(
    label: 'Flash falloff',
    get: (s) => s.flashFalloff,
    apply: (s, v) => s.copyWith(flashFalloff: v),
    min: 0.5,
    max: 6,
  ),
  ParamDescriptor(
    label: 'Flash warmth',
    get: (s) => s.flashWarmth,
    apply: (s, v) => s.copyWith(flashWarmth: v),
    min: -1,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Exposure',
    get: (s) => s.exposure,
    apply: (s, v) => s.copyWith(exposure: v),
    min: -2,
    max: 2,
  ),
  ParamDescriptor(
    label: 'Contrast',
    get: (s) => s.contrast,
    apply: (s, v) => s.copyWith(contrast: v),
    min: 0.5,
    max: 1.8,
  ),
  ParamDescriptor(
    label: 'Black lift',
    get: (s) => s.blackLift,
    apply: (s, v) => s.copyWith(blackLift: v),
    min: 0,
    max: 0.4,
  ),
  ParamDescriptor(
    label: 'Highlight clip',
    get: (s) => s.highlightClip,
    apply: (s, v) => s.copyWith(highlightClip: v),
    min: 0.4,
    max: 1,
  ),
  ParamDescriptor(
    label: 'LUT strength',
    get: (s) => s.lutStrength,
    apply: (s, v) => s.copyWith(lutStrength: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Saturation',
    get: (s) => s.saturation,
    apply: (s, v) => s.copyWith(saturation: v),
    min: 0,
    max: 2,
  ),
  ParamDescriptor(
    label: 'Bloom threshold',
    get: (s) => s.bloomThreshold,
    apply: (s, v) => s.copyWith(bloomThreshold: v),
    min: 0.3,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Bloom strength',
    get: (s) => s.bloomStrength,
    apply: (s, v) => s.copyWith(bloomStrength: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Halation strength',
    get: (s) => s.halationStrength,
    apply: (s, v) => s.copyWith(halationStrength: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Vignette',
    get: (s) => s.vignette,
    apply: (s, v) => s.copyWith(vignette: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Chromatic aberration',
    get: (s) => s.chromaticAberration,
    apply: (s, v) => s.copyWith(chromaticAberration: v),
    min: 0,
    max: 2,
  ),
  ParamDescriptor(
    label: 'Softness',
    get: (s) => s.softness,
    apply: (s, v) => s.copyWith(softness: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Grain amount',
    get: (s) => s.grainAmount,
    apply: (s, v) => s.copyWith(grainAmount: v),
    min: 0,
    max: 0.4,
  ),
  ParamDescriptor(
    label: 'Grain size',
    get: (s) => s.grainSize,
    apply: (s, v) => s.copyWith(grainSize: v),
    min: 0.5,
    max: 4,
  ),
  ParamDescriptor(
    label: 'Chroma noise',
    get: (s) => s.chromaNoise,
    apply: (s, v) => s.copyWith(chromaNoise: v),
    min: 0,
    max: 0.4,
  ),
  ParamDescriptor(
    label: 'Sharpen amount',
    get: (s) => s.sharpenAmount,
    apply: (s, v) => s.copyWith(sharpenAmount: v),
    min: 0,
    max: 2,
  ),
  ParamDescriptor(
    label: 'Light leak strength',
    get: (s) => s.lightLeakStrength,
    apply: (s, v) => s.copyWith(lightLeakStrength: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Light leak chance',
    get: (s) => s.lightLeakChance,
    apply: (s, v) => s.copyWith(lightLeakChance: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Dust',
    get: (s) => s.dustAmount,
    apply: (s, v) => s.copyWith(dustAmount: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'CCD smear',
    get: (s) => s.ccdSmear,
    apply: (s, v) => s.copyWith(ccdSmear: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Flash shadow',
    get: (s) => s.flashShadow,
    apply: (s, v) => s.copyWith(flashShadow: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'De-HDR',
    get: (s) => s.hdrUndo,
    apply: (s, v) => s.copyWith(hdrUndo: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Shadow crush',
    get: (s) => s.shadowCrush,
    apply: (s, v) => s.copyWith(shadowCrush: v),
    min: 0,
    max: 0.3,
  ),
  ParamDescriptor(
    label: 'Highlight blow',
    get: (s) => s.highlightBlow,
    apply: (s, v) => s.copyWith(highlightBlow: v),
    min: 0,
    max: 0.3,
  ),
  ParamDescriptor(
    label: 'Noise clump size',
    get: (s) => s.noiseSize,
    apply: (s, v) => s.copyWith(noiseSize: v),
    min: 1,
    max: 6,
  ),
  ParamDescriptor(
    label: 'Develop denoise',
    get: (s) => s.developDenoise,
    apply: (s, v) => s.copyWith(developDenoise: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'AWB bias',
    get: (s) => s.awbBias,
    apply: (s, v) => s.copyWith(awbBias: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Flash ambient drop',
    get: (s) => s.flashAmbientDrop,
    apply: (s, v) => s.copyWith(flashAmbientDrop: v),
    min: 0,
    max: 1,
  ),
  ParamDescriptor(
    label: 'Glow (veiling glare)',
    get: (s) => s.glow,
    apply: (s, v) => s.copyWith(glow: v),
    min: 0,
    max: 1,
  ),
];
