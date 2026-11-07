"""Cleaned palette PNGs -> outline rule -> assets/sprites.js (role letters per pixel).
usage: tojs.py <assets dir> name=file.png ...   (writes the outlined PNG back in place)"""
import sys, os
from PIL import Image
HEX = {'1E1430':'k','FFF4D6':'p','FF38B0':'A','6BD94A':'G','FF4B3E':'X','B67CFF':'V','6B2E3A':'1','B8543A':'2',
       'E89A4C':'3','FFD77A':'4','2B2459':'a','33589E':'b','3FA0C8':'c','9BE8E4':'d','BFE0E6':'s','E6C4A4':'f'}
assets = sys.argv[1]; out = {}
for arg in sys.argv[2:]:
    name, f = arg.split('=', 1); path = os.path.join(assets, f)
    im = Image.open(path).convert('RGBA'); w, h = im.size; px = im.load()
    g = [[None if px[x, y][3] < 128 else HEX['%02X%02X%02X' % px[x, y][:3]] for x in range(w)] for y in range(h)]
    # one consistent rule: every opaque pixel touching transparency (or the canvas edge) is ink
    edge = lambda x, y: x < 0 or y < 0 or x >= w or y >= h or g[y][x] is None
    o = [row[:] for row in g]
    for y in range(h):
        for x in range(w):
            if g[y][x] and any(edge(x+dx, y+dy) for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))): o[y][x] = 'k'
    inv = {v: k for k, v in HEX.items()}
    for y in range(h):
        for x in range(w):
            c = o[y][x]; px[x, y] = (0, 0, 0, 0) if c is None else tuple(int(inv[c][i:i+2], 16) for i in (0, 2, 4)) + (255,)
    im.save(path)
    out[name] = [''.join(c or '.' for c in row) for row in o]
with open(os.path.join(assets, 'sprites.js'), 'w') as fh:
    fh.write('// Generated from the PNGs in assets/sprites by the cleanup step (see assets/README.md).\n')
    fh.write('// One role letter per pixel (k ink, p paper, 1-4 warm, a-d cool, . clear), so palette swaps reach every pixel.\n')
    fh.write('window.GEN_SPRITES = {\n')
    for k, rows in out.items():
        fh.write('  %s: [\n%s\n  ],\n' % (k, '\n'.join("    '%s'," % r for r in rows)))
    fh.write('};\n')
for k, rows in out.items(): print(k); print('\n'.join(rows))
