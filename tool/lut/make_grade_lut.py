#!/usr/bin/env python3
"""Generate procedural colour-grade LUTs for every look.

tool/lut/build_lut.py fits a LUT to real reference photos; until those
exist (docs/LOOKS.md tuning process) each look gets a grade built here from
the *documented* character of its real-world counterpart. These are
informed starting grades, NOT measurements. When a look is tuned against
reference shots its LUT is replaced by the fitted one and this entry goes.

Grade ops, in order (all on the 33^3 grid, packed as a 1089x33 strip: red on
the tile's x, green on y, blue selects the tile):
  mix     3x3 channel matrix (dye crosstalk; panchromatic mono)
  gamma   per-channel mid curve (<1 lifts)
  gain    per-channel multiplier (white balance / cast)
  curve   -1..1 S-curve on luma-neutral tone (+ contrast, - flatter)
  sat     global saturation
  hues    [(centre_deg, width_deg, sat_mult, hue_shift_deg)] selective colour
  shadow / high  RGB added, weighted toward darks / brights (split tone)
  mono    (r,g,b) channel weights -> greyscale, then `tone` multiplier

Re-run to regenerate:
    ./.venv-tools/bin/python3 tool/lut/make_grade_lut.py
"""

from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 33
OUT = Path(__file__).resolve().parents[2] / "assets" / "luts"
LUMA = np.array([0.2126, 0.7152, 0.0722])

# Hue centres: red 0, orange/skin 25, yellow 55, green 120, cyan 180,
# blue 225, magenta 300.
GRADES = {
    # 2000s CCD compact: slightly cool auto-WB, punchy, reds pushed, skin a
    # touch pink, cyan-leaning shadows, hard-ish contrast.
    "digi03": dict(gain=(1.02, 1.0, 0.96), gamma=(0.99, 0.98, 1.0), curve=0.15, sat=1.04,
                   hues=[(0, 35, 1.1, -3), (25, 25, 0.97, -3), (55, 30, 1.0, 0), (120, 45, 1.08, -8), (180, 35, 1.05, 4), (225, 45, 1.08, 0)],
                   shadow=(-0.01, 0.01, 0.02), high=(0.03, 0.02, -0.02)),
    # Single-use film camera, cheap lab scan: warm, green-leaning shadows,
    # warm-yellow highlights, saturated, moderate contrast.
    "disposable": dict(gain=(1.03, 1.01, 0.97), gamma=(0.98, 0.96, 1.03), curve=0.3, sat=1.12,
                       hues=[(120, 40, 0.9, 14), (55, 30, 1.3, 0), (5, 30, 1.35, 0), (25, 25, 1.2, 2), (300, 40, 1.1, 0)],
                       shadow=(-0.01, 0.04, 0.03), high=(0.03, 0.02, -0.03)),
    # Square instant print: real blacks, pink-cream highlights, green-teal
    # shadows, pastel but not grey (docs/LOOK_RESEARCH.md 2.3).
    "instant": dict(gain=(1.06, 1.0, 0.92), gamma=(1.0, 1.0, 1.0), curve=0.35, sat=1.1,
                    hues=[(20, 30, 1.2, 0), (120, 45, 0.75, 14), (225, 45, 0.85, -12)],
                    shadow=(-0.04, 0.06, 0.06), high=(0.09, 0.03, 0.02)),
    # 35mm compact + consumer colour negative scan: warm flattering skin,
    # slightly muted greens pulled toward yellow, gentle S-curve.
    "point_and_shoot_35": dict(gain=(1.04, 1.0, 0.95), gamma=(0.97, 1.0, 1.03), curve=0.22, sat=1.08,
                               hues=[(25, 30, 1.12, 0), (120, 45, 0.75, 12), (225, 45, 0.9, -8)],
                               shadow=(0.0, 0.04, 0.07), high=(0.06, 0.02, -0.06)),
    # Panchromatic 400-speed B&W: red-leaning response (skin lightens, sky
    # darkens a touch), very slightly warm base.
    "mono_400": dict(mono=(0.32, 0.54, 0.14), tone=(1.0, 0.995, 0.975), curve=0.45),
    # Tungsten-balanced cine stock: cool cyan cast in daylight, teal shadows,
    # orange highlights.
    "cine_800": dict(gain=(0.92, 1.0, 1.1), gamma=(1.03, 1.0, 0.97), curve=0.32, sat=1.1,
                     hues=[(0, 30, 1.2, 0), (25, 25, 1.12, 0), (160, 45, 1.15, 0), (215, 40, 1.2, 0)],
                     shadow=(-0.03, 0.04, 0.08), high=(0.07, 0.03, -0.04)),
    # --- Video ---
    # VHS: warm-magenta tape colour, reds bloom, blues sink, lifted blacks.
    "vhs": dict(gain=(1.04, 0.98, 0.95), gamma=(0.98, 1.0, 1.04), curve=0.1, sat=1.05,
                hues=[(0, 35, 1.15, 0), (225, 45, 0.85, 0)],
                shadow=(0.03, 0.0, 0.04), high=(0.03, 0.01, -0.02)),
    # Hi8: cleaner, slightly warm consumer-camcorder colour.
    "hi8": dict(gain=(1.03, 1.0, 0.96), gamma=(1.0, 1.0, 1.02), curve=0.12, sat=1.05,
                shadow=(0.0, 0.01, 0.02), high=(0.02, 0.01, -0.02)),
    # MiniDV: cool, crisp, slightly cyan digital camcorder.
    "minidv": dict(gain=(0.96, 1.0, 1.05), gamma=(1.02, 1.0, 0.98), curve=0.15, sat=1.0,
                   hues=[(180, 40, 1.1, 0)],
                   shadow=(-0.01, 0.02, 0.04), high=(0.0, 0.01, 0.02)),
    # Super 8 reversal: warm, faded, magenta-leaning shadows, golden highs.
    "super8": dict(gain=(1.07, 1.0, 0.86), gamma=(0.98, 1.0, 1.06), curve=0.15, sat=1.05,
                   hues=[(55, 30, 1.15, 0), (120, 45, 0.85, 6)],
                   shadow=(0.04, 0.0, 0.03), high=(0.05, 0.03, -0.05)),
    # Flip cam: punchy auto-everything, cyan-ish skies.
    "flip": dict(gain=(1.0, 1.0, 1.02), gamma=(1.0, 0.98, 0.98), curve=0.25, sat=1.15,
                 hues=[(225, 45, 1.1, -5)]),
    # Webcam: sickly green-yellow fluorescent office.
    "webcam": dict(gain=(0.96, 1.04, 0.9), gamma=(1.04, 1.0, 1.05), curve=0.2, sat=0.95,
                   shadow=(0.0, 0.03, 0.01), high=(0.02, 0.03, -0.04)),
}


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    safe = np.where(d == 0, 1, d)
    h = np.where(mx == r, ((g - b) / safe) % 6, h)
    h = np.where(mx == g, (b - r) / safe + 2, h)
    h = np.where(mx == b, (r - g) / safe + 4, h)
    h = np.where(d == 0, 0, h) * 60.0
    s = np.where(mx == 0, 0, d / np.where(mx == 0, 1, mx))
    return h % 360.0, s, mx


def hsv_to_rgb(h, s, v):
    h6 = (h % 360.0) / 60.0
    c = v * s
    x = c * (1 - np.abs(h6 % 2 - 1))
    m = v - c
    z = np.zeros_like(h)
    sector = np.floor(h6).astype(int) % 6
    r = np.choose(sector, [c, x, z, z, x, c])
    g = np.choose(sector, [x, c, c, x, z, z])
    b = np.choose(sector, [z, z, x, c, c, x])
    return np.stack([r + m, g + m, b + m], -1)


def selective_colour(rgb, bands):
    h, s, v = rgb_to_hsv(rgb)
    sat_mult = np.ones_like(s)
    shift = np.zeros_like(s)
    for centre, width, sm, hs in bands:
        d = np.abs((h - centre + 180) % 360 - 180)
        w = np.clip(1 - d / width, 0, 1)
        w = w * w * (3 - 2 * w)
        sat_mult = sat_mult * (1 + (sm - 1) * w)
        shift = shift + hs * w
    return hsv_to_rgb(h + shift, np.clip(s * sat_mult, 0, 1), v)


def s_curve(x, amount):
    if amount >= 0:
        return x + amount * (x * x * (3 - 2 * x) - x)
    return x + amount * (x - (x * x * (3 - 2 * x)))  # flatter: pull toward linear


def build(p: dict) -> Image.Image:
    axis = np.linspace(0.0, 1.0, SIZE)
    r, g, b = np.meshgrid(axis, axis, axis, indexing="ij")  # [r, g, b]
    rgb = np.stack([r, g, b], axis=-1)

    if "mono" in p:
        grey = (rgb * np.array(p["mono"])).sum(-1, keepdims=True)
        grey = s_curve(np.clip(grey, 0, 1), p.get("curve", 0))
        rgb = np.clip(grey * np.array(p.get("tone", (1, 1, 1))), 0, 1)
    else:
        rgb = np.power(rgb, np.array(p.get("gamma", (1, 1, 1))))
        rgb = rgb * np.array(p.get("gain", (1, 1, 1)))
        rgb = np.clip(rgb, 0, 1)
        rgb = s_curve(rgb, p.get("curve", 0))

        luma = (rgb * LUMA).sum(-1, keepdims=True)
        rgb = luma + (rgb - luma) * p.get("sat", 1.0)
        rgb = np.clip(rgb, 0, 1)
        if "hues" in p:
            rgb = selective_colour(rgb, p["hues"])

        luma = (rgb * LUMA).sum(-1, keepdims=True)
        rgb = (rgb + np.array(p.get("shadow", (0, 0, 0))) * (1 - luma) ** 2
               + np.array(p.get("high", (0, 0, 0))) * luma ** 2)
        rgb = np.clip(rgb, 0.0, 1.0)

    strip = np.zeros((SIZE, SIZE * SIZE, 3), dtype=np.uint8)
    for bi in range(SIZE):
        for gi in range(SIZE):
            for ri in range(SIZE):
                strip[gi, bi * SIZE + ri] = np.round(rgb[ri, gi, bi] * 255)
    return Image.fromarray(strip, "RGB")


if __name__ == "__main__":
    for name, params in GRADES.items():
        build(params).save(OUT / f"{name}.png")
        print("wrote", OUT / f"{name}.png")
