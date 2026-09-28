#!/usr/bin/env python3
"""Build a look's 3D LUT from matched phone/reference-camera photo pairs.

This is the authenticity moat (docs/STRATEGY.md "Moat") — it needs REAL
reference photos, which don't exist yet in this repo (D-023: reference/ is
git-ignored, you shoot and keep them locally / back them up to Drive).
This script is written and ready; it cannot be run meaningfully until you
have:

  1. A reference camera (e.g. a real CCD digicam) and a 24-patch colour
     card (docs/BUILD_PLAN.md M0, docs/GTM.md budget).
  2. Photos of the SAME colour card, in the same light, shot on both the
     reference camera and a phone, saved as:
       reference/<look>/card_phone.jpg
       reference/<look>/card_reference.jpg
  3. (Optional, improves the fit) a few matched SCENE pairs — same subject,
     same moment, phone + reference camera — as:
       reference/<look>/scene_XX_phone.jpg
       reference/<look>/scene_XX_reference.jpg

Method: sample the 24 colour-card patches from both images, fit a
radial-basis-function (RBF) mapping from phone-RGB to reference-RGB using
those correspondences (plus scene pairs if present), then evaluate that
mapping on every node of a 33^3 grid and pack the result as the same
1089x33 strip format as tool/lut/make_identity_lut.py.

Usage (once reference photos exist):
    ./.venv-tools/bin/python3 tool/lut/build_lut.py digi03
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.interpolate import RBFInterpolator

SIZE = 33  # must match tool/lut/make_identity_lut.py and shaders/*.frag uLutSize

# Placeholder patch centres for a generic 24-patch colour card (e.g.
# X-Rite ColorChecker layout), as fractional (x, y) coordinates within the
# card's bounding box. Replace with real measured coordinates for the
# actual card once you have one — this is a starting layout, not verified
# against a specific product.
CARD_PATCH_GRID = (6, 4)  # columns, rows


def sample_patch_colors(image_path: Path, card_bbox: tuple[int, int, int, int]) -> np.ndarray:
    """Samples the mean colour of each patch in a 6x4 colour card.

    card_bbox is (left, top, right, bottom) of the card's outer edge in the
    image, in pixels — find this manually (crop/inspect) for each photo
    since framing won't be identical between the phone and the reference
    camera.
    """
    img = np.asarray(Image.open(image_path).convert('RGB'), dtype=np.float64) / 255.0
    left, top, right, bottom = card_bbox
    cols, rows = CARD_PATCH_GRID
    cell_w = (right - left) / cols
    cell_h = (bottom - top) / rows

    colors = []
    for row in range(rows):
        for col in range(cols):
            cx = left + (col + 0.5) * cell_w
            cy = top + (row + 0.5) * cell_h
            # Average a small box around the patch centre to reduce noise.
            half = min(cell_w, cell_h) * 0.15
            x0, x1 = int(cx - half), int(cx + half)
            y0, y1 = int(cy - half), int(cy + half)
            patch = img[y0:y1, x0:x1].reshape(-1, 3)
            colors.append(patch.mean(axis=0))
    return np.array(colors)


def build_lut(phone_points: np.ndarray, reference_points: np.ndarray) -> np.ndarray:
    """Fits phone->reference colour mapping and evaluates it on a 33^3 grid.

    Returns an array of shape (SIZE, SIZE, SIZE, 3) indexed [r, g, b].
    """
    interpolators = [
        RBFInterpolator(phone_points, reference_points[:, c], kernel='thin_plate_spline')
        for c in range(3)
    ]

    ramp = np.linspace(0, 1, SIZE)
    r, g, b = np.meshgrid(ramp, ramp, ramp, indexing='ij')
    grid_points = np.stack([r.ravel(), g.ravel(), b.ravel()], axis=1)

    mapped = np.stack([interp(grid_points) for interp in interpolators], axis=1)
    mapped = np.clip(mapped, 0, 1).reshape(SIZE, SIZE, SIZE, 3)
    return mapped


def pack_lut_strip(lut: np.ndarray) -> Image.Image:
    """Packs a (SIZE, SIZE, SIZE, 3) LUT as the 1089x33 strip format used by
    shaders/look.frag's sampleLut() — same layout as make_identity_lut.py.
    """
    size = lut.shape[0]
    strip = np.zeros((size, size * size, 3), dtype=np.uint8)
    for b in range(size):
        for g in range(size):
            for r in range(size):
                x = b * size + r
                strip[g, x] = (lut[r, g, b] * 255).astype(np.uint8)
    return Image.fromarray(strip, mode='RGB')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('look_id', help='e.g. digi03, disposable, instant, point_and_shoot_35')
    args = parser.parse_args()

    ref_dir = Path(__file__).resolve().parents[2] / 'reference' / args.look_id
    if not ref_dir.exists():
        print(
            f'No reference photos at {ref_dir} yet. See this file\'s module '
            'docstring for what to shoot before running this script.',
            file=sys.stderr,
        )
        sys.exit(1)

    print(
        'This script is a working scaffold. Before running it for real, set '
        'CARD_PATCH_GRID / patch coordinates for your actual colour card and '
        'the card_bbox values for each photo — see sample_patch_colors().',
        file=sys.stderr,
    )
    sys.exit(1)


if __name__ == '__main__':
    main()
