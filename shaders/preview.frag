// Shuttr — live preview shader (S3/S12)
//
// Cheap approximation for the live camera preview: LUT + tone + vignette
// only, no grain/bloom/sharpen (docs/ARCHITECTURE.md "Live preview"). Must
// run every frame, so it stays minimal.
//
// Uniform order mirrors the scalar/sampler subset used here from
// shaders/look.frag — see shader_uniforms.dart.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uExposure;
uniform float uContrast;
uniform float uLutStrength;
uniform float uLutSize;
uniform float uSaturation;
uniform float uVignette;

uniform sampler2D uImage;
uniform sampler2D uLut;

out vec4 fragColor;

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

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec3 color = texture(uImage, uv).rgb;

  color *= exp2(uExposure);
  color = (color - 0.5) * uContrast + 0.5;

  vec3 graded = sampleLut(clamp(color, 0.0, 1.0));
  color = mix(color, graded, uLutStrength);

  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = mix(vec3(luma), color, uSaturation);

  if (uVignette > 0.0) {
    vec2 center = vec2(0.5);
    float dist = length((uv - center) * vec2(uSize.x / uSize.y, 1.0));
    float v = smoothstep(0.9, 0.35, dist * (0.6 + uVignette));
    color *= mix(1.0, v, uVignette);
  }

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
