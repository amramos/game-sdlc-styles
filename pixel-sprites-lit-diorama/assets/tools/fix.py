# Meaning fixes and a closed 1-px outline, on the cleaned sprites.
from PIL import Image
import sys
C = dict(o=(34,28,36), s=(224,168,130), a=(208,72,60), w=(191,160,96), W=(138,115,69))
def put(im, pts, col):
    for x, y in pts: im.putpixel((x, y), C[col] + (255,))
def recolour(im, box, frm, to):
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            p = im.getpixel((x, y))
            if p[3] > 0 and p[:3] == C[frm]: im.putpixel((x, y), C[to] + (255,))
def outline(im):
    w, h = im.size; px = im.load(); add = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3]: continue
            for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                X, Y = x + dx, y + dy
                if 0 <= X < w and 0 <= Y < h and px[X, Y][3] and px[X, Y][:3] != C['o']: add.append((x, y)); break
    for x, y in add: px[x, y] = C['o'] + (255,)
    return len(add)
for n in ['elder', 'shopper', 'kid', 'vendor']:
    im = Image.open(f'clean2/{n}.png').convert('RGBA')
    if n == 'shopper': recolour(im, (5, 30, 13, 36), 'a', 'w'); recolour(im, (5, 30, 13, 36), 's', 'W')
    if n == 'kid': put(im, [(9, 29), (8, 33), (21, 29)], 's'); put(im, [(10, 31)], 's')
    k = outline(im); im.save(f'{sys.argv[1]}/{n}.png'); print(n, 'outline px added', k)
