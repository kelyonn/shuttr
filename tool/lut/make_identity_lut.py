#!/usr/bin/env python3
"""Generate assets/luts/identity.png — a neutral 33^3 3D LUT packed as a
1089x33 2D strip (33 tiles of 33x33, laid out left to right).

Flutter fragment shaders only support 2D samplers, so a 3D LUT is packed
as a horizontal strip of blue-axis slices and sampled with manual
interpolation between the two nearest slices in the shader
(see docs/ARCHITECTURE.md "Photo pipeline").

Usage:
    pip install -r tool/requirements.txt
    python3 tool/lut/make_identity_lut.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 33  # 33^3 LUT


def make_identity_lut(size: int) -> Image.Image:
    strip = np.zeros((size, size * size, 3), dtype=np.uint8)
    ramp = np.linspace(0, 255, size).astype(np.uint8)

    for b in range(size):
        for g in range(size):
            for r in range(size):
                x = b * size + r
                y = g
                strip[y, x] = (ramp[r], ramp[g], ramp[b])

    return Image.fromarray(strip, mode='RGB')


def main() -> None:
    out_dir = Path(__file__).resolve().parents[2] / 'assets' / 'luts'
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / 'identity.png'

    img = make_identity_lut(SIZE)
    img.save(out_path)
    print(f'Wrote {out_path} ({img.width}x{img.height})')


if __name__ == '__main__':
    main()
