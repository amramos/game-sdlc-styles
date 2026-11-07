"""Hand edits at true size, as a sprite artist would make them (documented in assets/README.md).
usage: handedit.py <assets/sprites dir>"""
import sys, os
from PIL import Image
D = sys.argv[1]
def load(n):
    im = Image.open(os.path.join(D, n)).convert('RGBA'); return im
def rows_set(im, y, s, legend):
    for x, ch in enumerate(s):
        im.putpixel((x, y), (0, 0, 0, 0) if ch == '.' else legend[ch])
INK = (0x1E, 0x14, 0x30, 255)
L = {'A': INK, 'D': (0xB8, 0x54, 0x3A, 255), 'E': (0x6B, 0x2E, 0x3A, 255), 'F': (0xE8, 0x9A, 0x4C, 255),
     'C': (0xFF, 0xD7, 0x7A, 255), 'T': (0x9B, 0xE8, 0xE4, 255)}
# trader 1: the eyes vanished in the mode downscale; place them, and open the face under the turban
t = load('cast_trader1.png')
rows_set(t, 3, '....ATTTTTTA....', L)
rows_set(t, 4, '....ACACCACA....', L)
t.save(os.path.join(D, 'cast_trader1.png'))
# traveller walk: the generated pose is contact A; passing and contact B are redrawn legs (rows 19-23)
base = load('cast_traveller.png')
legs = {
  'cast_traveller_walk2': ['.....ADFFA......', '.....AFFFA......', '.....AEEEA......', '.....AEEEEA.....', '......AAAAA.....'],
  'cast_traveller_walk3': ['...AFFA..ADDA...', '..AFFFA...ADDA..', '..AEEA....AEEEA.', '.AEEEA.....AEEA.', '..AAA......AAA..'],
  'cast_traveller_walk4': ['......ADDFA.....', '......ADFFA.....', '......AEEEA.....', '......AEEEEA....', '.......AAAAA....'],
}
for name, rs in legs.items():
    im = base.copy()
    for i, r in enumerate(rs): rows_set(im, 19 + i, r, L)
    im.save(os.path.join(D, name + '.png'))
print('ok')
# camel idle: the head and neck (columns 0-11, rows 0-10) dip 1 px; the body stays put
c = load('beast_camel.png'); b = c.copy()
for y in range(10, 0, -1):
    for x in range(12): b.putpixel((x, y), c.getpixel((x, y - 1)))
for x in range(12): b.putpixel((x, 0), (0, 0, 0, 0))
b.save(os.path.join(D, 'beast_camel_chew.png'))
print('camel ok')
# portrait: the cleaned bust sits 1 px left and 2 px high in its canvas; centre it on the frame's bottom edge
p = os.path.join(D, 'bust_trader2.png'); im = load('bust_trader2.png')
if im.getpixel((0, 19))[3] and not im.getpixel((0, 23))[3]:   # only once
    out = Image.new('RGBA', im.size, (0, 0, 0, 0)); out.alpha_composite(im, dest=(1, 2)); out.save(p)
print('bust ok')
# portrait skin: the bust snapped to warm-4 where the standing sprite uses warm-3; match the sprite
im = load('bust_trader2.png')
for y in range(im.height):
    for x in range(im.width):
        if im.getpixel((x, y)) == (0xFF, 0xD7, 0x7A, 255): im.putpixel((x, y), (0xE8, 0x9A, 0x4C, 255))
im.save(p); print('bust skin ok')
