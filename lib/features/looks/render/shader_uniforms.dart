import 'dart:math' as math;
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
  LeakPlacement leak = LeakPlacement.none,
  FaceHint? face,
  bool redEye = false,
  double denoise = 0,
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
  f(spec.flashWarmth);
  f(spec.dustAmount);
  f(leak.strength);
  f(leak.flipX ? 1 : 0);
  f(leak.flipY ? 1 : 0);
  f(spec.ccdSmear);
  f(spec.flashShadow);
  f(face?.centerX ?? 0.5);
  f(face?.centerY ?? 0.5);
  f(redEye && face != null ? 1 : 0);
  f(face?.leftEyeX ?? -1);
  f(face?.leftEyeY ?? -1);
  f(face?.rightEyeX ?? -1);
  f(face?.rightEyeY ?? -1);
  f(face?.eyeRadius ?? 0);
  f(denoise);
  f(spec.hdrUndo);
  f(spec.shadowCrush);
  f(spec.highlightBlow);
  f(spec.noiseSize);
  f(spec.flashAmbientDrop);
  f(spec.glow);
}

/// The main face in a shot, in normalised (0-1) coordinates of the cropped
/// frame. Drives where the flash hotspot lands and where red-eye goes.
class FaceHint {
  const new({
    required this.centerX,
    required this.centerY,
    required this.leftEyeX,
    required this.leftEyeY,
    required this.rightEyeX,
    required this.rightEyeY,
    required this.eyeRadius,
  });

  final double centerX;
  final double centerY;
  final double leftEyeX;
  final double leftEyeY;
  final double rightEyeX;
  final double rightEyeY;

  /// Pupil radius as a fraction of image height.
  final double eyeRadius;
}

/// Which light leak (if any) a given shot gets. Derived from the shot's
/// seed so a re-develop reproduces the same leak.
class LeakPlacement {
  const new({
    required this.textureIndex,
    required this.strength,
    this.flipX = false,
    this.flipY = false,
  });

  factory forShot(LookSpec spec, double seed) {
    if (spec.lightLeakStrength <= 0) return none;
    final rng = math.Random(seed.round());
    if (rng.nextDouble() >= spec.lightLeakChance) return none;
    return LeakPlacement(
      textureIndex: rng.nextInt(textureCount),
      // Vary strength a little per shot: real leaks range from a faint warm
      // edge to a blown-out streak.
      strength: spec.lightLeakStrength * (0.6 + rng.nextDouble() * 0.8),
      flipX: rng.nextBool(),
      flipY: rng.nextBool(),
    );
  }

  static const none = LeakPlacement(textureIndex: 0, strength: 0);
  static const textureCount = 6;

  final int textureIndex;
  final double strength;
  final bool flipX;
  final bool flipY;

  String get asset => 'assets/textures/leak_0$textureIndex.png';
}

/// Sampler order for look.frag: image, small blur, bloom, LUT, leak, smear,
/// chroma (the develop stage's wide blur; defaults to the small blur when
/// the develop stage is off, since `uDenoise` is then 0 and it's unused).
void bindLookSamplers(
  ui.FragmentShader shader, {
  required ui.Image image,
  required ui.Image blurSmall,
  required ui.Image bloom,
  required ui.Image lut,
  required ui.Image leak,
  required ui.Image smear,
  ui.Image? chroma,
}) {
  shader
    ..setImageSampler(0, image)
    ..setImageSampler(1, blurSmall)
    ..setImageSampler(2, bloom)
    ..setImageSampler(3, lut)
    ..setImageSampler(4, leak)
    ..setImageSampler(5, smear)
    ..setImageSampler(6, chroma ?? blurSmall);
}

/// How the live viewfinder is drawn (preview.frag `uViewfinder`).
enum PreviewMode { look, lcd, optical }

/// preview.frag uniform order: size, exposure, contrast, lutStrength,
/// lutSize, saturation, vignette, viewfinder, hdrUndo, shadowCrush,
/// highlightBlow, grain.
void bindPreviewUniforms(
  ui.FragmentShader shader, {
  required LookSpec spec,
  required double width,
  required double height,
  PreviewMode mode = PreviewMode.look,
}) {
  var i = 0;
  void f(double value) => shader.setFloat(i++, value);

  f(width);
  f(height);
  f(spec.exposure + spec.previewExposure);
  f(spec.contrast);
  f(spec.lutStrength);
  f(33);
  f(spec.saturation);
  f(spec.vignette);
  f(mode.index.toDouble());
  f(spec.hdrUndo);
  f(spec.shadowCrush);
  f(spec.highlightBlow);
  f(spec.grainAmount * 0.5);
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
