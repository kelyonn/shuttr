// Shuttr — look shader (the uber-shader, S3)
//
// Implements docs/LOOKS.md stages 2-9 (flash, tone, colour/LUT, highlights,
// lens, sensor, sharpen; overlays are composited separately). Stages 1
// (geometry) and 10 (output/date-stamp/frame) happen outside the shader —
// see lib/features/looks/render/look_renderer.dart.
//
// Blur inputs (uBlurSmall, uBloom) are pre-computed in Dart with
// ImageFilter.blur rather than blurred in-shader, per docs/ARCHITECTURE.md.
// uBloom is already bright-passed (spec.bloomThreshold) before its blur, so
// only real highlights glow.
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
uniform float uFlashWarmth;     // -1 cool xenon .. +1 warm
uniform float uDust;            // 0-1, dust specks on the scan
uniform float uLeakStrength;    // 0 = no leak on this shot
uniform float uLeakFlipX;       // 0 or 1
uniform float uLeakFlipY;       // 0 or 1
uniform float uCcdSmear;        // 0-1, vertical CCD smear from bright lights
uniform float uFlashShadow;     // 0-1, hard shadow behind a flash-lit subject
uniform vec2 uFlashCenter;      // flash hotspot centre in uv (face or frame centre)
uniform float uRedEye;          // 0-1, red-eye strength on this shot (0 = none)
uniform vec4 uEyes;             // left eye xy, right eye xy, in uv
uniform float uEyeRadius;       // pupil radius, fraction of image height
uniform float uDenoise;         // 0-1, develop-stage chroma denoise (phone cleanup)
uniform float uHdrUndo;         // 0-1, re-expands the phone's tone-mapped HDR
uniform float uShadowCrush;     // black point (0-0.3)
uniform float uHighlightBlow;   // white point pulled down (0-0.3)
uniform float uNoiseSize;       // chroma noise clump size, px at 2400 wide
uniform float uFlashAmbientDrop; // 0-1, how dark the room goes behind a flash
uniform float uGlow;            // 0-1, whole-frame veiling glare

// --- Samplers (setImageSampler, in this order) -------------------------
uniform sampler2D uImage;      // full-res source
uniform sampler2D uBlurSmall;  // small-radius blur, for sharpen + softness
uniform sampler2D uBloom;      // bright-pass, heavily blurred, for bloom/halation
uniform sampler2D uLut;        // 33^3 LUT packed as (size*size) x size strip
uniform sampler2D uLeak;       // light-leak overlay (premultiplied), screen-blended
uniform sampler2D uSmear;      // 1-row: r = column smear intensity, g = source row
uniform sampler2D uChroma;     // quarter-res wide blur, for blotchy chroma noise

out vec4 fragColor;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// Samples the packed 3D LUT with bilinear interpolation across the blue
// axis (the two nearest slices), matching the packing in
// tool/lut/make_identity_lut.py: size slices of size x size, laid out left
// to right, red on the tile's x axis, green on y. Coordinates are offset by
// half a texel so each lattice point lands on a texel centre (without it the
// bilinear filter smears neighbouring cells and tiles together).
vec3 sampleLut(vec3 color) {
  float size = uLutSize;
  float scale = size - 1.0;

  vec3 c = clamp(color, 0.0, 1.0) * scale;
  float bLow = floor(c.b);
  float bHigh = min(bLow + 1.0, scale);
  float bFrac = c.b - bLow;

  vec2 texel = vec2(1.0 / (size * size), 1.0 / size);

  vec2 uvLow = vec2((bLow * size + c.r + 0.5) * texel.x, (c.g + 0.5) * texel.y);
  vec2 uvHigh = vec2((bHigh * size + c.r + 0.5) * texel.x, (c.g + 0.5) * texel.y);

  vec3 lutLow = texture(uLut, uvLow).rgb;
  vec3 lutHigh = texture(uLut, uvHigh).rgb;
  return mix(lutLow, lutHigh, bFrac);
}

// Smooth value noise: grain with a soft, organic clump instead of hard
// square cells. Film grain is correlated over a few pixels; a per-pixel hash
// reads as digital noise.
float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
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

  vec3 raw = texture(uImage, uv).rgb;
  vec3 color = raw;

  // --- Develop: clean up the phone's colour noise before the look --------
  // Keep the sharp luma, take colour from the small blur (eyes barely see
  // colour detail, which is why every video format subsamples chroma).
  // Strongest in shadows, where budget sensors blotch. The deepest shadows
  // also get a little luma smoothing; the look's grain replaces it.
  if (uDenoise > 0.0) {
    vec3 soft = texture(uBlurSmall, uv).rgb;
    float yr = dot(raw, vec3(0.2126, 0.7152, 0.0722));
    float ys = dot(soft, vec3(0.2126, 0.7152, 0.0722));
    // Both blurs are brightness-guided: at an edge the neighbourhood's
    // brightness differs from the pixel's, so the pixel keeps its own colour.
    float w = uDenoise * (0.6 + 0.4 * (1.0 - yr)) * exp(-pow((yr - ys) / 0.05, 2.0));
    // Wide blotches (shadows only, where budget sensors mottle): take colour
    // from the wide blur too, but only where it has about the same
    // brightness, so colour doesn't bleed across edges.
    vec3 wide = texture(uChroma, uv).rgb;
    float yw = dot(wide, vec3(0.2126, 0.7152, 0.0722));
    float guide = exp(-pow((yr - yw) / 0.035, 2.0)) * 0.9 * smoothstep(0.45, 0.15, yr);
    vec3 chroma = mix(soft - vec3(ys), wide - vec3(yw), guide);
    color = mix(raw, vec3(yr) + chroma, w);
    color += (ys - yr) * uDenoise * 0.4 * smoothstep(0.22, 0.02, yr);
  }

  // --- Lens: chromatic aberration (R/B sampled at slightly offset UVs) ----
  if (uChromaticAberration > 0.0) {
    vec2 dir = normalize(uv - center + 1e-5);
    float amount = uChromaticAberration * 0.01 * distFromCenter;
    color.r += texture(uImage, uv + dir * amount).r - raw.r;
    color.b += texture(uImage, uv - dir * amount).b - raw.b;
  }

  // --- Lens: softness (blend toward the small blur) ----------------------
  if (uSoftness > 0.0) {
    vec3 blurred = texture(uBlurSmall, uv).rgb;
    color = mix(color, blurred, uSoftness);
  }

  // Sharpening detail is taken here, in the same (ungraded) domain as the
  // blur it is measured against, and added back at the end. Measuring it
  // against the graded colour would smuggle the whole LUT delta into the
  // "detail" and wreck the grade.
  vec3 detail = color - texture(uBlurSmall, uv).rgb;

  // --- Flash: hotspot on the subject (face if detected), background drops --
  // Xenon is cooler than tungsten room light; warmth tints the flash itself
  // (cool for CCD compacts, warm for a cheap film flash).
  if (uFlashFired > 0.5 && uFlashStrength > 0.0) {
    float flashDist = length((uv - uFlashCenter) * vec2(uSize.x / uSize.y, 1.0));
    vec3 flashColor = vec3(1.0) + uFlashWarmth * vec3(0.10, 0.02, -0.14);
    float falloff = pow(clamp(flashDist / max(uFlashRadius, 0.001), 0.0, 1.0), uFlashFalloff);
    float hotspot = (1.0 - falloff) * uFlashStrength;
    color = mix(color * mix(1.0, 1.0 - uFlashAmbientDrop, uFlashStrength), flashColor, hotspot * 0.35);
    color += flashColor * (hotspot * 0.08);
    // The lit subject is nearer than the room: push the hotspot well past
    // what the phone exposed (skin and white walls burn out, like xenon).
    color *= 1.0 + hotspot * 0.55;

    // Hard shadow: the flash sits above the lens, so a lit subject throws a
    // thin dark outline onto the background just below/beside it. A pixel is
    // "in shadow" when it's dark but the pixel a little above it is bright.
    if (uFlashShadow > 0.0) {
      vec2 up = vec2(0.004, -0.018) * vec2(uSize.y / uSize.x, 1.0);
      float lumHere = dot(texture(uBlurSmall, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
      float lumUp = dot(texture(uBlurSmall, uv + up).rgb, vec3(0.2126, 0.7152, 0.0722));
      float shadow = smoothstep(0.08, 0.3, lumUp - lumHere) * smoothstep(0.5, 0.2, lumHere);
      color *= 1.0 - shadow * uFlashShadow * 0.8;
    }
  }

  // --- Red-eye: flash bouncing off the retina, straight back to the lens ----
  if (uRedEye > 0.0) {
    vec2 aspect = vec2(uSize.x / uSize.y, 1.0);
    float r = uEyeRadius;
    float dL = length((uv - uEyes.xy) * aspect);
    float dR = length((uv - uEyes.zw) * aspect);
    float d = min(dL, dR);
    float pupil = smoothstep(r, r * 0.55, d);
    float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
    // Only the dark pupil turns red; the catchlight and sclera stay.
    float dark = smoothstep(0.55, 0.2, lum);
    vec3 red = vec3(0.78, 0.06, 0.05) * (0.7 + 0.5 * (1.0 - d / r));
    color = mix(color, red, pupil * dark * uRedEye);
  }

  // --- Sensor: CCD vertical smear (before tone, it's light on the chip) ---
  if (uCcdSmear > 0.0) {
    vec2 sm = texture(uSmear, vec2(uv.x, 0.5)).rg;
    float along = 0.6 + 0.4 * exp(-abs(uv.y - sm.g) * 4.0);
    color += vec3(1.0, 0.95, 1.0) * sm.r * uCcdSmear * along;
  }

  // --- Tone: exposure, contrast, black lift, highlight shoulder -----------
  // highlightClip is where the highlight shoulder starts. 1.0 = hard clip
  // (CCD digicams clip abruptly); lower = film-style roll-off that
  // compresses highlights smoothly towards white.
  color *= exp2(uExposure);
  // De-HDR: phones lift shadows and hold every highlight. Scale each pixel by
  // how bright its wide neighbourhood is, so skies push into the clip and
  // dark areas sink, like a small sensor's single exposure.
  if (uHdrUndo > 0.0) {
    float wl = dot(texture(uChroma, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
    color *= pow(clamp(wl, 0.03, 1.0) / 0.45, uHdrUndo * 0.6);
  }
  color = (color - 0.5) * uContrast + 0.5;
  color = (color - uShadowCrush) / max(1.0 - uShadowCrush - uHighlightBlow, 0.2);
  color = uBlackLift + max(color, vec3(0.0)) * (1.0 - uBlackLift);
  if (uHighlightClip < 1.0) {
    vec3 knee = vec3(uHighlightClip);
    vec3 over = max(color - knee, vec3(0.0));
    color = min(color, knee) + (1.0 - knee) * (1.0 - exp(-over / (1.0 - knee)));
  }

  // --- Colour: LUT + saturation ------------------------------------------
  vec3 graded = sampleLut(clamp(color, 0.0, 1.0));
  color = mix(color, graded, uLutStrength);
  color = applySaturation(color, uSaturation);

  // --- Highlights: bloom / halation (screen-blended, so it can't clip) ----
  if (uBloomStrength > 0.0) {
    // Grade the bloom colour too, or a mono/graded look gets a stray
    // full-colour glow from the ungraded source.
    vec3 bloom = mix(texture(uBloom, uv).rgb, sampleLut(clamp(texture(uBloom, uv).rgb, 0.0, 1.0)), uLutStrength);
    vec3 tint = mix(vec3(1.0), vec3(1.2, 0.55, 0.25), uHalationStrength);
    color = 1.0 - (1.0 - color) * (1.0 - clamp(bloom * tint * uBloomStrength, 0.0, 1.0));
  }

  // --- Lens: veiling glare. A wide blur screen-blended over everything, so
  // the whole frame glows softly and blacks lift, like an uncoated lens shot
  // into the light.
  if (uGlow > 0.0) {
    vec3 veil = texture(uChroma, uv).rgb;
    color = 1.0 - (1.0 - color) * (1.0 - veil * uGlow);
  }

  // --- Film: tight halation ring (red layer re-exposed around lights) ----
  // The wide bloom above is the glow; this is the thin red-orange ring that
  // hugs a bright edge, from light bouncing off the film's back
  // (docs/LOOK_RESEARCH.md §2.5). Bright in the small blur but not in the
  // pixel itself = just outside a highlight.
  if (uHalationStrength > 0.0) {
    float ls = dot(texture(uBlurSmall, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
    float li = dot(raw, vec3(0.2126, 0.7152, 0.0722));
    float ring = clamp((ls - 0.72) * 4.0, 0.0, 1.0) * (1.0 - clamp((li - 0.72) * 4.0, 0.0, 1.0));
    color = 1.0 - (1.0 - color) * (1.0 - vec3(0.9, 0.3, 0.12) * ring * uHalationStrength * 0.7);
  }

  // --- Lens: vignette -------------------------------------------------------
  if (uVignette > 0.0) {
    float v = smoothstep(0.9, 0.35, distFromCenter * (0.6 + uVignette));
    color *= mix(1.0, v, uVignette);
  }

  // --- Light leak: film-plane exposure, screen-blended --------------------
  if (uLeakStrength > 0.0) {
    vec2 luv = vec2(mix(uv.x, 1.0 - uv.x, uLeakFlipX), mix(uv.y, 1.0 - uv.y, uLeakFlipY));
    vec3 leak = texture(uLeak, luv).rgb;
    color = 1.0 - (1.0 - color) * (1.0 - leak * uLeakStrength);
  }

  // --- Sensor: grain + chroma noise --------------------------------------
  // Grain size is relative to a 2400px frame so a look reads the same at any
  // output size. Luma grain peaks in the mid-tones and fades in deep
  // shadows/highlights (as on film); sensor chroma noise does the opposite
  // and is worst in the shadows (as on a small CCD).
  if (uGrainAmount > 0.0 || uChromaNoise > 0.0) {
    float grainScale = max(uGrainSize * max(uSize.x, uSize.y) / 2400.0, 1.0);
    vec2 grainUv = floor(fragCoord / grainScale);
    float clump = clamp(grainScale - 1.0, 0.0, 1.0);
    float l = dot(color, vec3(0.2126, 0.7152, 0.0722));

    float raw = mix(hash12(grainUv + uSeed), valueNoise(fragCoord / grainScale + uSeed), clump);
    float luma = (raw - 0.5) * mix(1.0, 1.7, clump);
    float midWeight = 0.35 + 0.65 * 4.0 * l * (1.0 - l);
    color += vec3(luma) * uGrainAmount * midWeight;

    if (uChromaNoise > 0.0) {
      // Sensor chroma noise is blotchy (JPEG and NR smear it into clumps):
      // blend from per-pixel hash toward smooth value noise as the clump grows.
      float cell = max(uNoiseSize * max(uSize.x, uSize.y) / 2400.0, 1.0);
      float cl = clamp(cell - 1.0, 0.0, 1.0);
      vec2 cUv = floor(fragCoord / cell);
      vec2 cF = fragCoord / cell + uSeed;
      float noiseR = mix(hash12(cUv + uSeed + 11.0), valueNoise(cF + 11.0), cl) - 0.5;
      float noiseG = mix(hash12(cUv + uSeed + 23.0), valueNoise(cF + 23.0), cl) - 0.5;
      float noiseB = mix(hash12(cUv + uSeed + 37.0), valueNoise(cF + 37.0), cl) - 0.5;
      float cGain = mix(1.0, 1.7, cl);
      noiseR *= cGain; noiseG *= cGain; noiseB *= cGain;
      float shadowWeight = 0.25 + 1.1 * (1.0 - l) * (1.0 - l);
      color += vec3(noiseR, noiseG, noiseB) * uChromaNoise * 0.5 * shadowWeight;
    }
  }

  // --- Processing: sharpen (unsharp mask against the small blur) ---------
  if (uSharpenAmount > 0.0) {
    color += detail * uSharpenAmount;
  }

  // --- Dust: sparse specks on the scan, placed per shot from the seed ----
  if (uDust > 0.0) {
    float cellPx = 90.0 * max(uSize.x, uSize.y) / 2400.0;
    vec2 g = fragCoord / cellPx;
    vec2 id = floor(g);
    vec2 f = fract(g);
    if (hash12(id + uSeed * 1.7 + 91.0) < 0.08 * uDust) {
      vec2 pos = vec2(hash12(id + 7.1 + uSeed), hash12(id + 13.3 + uSeed)) * 0.8 + 0.1;
      float r = 0.012 + 0.03 * hash12(id + 3.9);
      float speck = smoothstep(r, r * 0.4, length(f - pos));
      float bright = step(0.35, hash12(id + 5.5));
      color = mix(color, vec3(bright * 0.9 + 0.04), speck * 0.55);
    }
  }

  // Triangular dither (+-1 level) so smooth gradients (sky, flash falloff)
  // don't band in 8-bit output; real sensors are never band-free either.
  float dither = hash12(fragCoord + 3.7) + hash12(fragCoord + 17.3) - 1.0;
  color += dither / 255.0;

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
