// Shuttr — video look shader. Runs on every frame of a recording after it's
// shot (never live), inside Media3 Transformer. Parameters come from the
// Dart VideoLook (lib/features/video/video_look.dart) via VideoLookEffect.kt.
//
// Coordinates: uv 0-1, origin bottom-left, so "the bottom of the picture"
// (where VHS head-switching noise lives) is uv.y near 0.

precision highp float;

uniform sampler2D uTexSampler;
uniform sampler2D uLut;         // 33^3 LUT packed as a 1089x33 strip
uniform float uHasLut;
uniform vec2 uSize;             // output size in px
uniform float uTime;            // seconds since start
uniform float uSeed;

uniform float uExposure;
uniform float uContrast;
uniform float uSaturation;
uniform float uBlackLift;
uniform float uVignette;
uniform float uLumaBlur;
uniform float uChromaBlur;
uniform float uChromaShift;
uniform float uSharpen;
uniform float uNoise;
uniform float uChromaNoise;
uniform float uGrain;
uniform float uLineJitter;
uniform float uTracking;
uniform float uHeadSwitch;
uniform float uInterlace;
uniform float uGateWeave;
uniform float uFlicker;
uniform float uDust;
uniform float uGateMask;
uniform float uWobble;
uniform float uNightVision;

varying vec2 vTexSamplingCoord;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

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

// YIQ: the NTSC colour space tape stored. Luma and chroma are recorded with
// very different bandwidth, which is where the VHS smear comes from.
vec3 rgb2yiq(vec3 c) {
  return vec3(dot(c, vec3(0.299, 0.587, 0.114)),
              dot(c, vec3(0.596, -0.274, -0.322)),
              dot(c, vec3(0.211, -0.523, 0.312)));
}

vec3 yiq2rgb(vec3 c) {
  return vec3(c.x + 0.956 * c.y + 0.621 * c.z,
              c.x - 0.272 * c.y - 0.647 * c.z,
              c.x - 1.106 * c.y + 1.703 * c.z);
}

vec3 sampleLut(vec3 color) {
  float size = 33.0;
  float scale = size - 1.0;
  vec3 c = clamp(color, 0.0, 1.0) * scale;
  float bLow = floor(c.b);
  float bHigh = min(bLow + 1.0, scale);
  float bFrac = c.b - bLow;
  vec2 texel = vec2(1.0 / (size * size), 1.0 / size);
  // GLUtils uploads the PNG's first row at t = 0, which is exactly green = 0
  // in the strip layout, so no flip is needed here.
  vec2 uvLow = vec2((bLow * size + c.r + 0.5) * texel.x, (c.g + 0.5) * texel.y);
  vec2 uvHigh = vec2((bHigh * size + c.r + 0.5) * texel.x, (c.g + 0.5) * texel.y);
  return mix(texture2D(uLut, uvLow).rgb, texture2D(uLut, uvHigh).rgb, bFrac);
}

vec3 src(vec2 uv) {
  return texture2D(uTexSampler, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void main() {
  vec2 uv = vTexSamplingCoord;
  vec2 px = 1.0 / uSize;
  float frame = floor(uTime * 30.0);
  float line = floor((1.0 - uv.y) * 240.0);  // tape scanline, top = 0

  // --- Geometry: film gate weave, rolling shutter, line jitter ------------
  if (uGateWeave > 0.0) {
    float f18 = floor(uTime * 18.0);
    uv += (vec2(hash12(vec2(f18, uSeed)), hash12(vec2(f18, uSeed + 5.0))) - 0.5)
        * uGateWeave * vec2(0.004, 0.006);
  }
  if (uWobble > 0.0) {
    // Cheap CMOS reads top to bottom, so hand shake bends verticals.
    uv.x += sin(uv.y * 5.0 + uTime * 9.0) * sin(uTime * 2.3) * uWobble * 0.004;
  }
  if (uLineJitter > 0.0) {
    uv.x += (hash12(vec2(line, frame + uSeed)) - 0.5) * uLineJitter * 3.0 * px.x;
  }

  // Tracking: a band of torn, noisy lines drifting up the frame now and
  // then, like a worn tape.
  float trackingBand = 0.0;
  if (uTracking > 0.0) {
    float episode = floor(uTime / 3.0);
    float active = step(1.0 - uTracking * 0.6, hash12(vec2(episode, uSeed + 3.0)));
    float pos = fract(uTime * 0.35 + hash12(vec2(episode, uSeed)));
    float d = abs(uv.y - pos);
    trackingBand = active * smoothstep(0.035, 0.0, d);
    uv.x += trackingBand * (hash12(vec2(line, frame)) - 0.3) * 0.03;
  }

  // Head-switching: the bottom few lines tear sideways (VHS playback).
  float headBand = 0.0;
  if (uHeadSwitch > 0.0) {
    headBand = smoothstep(0.03, 0.0, uv.y);
    uv.x += headBand * uHeadSwitch * (0.02 + 0.02 * hash12(vec2(line, frame)));
  }

  // --- Tape bandwidth: soft luma, very smeared + late chroma --------------
  vec3 yiq = vec3(0.0);
  vec3 center = src(uv);
  if (uLumaBlur > 0.0 || uChromaBlur > 0.0 || uChromaShift > 0.0) {
    float y = 0.0;
    vec2 iq = vec2(0.0);
    for (int i = -2; i <= 2; i++) {
      float fi = float(i);
      y += rgb2yiq(src(uv + vec2(fi * uLumaBlur * 0.5 * px.x, 0.0))).x;
      iq += rgb2yiq(src(uv + vec2((fi * uChromaBlur * 0.5 - uChromaShift) * px.x, 0.0))).yz;
    }
    yiq = vec3(y / 5.0, iq / 5.0);
  } else {
    yiq = rgb2yiq(center);
  }

  // Camcorder edge enhancement: bright/dark halos on luma edges.
  if (uSharpen > 0.0) {
    float wide = 0.0;
    for (int i = -2; i <= 2; i++) {
      wide += rgb2yiq(src(uv + vec2(float(i) * 2.0 * px.x, 0.0))).x;
    }
    yiq.x += (yiq.x - wide / 5.0) * uSharpen * 1.5;
  }
  vec3 color = yiq2rgb(yiq);

  // --- Tone + colour --------------------------------------------------------
  color *= exp2(uExposure);
  color = (color - 0.5) * uContrast + 0.5;
  color = uBlackLift + max(color, vec3(0.0)) * (1.0 - uBlackLift);
  if (uHasLut > 0.5) color = sampleLut(color);
  float lum = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(vec3(lum), color, uSaturation);

  // Night vision: IR picture in phosphor green, highlights bloom.
  if (uNightVision > 0.0) {
    float ir = clamp(lum * 1.4, 0.0, 1.0);
    vec3 green = vec3(0.25, 1.0, 0.35) * ir + vec3(0.02, 0.06, 0.03);
    color = mix(color, green, uNightVision);
  }

  // --- Noise ---------------------------------------------------------------
  vec2 fc = uv * uSize;
  if (uNoise > 0.0) {
    float snow = hash12(fc + frame * 17.0 + uSeed) - 0.5;
    color += snow * uNoise * (1.0 + trackingBand * 6.0 + headBand * 4.0);
  }
  if (uChromaNoise > 0.0) {
    // Chroma noise on tape is streaky: stretched along the line.
    vec2 cc = vec2(floor(fc.x / 6.0), floor(fc.y));
    vec3 n = vec3(hash12(cc + frame), hash12(cc + frame + 7.0), hash12(cc + frame + 13.0)) - 0.5;
    color += n * uChromaNoise;
  }
  if (uGrain > 0.0) {
    float g = valueNoise(fc / 1.6 + frame * 31.7) - 0.5;
    color += g * uGrain * (0.4 + 2.4 * lum * (1.0 - lum));
  }

  // Interlace: alternate fields sit a touch apart.
  if (uInterlace > 0.0) {
    float field = mod(floor(fc.y), 2.0);
    color *= 1.0 - field * uInterlace * 0.05;
  }

  // --- Film: projector flicker, dust and scratches -------------------------
  if (uFlicker > 0.0) {
    color *= 1.0 + (hash12(vec2(floor(uTime * 18.0), uSeed)) - 0.5) * uFlicker * 0.14;
  }
  if (uDust > 0.0) {
    float f18 = floor(uTime * 18.0);
    // A few specks per frame, different every frame.
    vec2 cell = floor(uv * vec2(14.0, 10.0));
    vec2 f = fract(uv * vec2(14.0, 10.0));
    if (hash12(cell + f18 * 3.1) < 0.025 * uDust) {
      vec2 p = vec2(hash12(cell + f18), hash12(cell + f18 + 9.0));
      float r = 0.03 + 0.06 * hash12(cell + 2.0);
      float speck = smoothstep(r, r * 0.3, length((f - p) * vec2(1.4, 1.0)));
      color = mix(color, vec3(0.05), speck * 0.8);
    }
    // A vertical scratch that hangs around for a second or two.
    float scratchEp = floor(uTime * 0.7);
    if (hash12(vec2(scratchEp, uSeed + 1.0)) < 0.5 * uDust) {
      float sx = hash12(vec2(scratchEp, uSeed + 2.0)) + (hash12(vec2(f18, 4.0)) - 0.5) * 0.004;
      float s = smoothstep(1.5 * px.x, 0.0, abs(uv.x - sx));
      color += s * 0.35;
    }
  }

  // --- Lens / gate ----------------------------------------------------------
  vec2 p = (uv - 0.5) * vec2(uSize.x / uSize.y, 1.0);
  if (uVignette > 0.0) {
    float v = smoothstep(0.95, 0.3, length(p) * (0.7 + uVignette * 0.6));
    color *= mix(1.0, v, uVignette);
  }
  if (uGateMask > 0.0) {
    vec2 halfSize = vec2(0.5 * uSize.x / uSize.y, 0.5) * 0.98;
    vec2 q = abs(p) - halfSize + 0.08;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.08;
    color *= 1.0 - uGateMask * smoothstep(-0.02, 0.01, d);
  }

  gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
