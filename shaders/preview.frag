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
uniform float uViewfinder;  // 0 look preview, 1 tiny LCD, 2 optical window
uniform float uHdrUndo;
uniform float uShadowCrush;
uniform float uHighlightBlow;
uniform float uGrain;

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

  vec2 uvLow = vec2((bLow * size + c.r + 0.5) * texel.x, (c.g + 0.5) * texel.y);
  vec2 uvHigh = vec2((bHigh * size + c.r + 0.5) * texel.x, (c.g + 0.5) * texel.y);

  vec3 lutLow = texture(uLut, uvLow).rgb;
  vec3 lutHigh = texture(uLut, uvHigh).rgb;
  return mix(lutLow, lutHigh, bFrac);
}

// Rounded-rectangle signed distance, for the optical finder's window.
float roundedBox(vec2 p, vec2 halfSize, float r) {
  vec2 q = abs(p) - halfSize + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uSize;

  // Optical finder: you look through glass, so no processing at all — just
  // the scene in a slightly smaller bright window with frame-line corners.
  if (uViewfinder > 1.5) {
    vec2 aspect = vec2(uSize.x / uSize.y, 1.0);
    vec2 p = (uv - 0.5) * aspect;
    vec2 win = vec2(0.5 * aspect.x, 0.5) * 0.9;
    float d = roundedBox(p, win, 0.06);
    vec3 scene = texture(uImage, uv).rgb;
    // Finder glass: a touch of barrel softness and falloff at the edges.
    scene *= 1.0 - 0.25 * smoothstep(0.2, 0.6, length(p));
    vec3 color = mix(scene, vec3(0.02), smoothstep(-0.004, 0.004, d));

    // Bright-line frame corners, inset from the window edge.
    vec2 inner = win * 0.86;
    vec2 q = abs(p);
    float lineW = 0.004;
    float arm = 0.07;
    bool onH = abs(q.y - inner.y) < lineW && q.x > inner.x - arm && q.x < inner.x + lineW;
    bool onV = abs(q.x - inner.x) < lineW && q.y > inner.y - arm && q.y < inner.y + lineW;
    if (onH || onV) color = mix(color, vec3(0.95, 0.93, 0.85), 0.85);
    // Centre focus mark.
    if (length(p) < 0.03 && length(p) > 0.026) color = mix(color, vec3(0.95), 0.7);

    fragColor = vec4(color, 1.0);
    return;
  }

  // Tiny LCD: a ~2 inch 240-column screen, visible pixel grid.
  vec2 cells = vec2(240.0, 240.0 * uSize.y / uSize.x);
  if (uViewfinder > 0.5) {
    uv = (floor(uv * cells) + 0.5) / cells;
  }

  vec3 color = texture(uImage, uv).rgb;
  color *= exp2(uExposure);
  // Cheap de-HDR: no wide blur per frame, so approximate it with a per-pixel
  // curve that sinks darks and pushes brights, like the full render does
  // regionally.
  if (uHdrUndo > 0.0) {
    float l = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color *= pow(clamp(l, 0.03, 1.0) / 0.45, uHdrUndo * 0.45);
  }
  color = (color - 0.5) * uContrast + 0.5;
  color = (color - uShadowCrush) / max(1.0 - uShadowCrush - uHighlightBlow, 0.2);

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

  if (uGrain > 0.0) {
    float n = fract(sin(dot(floor(fragCoord / 2.0), vec2(12.9898, 78.233))) * 43758.5453);
    color += (n - 0.5) * uGrain;
  }

  if (uViewfinder > 0.5) {
    // Cheap LCD: backlit greyish blacks, washed contrast, 6-bit colour, and
    // the RGB sub-pixel stripes of each cell.
    color = floor(clamp(color, 0.0, 1.0) * 63.0 + 0.5) / 63.0;
    color = color * 0.88 + vec3(0.035, 0.04, 0.06);
    float sub = fract(fragCoord.x / (uSize.x / cells.x)) * 3.0;
    vec3 mask = sub < 1.0 ? vec3(1.0, 0.72, 0.72) : (sub < 2.0 ? vec3(0.72, 1.0, 0.72) : vec3(0.72, 0.72, 1.0));
    float rowGap = step(0.85, fract(fragCoord.y / (uSize.y / cells.y)));
    color *= mask * (1.0 - 0.35 * rowGap);
  }

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
