"""Build tileable greyscale value maps in MaterialCraft from small expression graphs.

Each texture is one Pixel Processor whose per-pixel function is written here as Python
expressions and compiled to MaterialCraft's function-graph JSON. The output is posterised to
four levels inside the graph, so the export is already a 4-step value ramp.
usage: python mcgen.py <outdir> [name ...]
"""
import json, math, subprocess, sys, os

MC = os.environ.get('MATERIALCRAFT_CLI', 'materialcraft-cli')  # the CLI on PATH, or its full path
T = {1: 256, 2: 512, 3: 1024, 4: 2048, 'b': 4}


class E:
    _n = 0
    def __init__(self, op, inputs=(), value=None, dim=1):
        E._n += 1; self.id = E._n; self.op = op; self.inputs = list(inputs); self.value = value; self.dim = dim
    def _b(self, op, o):
        o = lift(o); return E(op, [self, o], dim=max(self.dim, o.dim) if op != 'mulscalar' else self.dim)
    def __add__(self, o): return self._b('add', o)
    __radd__ = __add__
    def __sub__(self, o): return self._b('sub', o)
    def __rsub__(self, o): return lift(o)._b('sub', self)
    def __mul__(self, o):
        o = lift(o)
        if self.dim > 1 and o.dim == 1: return E('mulscalar', [self, o], dim=self.dim)
        return self._b('mul', o)
    __rmul__ = __mul__
    def __truediv__(self, o): return self._b('div', o)
    def __rtruediv__(self, o): return lift(o)._b('div', self)
    def __getitem__(self, i): return E('swizzle1', [self], {'t': 'int', 'v': i}, 1)


def lift(v):
    if isinstance(v, E): return v
    return E('const_float1', [], {'t': 'float', 'v': float(v)}, 1)

def f1(op, *a): a = [lift(x) for x in a]; return E(op, a, dim=max(x.dim for x in a))
floor = lambda a: f1('floor', a)
sin = lambda a: f1('sin', a)
absf = lambda a: f1('abs', a)
fmin = lambda a, b: f1('min', a, b)
fmax = lambda a, b: f1('max', a, b)
lerp = lambda a, b, t: E('lerp', [lift(a), lift(b), lift(t)], dim=max(lift(a).dim, lift(b).dim))
gt = lambda a, b: E('gt', [lift(a), lift(b)], dim='b')
ifelse = lambda c, a, b: E('ifelse', [c, lift(a), lift(b)], dim=max(lift(a).dim, lift(b).dim))
frac = lambda a: a - floor(a)
clamp01 = lambda a: fmin(fmax(a, 0.0), 1.0)
def wrap(a, n): return a - floor(a / n) * n

POS = E('get_float2', [], {'t': 'text', 'v': '$pos'}, 2)
X, Y = POS[0], POS[1]

def hash2(a, b, s=0.0):
    return frac(sin(a * 127.1 + b * 311.7 + s * 74.7) * 43758.5453)

def vnoise(u, v, n, s=0.0):
    """Tileable value noise over an n x n grid, u and v in 0..1."""
    gx, gy = u * n, v * n
    ix, iy = floor(gx), floor(gy)
    fx, fy = gx - ix, gy - iy
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    ix1, iy1 = wrap(ix + 1, n), wrap(iy + 1, n)
    a, b = hash2(ix, iy, s), hash2(ix1, iy, s)
    c, d = hash2(ix, iy1, s), hash2(ix1, iy1, s)
    return lerp(lerp(a, b, sx), lerp(c, d, sx), sy)

def posterise(v, levels=4):
    return clamp01(floor(clamp01(v) * levels * 0.9999) / (levels - 1))


def compile_fn(out):
    nodes, seen = [], {}
    def visit(e):
        if e.id in seen: return
        for i in e.inputs: visit(i)
        seen[e.id] = 1
        n = {'id': e.id, 'inputs': [i.id for i in e.inputs], 'op': e.op, 'pos': [0.0, 0.0],
             'type_code': T[e.dim]}
        if e.value is not None: n['value'] = e.value
        nodes.append(n)
    visit(out)
    return {'t': 'function', 'v': {'nodes': nodes, 'output': out.id}}


# ---------------- the textures (value maps; 1.0 = the role colour as authored) ----------------
PX = 128.0   # texels across the tile, so "pixels" below are texels of the final map

def floor_tiles():
    n = 8.0                                            # 8 x 8 square tiles, 16 texels each
    gu, gv = X * n, Y * n
    cu, cv = floor(gu), floor(gv)
    fu, fv = gu - cu, gv - cv
    h = hash2(cu, cv, 1.0)
    base = 0.55 + 0.30 * h                              # each tile its own shade
    worn = vnoise(X, Y, 4.0, 3.0)
    base = base + (worn - 0.5) * 0.25
    t = 1.0 / 16.0
    edge = ifelse(gt(t, fu), 0.0, ifelse(gt(t, fv), 0.0, base))          # grout, 1 texel
    lit = ifelse(gt(2 * t, fv), base + 0.18, edge)                         # a lit lip under the grout
    lit = ifelse(gt(t, fu), 0.0, ifelse(gt(t, fv), 0.0, lit))
    speck = hash2(floor(X * PX), floor(Y * PX), 9.0)
    v = ifelse(gt(speck, 0.975), lit - 0.25, lit)
    return posterise(v)

def roof_tiles():
    cols, rows = 8.0, 8.0                             # barrel tiles in staggered rows
    gv = Y * rows
    rv = floor(gv); fv = gv - rv
    off = wrap(rv, 2.0) * 0.5
    gu = X * cols + off
    cu = floor(gu); fu = gu - cu
    h = hash2(wrap(cu, cols), rv, 2.0)
    shade = sin(fu * math.pi)                           # rounded across each tile
    v = 0.42 + 0.45 * shade + (h - 0.5) * 0.3
    v = v + fv * 0.15                                   # lighter toward the tile's lower end
    v = ifelse(gt(fv, 0.82), 0.12, v)                    # the shadowed lip of the row above
    return posterise(v)

def plaster():
    big = vnoise(X, Y, 5.0, 5.0) * 0.55 + vnoise(X, Y, 11.0, 6.0) * 0.45
    v = 0.55 + big * 0.55
    # bricks show through where the plaster has fallen away
    bn, bh = 16.0, 32.0
    rv = floor(Y * bh); off = wrap(rv, 2.0) * 0.5
    bu = X * bn + off; fu = bu - floor(bu); fv = Y * bh - rv
    brick = 0.45 + hash2(floor(bu), rv, 7.0) * 0.25
    brick = ifelse(gt(0.12, fu), 0.15, ifelse(gt(0.16, fv), 0.15, brick))
    bare = gt(0.24, big)
    v = ifelse(bare, brick, v)
    streak = hash2(floor(X * 256.0 / 2.0), floor(Y * 6.0), 8.0)          # faint vertical weathering
    v = v - ifelse(gt(streak, 0.85), 0.08, 0.0)
    return posterise(v)

def wood_planks():
    n = 8.0                                            # planks across the tile, 16 texels each
    gv = Y * n; rv = floor(gv); fv = gv - rv
    seam = hash2(rv, 0.0, 4.0)                          # one butt joint per plank per tile
    u2 = wrap(X - seam + 1.0, 1.0)
    h = hash2(rv, floor(X - seam + 1.0), 3.0)
    grain = sin((fv * 5.0 + sin(u2 * 2 * math.pi * 2.0 + h * 6.0) * 0.35) * 2 * math.pi)
    v = 0.62 + 0.18 * h + 0.12 * grain
    v = ifelse(gt(1.0 / 16.0, fv), 0.08, v)             # gap between planks
    v = ifelse(gt(1.5 / PX, u2), 0.12, v)               # butt joint
    v = ifelse(gt(2.0 / 16.0, fv), ifelse(gt(fv, 1.0 / 16.0), v + 0.2, v), v)
    return posterise(v)

SIZE = {'plaster': 256}
TEXTURES = {'floor-tiles': floor_tiles, 'roof-tiles': roof_tiles, 'plaster': plaster, 'wood-planks': wood_planks}


def build(name, out_dir):
    E._n = 1000
    fn = compile_fn(TEXTURES[name]())
    sbs = os.path.join(out_dir, name + '.sbs')
    subprocess.run([MC, 'new', 'empty', sbs, '--size', str(SIZE.get(name, 128)), '--name', name.replace('-', '_')], check=True, capture_output=True)
    steps = [
        {'id': 'graph.node.add', 'params': {'def': 'pixel_processor', 'params': {'color_mode': {'t': 'bool', 'v': False}}}},
        {'id': 'graph.select', 'params': {'ids': [1]}},
        {'id': 'graph.node.param', 'params': {'id': 1, 'param': 'function', 'value': fn}},
        {'id': 'graph.node.add', 'params': {'def': 'output', 'connectFrom': {'node': 1}, 'params': {'identifier': {'t': 'text', 'v': 'value'}}}},
        {'id': 'graph.cook', 'params': {'full': True}},
    ]
    script = os.path.join(out_dir, name + '_batch.json')
    json.dump({'open': sbs, 'steps': steps, 'save': sbs}, open(script, 'w'))
    r = subprocess.run([MC, 'batch', script], capture_output=True, text=True)
    if r.returncode: print(r.stdout[-1500:], r.stderr[-800:]); sys.exit(1)
    r = subprocess.run([MC, 'export', sbs, out_dir, '--size', str(SIZE.get(name, 128)), '--pattern', name], capture_output=True, text=True)
    print(name, r.stdout.strip().replace('\n', ' ')[:300], r.stderr.strip()[:300])
    print('  function nodes:', len(fn['v']['nodes']))


if __name__ == '__main__':
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    for n in (sys.argv[2:] or TEXTURES): build(n, out)
