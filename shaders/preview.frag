// Shuttr — live preview shader (placeholder)
//
// Identity pass-through for scaffolding (M1). The real cheap preview
// (LUT + tone + vignette only, no grain/bloom) is built in S12 — see
// docs/ARCHITECTURE.md "Live preview".

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform sampler2D uImage;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  fragColor = texture(uImage, uv);
}
