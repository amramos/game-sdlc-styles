"""Build the floor, brick and counter-top textures in MaterialCraft (headless), then export them.

usage: python make_textures.py            (run from this folder)

Each material is a fresh `pbr` package at its final size (64 px), with one colour pixel processor
wired to basecolor. Every colour is a palette role from example-palette.gpl, shaded by a factor;
per-tile variation comes from a position hash, so the textures tile exactly. The exported basecolor
is then cut to 5 bits per channel (the era's 15-bit colour) and written to ../<name>.png.
"""
import json, os, subprocess
from PIL import Image
from mcfun import F, batch

MC = os.environ.get("MATERIALCRAFT_CLI", "materialcraft-cli")  # the CLI on PATH, or its full path
PAL = {"floor-light": "#E0CCA0", "floor-dark": "#2A2A30", "wall": "#8FCFBF", "wood": "#7A4E2E",
       "vinyl": "#B02A34", "chrome": "#C4CCD6", "formica": "#E2CA7A", "brick": "#9A5A48"}
SIZE = 64


def cell(f, p, nx, ny):
    """Integer cell coordinates of $pos on an nx by ny grid, and the position inside the cell (0..1)."""
    x = f.mul(f.sw(p, 0), f.c1(nx)); y = f.mul(f.sw(p, 1), f.c1(ny))
    cx, cy = f.floor(x), f.floor(y)
    return cx, cy, f.sub(x, cx), f.sub(y, cy)


def floor_tex():
    """Checkerboard linoleum: 4 x 4 tiles of 16 px, each tile a touch lighter or darker, a one-texel
    bevel (light top-left, dark bottom-right) and sparse scuffs."""
    f = F(); p = f.pos()
    cx, cy, fx, fy = cell(f, p, 4, 4)
    dark = f.gt(f.mod(f.add(cx, cy), f.c1(2)), f.c1(0.5))
    base = f.ifelse(dark, f.hexc(PAL["floor-dark"]), f.hexc(PAL["floor-light"]))
    var = f.add(f.c1(0.93), f.mul(f.hash(f.v2(cx, cy), 1.0), f.c1(0.1)))          # 0.93..1.03 per tile
    col = f.scale(base, var)
    t = f.c1(1.0 / 16)                                                              # one texel inside a tile
    edge_lo = f.ifelse(f.gt(fy, f.c1(1 - 1.0 / 16)), f.c1(0.8), f.c1(1.0))         # bottom row
    edge_lo = f.ifelse(f.gt(fx, f.c1(1 - 1.0 / 16)), f.c1(0.8), edge_lo)            # right column
    edge = f.ifelse(f.lt(fy, t), f.c1(1.12), edge_lo)                               # top row
    col = f.scale(col, edge)
    px = f.floor(f.scale(p, f.c1(SIZE)))
    h = f.hash(px, 7.0)
    scuff = f.ifelse(f.gt(h, f.c1(0.965)), f.c1(0.82), f.c1(1.0))
    return f.graph(f.scale(col, scuff))


def brick_tex():
    """Running-bond brick: 4 bricks of 16 x 8 px per row, offset by half a brick on odd rows, one-texel
    grey mortar, each brick its own shade with a lit top edge and a shaded bottom edge."""
    f = F(); p = f.pos()
    y = f.mul(f.sw(p, 1), f.c1(8)); cy = f.floor(y); fy = f.sub(y, cy)
    off = f.mul(f.mod(cy, f.c1(2)), f.c1(0.5))
    x = f.add(f.mul(f.sw(p, 0), f.c1(4)), off); cx = f.floor(x); fx = f.sub(x, cx)
    cxw = f.mod(cx, f.c1(4))                                                         # wrap so it tiles
    h = f.hash(f.v2(cxw, cy), 3.0)
    shade = f.add(f.c1(0.8), f.mul(h, f.c1(0.32)))                                   # 0.80..1.12
    burnt = f.gt(f.hash(f.v2(cy, cxw), 11.0), f.c1(0.86))
    b = f.ifelse(burnt, f.mix(f.hexc(PAL["brick"]), f.hexc(PAL["wood"]), f.c1(0.6)), f.hexc(PAL["brick"]))
    col = f.scale(b, shade)
    top = f.lt(fy, f.c1(1.0 / 8 * 1.5))                                              # row 1 of 7 brick rows
    low = f.gt(fy, f.c1(1 - 1.0 / 8 * 2.5))                                          # last brick row
    col = f.scale(col, f.ifelse(top, f.c1(1.15), f.ifelse(low, f.c1(0.84), f.c1(1.0))))
    px = f.floor(f.scale(p, f.c1(SIZE)))
    pit = f.gt(f.hash(px, 5.0), f.c1(0.93))
    col = f.scale(col, f.ifelse(pit, f.c1(0.88), f.c1(1.0)))
    mortar_y = f.gt(fy, f.c1(1 - 1.0 / 8))                                           # bottom texel row
    mortar_x = f.lt(fx, f.c1(1.0 / 16))                                              # left texel column
    mortar = f.scale(f.hexc(PAL["chrome"], 0.72), f.ifelse(pit, f.c1(0.9), f.c1(1.0)))
    col = f.ifelse(mortar_y, mortar, f.ifelse(mortar_x, mortar, col))
    return f.graph(col)


def formica_tex():
    """Speckled counter laminate: the base laminate with sparse two-texel flecks one shade darker
    and a few in the wall's teal at low contrast. No thin bright lines: at grazing angles they
    stretch into streaks."""
    f = F(); p = f.pos()
    base = f.hexc(PAL["formica"])
    cx, cy, _, _ = cell(f, p, 32, 64)                                                # 2 x 1 texel flecks
    h = f.hash(f.v2(cx, cy), 2.0)
    dark = f.scale(base, f.c1(0.8))
    teal = f.mix(base, f.hexc(PAL["wall"]), f.c1(0.45))
    warm = f.mix(base, f.hexc(PAL["vinyl"]), f.c1(0.18))
    col = f.ifelse(f.gt(h, f.c1(0.94)), dark,
                   f.ifelse(f.gt(h, f.c1(0.92)), teal, f.ifelse(f.gt(h, f.c1(0.905)), warm, base)))
    px = f.floor(f.scale(p, f.c1(SIZE)))
    g = f.hash(px, 9.0)
    col = f.scale(col, f.add(f.c1(0.96), f.mul(g, f.c1(0.06))))                        # faint grain
    return f.graph(col)


def build(name, fn):
    sbs0, sbs = f"{name}_base.sbs", f"{name}.sbs"
    subprocess.run([MC, "new", "pbr", sbs0, "--size", str(SIZE), "--name", name], check=True, capture_output=True)
    with open(f"{name}.json", "w") as fh:
        json.dump(batch(sbs0, sbs, fn), fh)
    r = subprocess.run([MC, "batch", f"{name}.json"], capture_output=True, text=True)
    if r.returncode or '"error": "' in r.stdout:
        raise SystemExit(f"{name}: {r.stdout[-2000:]} {r.stderr[-2000:]}")
    out = f"out_{name}"
    subprocess.run([MC, "export", sbs, out, "--size", str(SIZE)], check=True, capture_output=True)
    im = Image.open(os.path.join(out, f"{name}_basecolor.png")).convert("RGB")
    im = im.point(lambda v: v >> 3 << 3)                                              # 5 bits per channel
    im.save(os.path.join("..", f"{name}.png"))
    im.resize((SIZE * 8, SIZE * 8), Image.NEAREST).save(f"preview_{name}.png")
    os.remove(sbs0); os.remove(f"{name}.json")
    print(name, "ok")


if __name__ == "__main__":
    build("floor", floor_tex())
    build("brick", brick_tex())
    build("formica", formica_tex())
