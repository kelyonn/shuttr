#!/usr/bin/env python3
"""Generate the Instant look's frame asset (docs/LOOKS.md "Instant",
docs/BUILD_PLAN.md S10): a self-made off-white border, thicker at the
bottom, around the near-square photo window. No brand marks.

The margins below (as a fraction of the frame's own width/height) MUST match
`sideMargin`/`topMargin`/`bottomMargin` in
lib/features/looks/render/frame_composite.dart — that's what lets
`LookRenderer` stretch this asset to any output size and have its border
line up with the photo exactly.

Usage:
    ./.venv-tools/bin/python3 tool/frames/gen_instant_frame.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

# Fractions of the *photo's* width/height — keep in sync with
# frame_composite.dart.
SIDE_MARGIN = 0.06
TOP_MARGIN = 0.06
BOTTOM_MARGIN = 0.22

# Reference photo size to author the asset at (frame_composite.dart stretches
# this to the real output size at render time, so this can be arbitrary).
PHOTO = 1000

BORDER_COLOR = (250, 247, 240, 255)  # off-white paper, not pure white
SHADOW_COLOR = (0, 0, 0, 40)  # subtle inner shadow around the photo window


def main() -> None:
    canvas_w = round(PHOTO * (1 + 2 * SIDE_MARGIN))
    canvas_h = round(PHOTO * (1 + TOP_MARGIN + BOTTOM_MARGIN))

    img = Image.new('RGBA', (canvas_w, canvas_h), BORDER_COLOR)
    draw = ImageDraw.Draw(img)

    left = round(PHOTO * SIDE_MARGIN)
    top = round(PHOTO * TOP_MARGIN)
    window = (left, top, left + PHOTO, top + PHOTO)

    # A soft inset shadow just inside the window edge, so the border reads
    # as a physical print rather than a flat colour-swap. LookRenderer draws
    # the photo on top, covering the window's interior entirely.
    shadow_width = max(2, round(PHOTO * 0.01))
    for i in range(shadow_width):
        alpha = round(SHADOW_COLOR[3] * (1 - i / shadow_width))
        draw.rectangle(
            [
                window[0] + i,
                window[1] + i,
                window[2] - i,
                window[3] - i,
            ],
            outline=(*SHADOW_COLOR[:3], alpha),
        )

    out_path = (
        Path(__file__).resolve().parents[2] / 'assets' / 'frames' / 'instant.png'
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path)
    print(f'Wrote {out_path} ({canvas_w}x{canvas_h})')


if __name__ == '__main__':
    main()
