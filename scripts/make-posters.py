#!/usr/bin/env python3
"""Draws stand-in film posters for invented films, so the edition's key art (ADR-049) can be built and checked without
TMDB and without carrying anyone's artwork in the repo. Each has the tonal range of a real one-sheet: a lit sky, a
silhouetted subject, deep shadow, and a title block at the foot that the saliency crop should leave out.

Usage: python3 scripts/make-posters.py Stub/Resources/Fixtures
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1000, 1500


def gradient(top, bottom):
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def font(size):
    for name in ["/System/Library/Fonts/Supplemental/Futura.ttc", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def title_block(img, title, credit):
    d = ImageDraw.Draw(img)
    d.text((W / 2, H - 230), title, font=font(92), fill=(245, 238, 225), anchor="mm")
    d.text((W / 2, H - 140), credit, font=font(30), fill=(200, 190, 175), anchor="mm")


def orchard(path):
    """Salt in the Orchard: a low sun over rows of trees, a figure on a ladder."""
    img = gradient((246, 196, 130), (120, 52, 38))
    d = ImageDraw.Draw(img)
    d.ellipse([W / 2 - 170, 330, W / 2 + 170, 670], fill=(255, 226, 170))
    rnd = random.Random(7)
    for row, (y, shade) in enumerate([(820, (92, 44, 34)), (930, (62, 30, 26)), (1060, (34, 18, 16))]):
        for i in range(-1, 9):
            x = i * 130 + (row * 55) % 130
            r = 70 + rnd.randint(-10, 18) + row * 12
            d.ellipse([x - r, y - r, x + r, y + r * 0.8], fill=shade)
            d.rectangle([x - 8, y, x + 8, y + 120], fill=shade)
    d.rectangle([0, 1080, W, H], fill=(28, 14, 12))
    # The figure on the ladder, against the sun.
    d.line([(560, 900), (620, 560)], fill=(24, 12, 10), width=10)
    d.line([(610, 900), (670, 560)], fill=(24, 12, 10), width=10)
    for k in range(8):
        y = 880 - k * 42
        d.line([(563 + k * 7.5, y), (613 + k * 7.5, y)], fill=(24, 12, 10), width=7)
    d.ellipse([608, 470, 656, 518], fill=(24, 12, 10))
    d.polygon([(600, 520), (668, 520), (676, 640), (596, 640)], fill=(24, 12, 10))
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    title_block(img, "SALT IN THE ORCHARD", "A FILM IN THE LATE SUMMER")
    img.save(path, quality=88)


def harbour(path):
    """Glass Harbour: a face in profile against a night harbour, lit from one side."""
    img = gradient((16, 30, 58), (6, 10, 20))
    d = ImageDraw.Draw(img)
    for i in range(40):
        x = 60 + (i * 97) % 880
        y = 900 + (i * 53) % 220
        d.rectangle([x, y, x + 6, y + 30 + (i * 13) % 50], fill=(240, 200, 120))
    d.rectangle([0, 1120, W, H], fill=(8, 12, 22))
    # The profile: forehead, nose, lips, chin, neck, as one lit shape.
    face = [(560, 180), (690, 210), (760, 330), (770, 450), (820, 520), (780, 560), (795, 600), (770, 640),
            (780, 690), (720, 760), (690, 860), (720, 1000), (380, 1000), (420, 820), (380, 640), (360, 420),
            (420, 260)]
    shade = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shade).polygon(face, fill=255)
    lit = gradient((70, 90, 130), (230, 210, 190)).transpose(Image.Transpose.ROTATE_90).resize((W, H))
    img.paste(lit, (0, 0), shade.filter(ImageFilter.GaussianBlur(3)))
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    title_block(img, "GLASS HARBOUR", "EVERY LIGHT ON THE WATER IS SOMEONE")
    img.save(path, quality=88)


if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "Stub/Resources/Fixtures")
    orchard(out / "poster-orchard.jpg")
    harbour(out / "poster-harbour.jpg")
    print("wrote", out / "poster-orchard.jpg", out / "poster-harbour.jpg")
