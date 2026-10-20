// Full-frame quad. Media3 draws a triangle strip over clip space; texture
// coordinates run 0-1 with the origin at the bottom-left (GL convention).
attribute vec4 aFramePosition;
varying vec2 vTexSamplingCoord;

void main() {
  gl_Position = aFramePosition;
  vTexSamplingCoord = aFramePosition.xy * 0.5 + 0.5;
}
