// Shuttr — look shader (placeholder)
//
// This is an identity pass-through so the app builds during scaffolding (M1).
// The real uber-shader implementing the LookSpec pipeline (flash, tone, LUT,
// bloom/halation, vignette/CA, grain, sharpen) is built in S3 — see
// docs/ARCHITECTURE.md "Photo pipeline" and docs/LOOKS.md for the param spec.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform sampler2D uImage;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  fragColor = texture(uImage, uv);
}
