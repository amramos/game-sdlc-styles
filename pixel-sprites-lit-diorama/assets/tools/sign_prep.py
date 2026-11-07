"""Meaning fixes before the palette snap for the painted stall signs: the board's browns are
darkened so they land on wood (not roof), purple fruit is turned toward the roof's red-brown,
greens and creams are left alone. usage: sign_prep.py <framed.png> <out.png>"""
import sys, colorsys
import numpy as np
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGBA').resize((48 * 16, 24 * 16), Image.NEAREST)
a = np.array(im).astype(float) / 255
out = a.copy()
for y in range(a.shape[0]):
    for x in range(a.shape[1]):
        r, g, b, al = a[y, x]
        if al < 0.5: continue
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if 0.02 <= h <= 0.12 and s > 0.35:          # board browns and oranges -> toward wood
            out[y, x, :3] = [c * 0.8 for c in (r, g, b)]
        elif 0.72 <= h <= 0.95:                       # purple fruit -> red-brown, kept dark
            out[y, x, :3] = colorsys.hsv_to_rgb(0.04, min(1, s * 0.9), v * 0.95)
Image.fromarray((out * 255).clip(0, 255).astype('uint8')).save(sys.argv[2])
