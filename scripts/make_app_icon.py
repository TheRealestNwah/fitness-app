#!/usr/bin/env python3
"""Draws the Stride app icon: a progress ring, like the calorie ring on Today, around a
rising stride mark. Writes the iOS light, dark and tinted icons and the watchOS icon.

Needs Pillow (pip install pillow). Run from the repository root: python3 scripts/make_app_icon.py
"""
import math
import os

from PIL import Image, ImageDraw

SIZE = 1024
SCALE = 4                      # drawn large, then scaled down for smooth edges
S = SIZE * SCALE

# The app's accent colour (AccentColor) and its dark-mode variant.
DEEP = (12, 84, 122)
ACCENT = (23, 120, 158)
LIGHT = (77, 184, 230)

IOS_DIR = "FitnessApp/Assets.xcassets/AppIcon.appiconset"
WATCH_DIR = "StrideWatch/Assets.xcassets/AppIcon.appiconset"


def gradient(top, bottom):
    """Vertical gradient, top to bottom."""
    column = Image.new("RGB", (1, S))
    for y in range(S):
        t = y / (S - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return column.resize((S, S))


def glyph_mask(ring_only=False):
    """White-on-black mask of the ring and the stride mark."""
    mask = Image.new("L", (S, S), 0)
    draw = ImageDraw.Draw(mask)
    c = S / 2
    radius = S * 0.33
    width = round(S * 0.085)

    # Faint full track, then the three-quarter progress arc with rounded ends.
    box = [c - radius, c - radius, c + radius, c + radius]
    draw.arc(box, 0, 360, fill=70, width=width)
    start, end = -90, 180
    draw.arc(box, start, end, fill=255, width=width)
    for angle in (start, end):
        a = math.radians(angle)
        x, y = c + (radius - width / 2) * math.cos(a), c + (radius - width / 2) * math.sin(a)
        draw.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=255)
    if ring_only:
        return mask

    # The stride: a rising zig-zag trend line ending in an arrowhead.
    stroke = S * 0.07
    points = [(c - S * 0.17, c + S * 0.09), (c - S * 0.06, c - S * 0.02),
              (c + S * 0.02, c + S * 0.06), (c + S * 0.12, c - S * 0.04)]
    for (x1, y1), (x2, y2) in zip(points, points[1:]):
        # Each segment as a rectangle, so the ends meet the round joints exactly.
        a = math.atan2(y2 - y1, x2 - x1)
        dx, dy = -math.sin(a) * stroke / 2, math.cos(a) * stroke / 2
        draw.polygon([(x1 + dx, y1 + dy), (x2 + dx, y2 + dy), (x2 - dx, y2 - dy), (x1 - dx, y1 - dy)], fill=255)
    for x, y in points[:-1]:
        draw.ellipse([x - stroke / 2, y - stroke / 2, x + stroke / 2, y + stroke / 2], fill=255)
    # Arrowhead whose base is centred on the last point, covering the line's square end.
    half_angle, head = 0.55, S * 0.13
    a = math.atan2(points[-1][1] - points[-2][1], points[-1][0] - points[-2][0])
    reach = head * math.cos(half_angle)
    tip = (points[-1][0] + reach * math.cos(a), points[-1][1] + reach * math.sin(a))
    left = (tip[0] - head * math.cos(a - half_angle), tip[1] - head * math.sin(a - half_angle))
    right = (tip[0] - head * math.cos(a + half_angle), tip[1] - head * math.sin(a + half_angle))
    draw.polygon([tip, left, right], fill=255)
    return mask


def finish(image):
    return image.resize((SIZE, SIZE), Image.LANCZOS)


def light():
    background = gradient(LIGHT, DEEP)
    white = Image.new("RGB", (S, S), (255, 255, 255))
    return finish(Image.composite(white, background, glyph_mask()))


def dark():
    """iOS 18 dark icon: the glyph in the accent gradient on a transparent background."""
    colored = gradient(LIGHT, ACCENT).convert("RGBA")
    colored.putalpha(glyph_mask())
    return finish(colored)


def tinted():
    """iOS 18 tinted icon: grayscale; the system applies the tint colour by brightness."""
    return finish(Image.merge("RGB", [glyph_mask()] * 3)).convert("L")


def main():
    os.makedirs(IOS_DIR, exist_ok=True)
    os.makedirs(WATCH_DIR, exist_ok=True)
    icon = light()
    icon.save(os.path.join(IOS_DIR, "AppIcon.png"))
    dark().save(os.path.join(IOS_DIR, "AppIcon-Dark.png"))
    tinted().save(os.path.join(IOS_DIR, "AppIcon-Tinted.png"))
    # watchOS masks the icon to a circle; the ring sits inside it.
    icon.save(os.path.join(WATCH_DIR, "AppIcon.png"))
    print("Wrote", IOS_DIR, "and", WATCH_DIR)


if __name__ == "__main__":
    main()
