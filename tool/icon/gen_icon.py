#!/usr/bin/env python3
"""Generate the app icon: a black plate, a cream Anton "S", and film
sprocket holes down the right edge. No brand marks.

    ./.venv-tools/bin/python3 tool/icon/gen_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SIZE = 1024
INK = (17, 17, 17, 255)
CREAM = (243, 235, 221, 255)


def glyph_layer(with_holes: bool) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(str(ROOT / "assets/fonts/Anton-Regular.ttf"), 620)
    box = d.textbbox((0, 0), "S", font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (SIZE - w) / 2 - box[0] - (40 if with_holes else 0)
    y = (SIZE - h) / 2 - box[1]
    d.text((x, y), "S", font=font, fill=CREAM)
    if with_holes:
        for i in range(5):
            cy = 190 + i * 160
            d.rounded_rectangle((820, cy, 880, cy + 90), radius=14, fill=CREAM)
    return img


full = Image.new("RGBA", (SIZE, SIZE), INK)
full.alpha_composite(glyph_layer(True))
full.save(ROOT / "assets/icon/icon.png")

# Adaptive foreground: keep everything inside the 66% safe zone.
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
small = glyph_layer(True).resize((int(SIZE * 0.66), int(SIZE * 0.66)), Image.LANCZOS)
fg.alpha_composite(small, (int(SIZE * 0.17), int(SIZE * 0.17)))
fg.save(ROOT / "assets/icon/icon_foreground.png")
print("wrote assets/icon/icon.png and icon_foreground.png")
