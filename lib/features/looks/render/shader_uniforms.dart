import 'dart:ui' as ui;

import 'package:shuttr/features/looks/look_spec.dart';

/// The only place `look.frag`'s uniform order is encoded on the Dart side.
/// Every `setFloat` call here must match the `uniform` declaration order in
/// shaders/look.frag exactly — see the comment at the top of that file.
void bindLookUniforms(
  ui.FragmentShader shader, {
  required LookSpec spec,
  required double width,
  required double height,
  required bool flashFired,
  required double seed,
}) {
  var i = 0;
  void f(double value) => shader.setFloat(i++, value);

  f(width);
  f(height);
  f(flashFired ? 1 : 0);
  f(spec.flashStrength);
  f(spec.flashRadius);
  f(spec.flashFalloff);
  f(spec.exposure);
  f(spec.contrast);
  f(spec.blackLift);
  f(spec.highlightClip);
  f(spec.lutStrength);
  f(33); // uLutSize — fixed at 33^3 per D-025; revisit if a look needs finer.
  f(spec.saturation);
  f(spec.bloomStrength);
  f(spec.halationStrength);
  f(spec.vignette);
  f(spec.chromaticAberration);
  f(spec.softness);
  f(spec.grainAmount);
  f(spec.grainSize);
  f(spec.chromaNoise);
  f(spec.sharpenAmount);
  f(seed);
}

/// Sampler order for look.frag: image, small blur, bloom, LUT.
void bindLookSamplers(
  ui.FragmentShader shader, {
  required ui.Image image,
  required ui.Image blurSmall,
  required ui.Image bloom,
  required ui.Image lut,
}) {
  shader
    ..setImageSampler(0, image)
    ..setImageSampler(1, blurSmall)
    ..setImageSampler(2, bloom)
    ..setImageSampler(3, lut);
}

/// preview.frag uniform order: size, exposure, contrast, lutStrength,
/// lutSize, saturation, vignette.
void bindPreviewUniforms(
  ui.FragmentShader shader, {
  required LookSpec spec,
  required double width,
  required double height,
}) {
  var i = 0;
  void f(double value) => shader.setFloat(i++, value);

  f(width);
  f(height);
  f(spec.exposure);
  f(spec.contrast);
  f(spec.lutStrength);
  f(33);
  f(spec.saturation);
  f(spec.vignette);
}

/// preview.frag sampler order: image, LUT.
void bindPreviewSamplers(
  ui.FragmentShader shader, {
  required ui.Image image,
  required ui.Image lut,
}) {
  shader
    ..setImageSampler(0, image)
    ..setImageSampler(1, lut);
}
