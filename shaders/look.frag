// Shuttr — look shader (the uber-shader, S3)
//
// Implements docs/LOOKS.md stages 2-9 (flash, tone, colour/LUT, highlights,
// lens, sensor, sharpen; overlays are composited separately). Stages 1
// (geometry) and 10 (output/date-stamp/frame) happen outside the shader —
// see lib/features/looks/render/look_renderer.dart.
//
// Blur inputs (uBlurSmall, uBloom) are pre-computed in Dart with
// ImageFilter.blur rather than blurred in-shader, per docs/ARCHITECTURE.md.
//
// Uniform order here MUST match lib/features/looks/render/shader_uniforms.dart
// — that file is the only other place these indices are defined.

#include <flutter/runtime_effect.glsl>

// --- Scalars (setFloat, in this order) --------------------------------
uniform vec2 uSize;             // output image size in px
uniform float uFlashFired;      // 0 or 1
uniform float uFlashStrength;   // 0-1
uniform float uFlashRadius;     // 0-1, fraction of the shorter edge
uniform float uFlashFalloff;    // exponent, higher = harder edge
uniform float uExposure;        // stops, -2..2
uniform float uContrast;        // 1 = none
uniform float uBlackLift;       // 0-1, raises shadow floor
uniform float uHighlightClip;   // 0-1, where highlights start clipping
uniform float uLutStrength;     // 0-1
uniform float uLutSize;         // e.g. 33
uniform float uSaturation;      // 1 = none
uniform float uBloomStrength;   // 0-1
uniform float uHalationStrength; // 0-1, tints bloom red-orange
uniform float uVignette;        // 0-1
uniform float uChromaticAberration; // 0-1
uniform float uSoftness;        // 0-1, blends toward uBlurSmall
uniform float uGrainAmount;     // 0-1
uniform float uGrainSize;       // px, larger = coarser grain
uniform float uChromaNoise;     // 0-1, colour-channel-independent noise
uniform float uSharpenAmount;   // 0-1, unsharp mask strength
uniform float uSeed;            // random seed for grain/noise, per shot

// --- Samplers (setImageSampler, in this order) -------------------------
uniform sampler2D uImage;      // full-res source
uniform sampler2D uBlurSmall;  // small-radius blur, for sharpen + softness
uniform sampler2D uBloom;      // bright-pass, heavily blurred, for bloom/halation
uniform sampler2D uLut;        // 33^3 LUT packed as (size*size) x size strip

out vec4 fragColor;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// Samples the packed 3D LUT with bilinear interpolation across the blue
// axis (the two nearest slices), matching the packing in
// tool/lut/make_identity_lut.py: size slices of size x size, laid out left
// to right, red on the tile's x axis, green on y.
vec3 sampleLut(vec3 color) {
  float size = uLutSize;
  float scale = size - 1.0;

  vec3 c = clamp(color, 0.0, 1.0) * scale;
  float bLow = floor(c.b);
  float bHigh = min(bLow + 1.0, scale);
  float bFrac = c.b - bLow;

  vec2 texel = vec2(1.0 / (size * size), 1.0 / size);

  vec2 uvLow = vec2((bLow * size + c.r) * texel.x, c.g * texel.y);
  vec2 uvHigh = vec2((bHigh * size + c.r) * texel.x, c.g * texel.y);

  vec3 lutLow = texture(uLut, uvLow).rgb;
  vec3 lutHigh = texture(uLut, uvHigh).rgb;
  return mix(lutLow, lutHigh, bFrac);
}

vec3 applySaturation(vec3 color, float amount) {
  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  return mix(vec3(luma), color, amount);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uSize;
  vec2 center = vec2(0.5);
  float distFromCenter = length((uv - center) * vec2(uSize.x / uSize.y, 1.0));

  // --- Lens: chromatic aberration (sample R/G/B at slightly offset UVs) --
  vec3 color;
  if (uChromaticAberration > 0.0) {
    vec2 dir = normalize(uv - center + 1e-5);
    float amount = uChromaticAberration * 0.01 * distFromCenter;
    color.r = texture(uImage, uv + dir * amount).r;
    color.g = texture(uImage, uv).g;
    color.b = texture(uImage, uv - dir * amount).b;
  } else {
    color = texture(uImage, uv).rgb;
  }

  // --- Lens: softness (blend toward the small blur) ----------------------
  if (uSoftness > 0.0) {
    vec3 blurred = texture(uBlurSmall, uv).rgb;
    color = mix(color, blurred, uSoftness);
  }

  // --- Flash: hotspot at frame centre, darkens the background ------------
  if (uFlashFired > 0.5 && uFlashStrength > 0.0) {
    float falloff = pow(clamp(distFromCenter / max(uFlashRadius, 0.001), 0.0, 1.0), uFlashFalloff);
    float hotspot = (1.0 - falloff) * uFlashStrength;
    color = mix(color * mix(1.0, 0.55, uFlashStrength), vec3(1.0), hotspot * 0.6);
    color += vec3(hotspot * 0.15);
  }

  // --- Tone: exposure, black lift, highlight clip, contrast --------------
  color *= exp2(uExposure);
  color = uBlackLift + color * (1.0 - uBlackLift);
  if (uHighlightClip < 1.0) {
    float clipStart = uHighlightClip;
    vec3 rolled = vec3(clipStart) + (1.0 - clipStart) *
        smoothstep(vec3(clipStart), vec3(1.0), color);
    vec3 aboveClip = step(vec3(clipStart), color);
    color = mix(color, rolled, aboveClip);
  }
  color = (color - 0.5) * uContrast + 0.5;

  // --- Colour: LUT + saturation ------------------------------------------
  vec3 graded = sampleLut(clamp(color, 0.0, 1.0));
  color = mix(color, graded, uLutStrength);
  color = applySaturation(color, uSaturation);

  // --- Highlights: bloom / halation ---------------------------------------
  if (uBloomStrength > 0.0) {
    vec3 bloom = texture(uBloom, uv).rgb;
    vec3 tint = mix(vec3(1.0), vec3(1.2, 0.55, 0.25), uHalationStrength);
    color += bloom * tint * uBloomStrength;
  }

  // --- Lens: vignette -------------------------------------------------------
  if (uVignette > 0.0) {
    float v = smoothstep(0.9, 0.35, distFromCenter * (0.6 + uVignette));
    color *= mix(1.0, v, uVignette);
  }

  // --- Sensor: grain + chroma noise --------------------------------------
  if (uGrainAmount > 0.0 || uChromaNoise > 0.0) {
    vec2 grainUv = floor(fragCoord / max(uGrainSize, 1.0));
    float luma = hash12(grainUv + uSeed) - 0.5;
    color += vec3(luma) * uGrainAmount;

    if (uChromaNoise > 0.0) {
      float noiseR = hash12(grainUv + uSeed + 11.0) - 0.5;
      float noiseG = hash12(grainUv + uSeed + 23.0) - 0.5;
      float noiseB = hash12(grainUv + uSeed + 37.0) - 0.5;
      color += vec3(noiseR, noiseG, noiseB) * uChromaNoise * 0.5;
    }
  }

  // --- Processing: sharpen (unsharp mask against the small blur) ---------
  if (uSharpenAmount > 0.0) {
    vec3 blurred = texture(uBlurSmall, uv).rgb;
    color += (color - blurred) * uSharpenAmount;
  }

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
