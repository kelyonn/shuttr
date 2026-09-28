#!/usr/bin/env python3
"""Generate self-made light-leak overlay textures for the Disposable look
(docs/LOOKS.md, docs/BUILD_PLAN.md S9). Procedural, so there's no licensing
question (D-025) — these are soft radial/streak gradients in warm tones,
not photographed leaks.

Usage:
    ./.venv-tools/bin/python3 tool/textures/gen_leaks.py
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

WIDTH, HEIGHT = 1024, 768
COLORS = [
    (255, 140, 40),   # warm orange
    (255, 60, 90),    # warm red
    (255, 210, 90),   # warm yellow
]


def gen_leak(seed: int) -> Image.Image:
    rng = random.Random(seed)
    img = Image.new('RGBA', (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # One or two soft blobs entering from an edge, per the "streaks in from
    # the side" look of a real light leak.
    blob_count = rng.choice([1, 1, 2])
    edge = rng.choice(['left', 'right', 'top'])

    for _ in range(blob_count):
        color = rng.choice(COLORS)
        radius = rng.uniform(0.4, 0.8) * max(WIDTH, HEIGHT)

        if edge == 'left':
            cx = rng.uniform(-0.1, 0.15) * WIDTH
        elif edge == 'right':
            cx = rng.uniform(0.85, 1.1) * WIDTH
        else:
            cx = rng.uniform(0.2, 0.8) * WIDTH
        cy = rng.uniform(0.1, 0.9) * HEIGHT if edge != 'top' else rng.uniform(-0.1, 0.15) * HEIGHT

        layer = Image.new('L', (WIDTH, HEIGHT), 0)
        ldraw = ImageDraw.Draw(layer)
        ldraw.ellipse(
            [cx - radius, cy - radius, cx + radius, cy + radius],
            fill=200,
        )
        layer = layer.filter(ImageFilter.GaussianBlur(radius=radius * 0.3))

        color_layer = Image.new('RGBA', (WIDTH, HEIGHT), color + (0,))
        color_layer.putalpha(layer)
        img = Image.alpha_composite(img, color_layer)

    return img


def main() -> None:
    out_dir = Path(__file__).resolve().parents[2] / 'assets' / 'textures'
    out_dir.mkdir(parents=True, exist_ok=True)

    count = 6
    for i in range(count):
        img = gen_leak(seed=i)
        out_path = out_dir / f'leak_{i:02d}.png'
        img.save(out_path)
        print(f'Wrote {out_path}')


if __name__ == '__main__':
    main()
