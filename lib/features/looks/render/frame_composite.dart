import 'dart:ui';

/// Margins for a look's frame overlay, as a fraction of the *photo's own*
/// width/height (not the frame asset's native resolution) — a thicker
/// bottom border per docs/LOOKS.md "Instant". [tool/frames/gen_instant_frame.py]
/// generates the frame PNG with these same fractions of its own dimensions,
/// so stretching the frame to [frameCanvasSize] always lines its border up
/// with [frameWindowRect] regardless of the asset's native resolution.
const sideMargin = 0.06;
const topMargin = 0.06;
const bottomMargin = 0.22;

/// Final output size once a frame is composited around a `photoWidth` x
/// `photoHeight` photo.
Size frameCanvasSize({
  required double photoWidth,
  required double photoHeight,
}) {
  return Size(
    photoWidth * (1 + 2 * sideMargin),
    photoHeight * (1 + topMargin + bottomMargin),
  );
}

/// Where the photo sits within [frameCanvasSize]'s canvas.
Rect frameWindowRect({
  required double photoWidth,
  required double photoHeight,
}) {
  return Rect.fromLTWH(
    photoWidth * sideMargin,
    photoHeight * topMargin,
    photoWidth,
    photoHeight,
  );
}
