"""Tiny expression builder for MaterialCraft pixel-processor function graphs.

Each texture is one pixel processor whose function computes the colour from $pos (0..1, tiling),
using only palette colours as constants and a position hash for per-tile variation. The graph is
written with materialcraft-cli `batch`, cooked, and exported at its own size (64 or 128 px), so the
texels come straight out of MaterialCraft with no resampling.
"""
import json


class F:
    def __init__(self):
        self.nodes = []

    def _n(self, op, inputs=(), value=None, tc=0):
        nid = len(self.nodes) + 1
        node = {"id": nid, "inputs": list(inputs), "op": op, "pos": [nid * 140.0, 0.0], "type_code": tc}
        if value is not None:
            node["value"] = value
        self.nodes.append(node)
        return nid

    # leaves
    def c1(self, v): return self._n("const_float1", value={"t": "float", "v": float(v)})
    def c2(self, a, b): return self._n("const_float2", value={"t": "float2", "v": [float(a), float(b)]})
    def c4(self, r, g, b, a=1.0): return self._n("const_float4", value={"t": "float4", "v": [r, g, b, a]})
    def hexc(self, h, k=1.0):
        # colour constants are linear inside the graph and exported as sRGB: convert the palette hex
        lin = lambda s: s / 12.92 if s <= 0.04045 else ((s + 0.055) / 1.055) ** 2.4
        r, g, b = (lin(min(1.0, int(h[i:i + 2], 16) / 255 * k)) for i in (1, 3, 5))
        return self.c4(r, g, b, 1.0)
    def mix(self, a, b, t): return self.add(a, self.scale(self.sub(b, a), t))
    def scale(self, v, s): return self._n("mulscalar", [v, s])
    def pos(self): return self._n("get_float2", value={"t": "text", "v": "$pos"})
    # structure
    def sw(self, v, i): return self._n("swizzle1", [v], value={"t": "int", "v": i})
    def v2(self, a, b): return self._n("vector2", [a, b])
    # arithmetic
    def add(self, a, b): return self._n("add", [a, b])
    def sub(self, a, b): return self._n("sub", [a, b])
    def mul(self, a, b): return self._n("mul", [a, b])
    def div(self, a, b): return self._n("div", [a, b])
    def mod(self, a, b): return self._n("mod", [a, b])
    def floor(self, a): return self._n("floor", [a])
    def abs(self, a): return self._n("abs", [a])
    def sin(self, a): return self._n("sin", [a])
    def dot(self, a, b): return self._n("dot", [a, b])
    def lerp(self, a, b, t): return self._n("lerp", [a, b, t])
    def lt(self, a, b): return self._n("lr", [a, b])
    def gt(self, a, b): return self._n("gt", [a, b])
    def ifelse(self, c, a, b): return self._n("ifelse", [c, a, b])
    def fract(self, a): return self.sub(a, self.floor(a))
    def hash(self, v2, salt=0.0):
        """0..1 pseudo-random from a float2 (classic sin-dot hash)."""
        d = self.dot(v2, self.c2(12.9898 + salt, 78.233 + salt * 0.5))
        return self.fract(self.mul(self.sin(d), self.c1(43758.5453)))

    def graph(self, out):
        return {"nodes": self.nodes, "output": out}


def batch(sbs_in, sbs_out, fn, pp_id_hint=None):
    """Steps that add one colour pixel processor and wire it to the basecolor output (node 2)."""
    return {
        "open": sbs_in,
        "steps": [
            {"id": "graph.node.add", "params": {"def": "pixel_processor", "at": [0, -200],
                                                "params": {"color_mode": True}}},
            {"id": "graph.function.set", "params": {"function": fn,
                                                    "target": {"kind": "parameter", "node": 13,
                                                               "parameter": "function"}}},
            {"id": "graph.connect", "params": {"from": 13, "to": 2, "toPort": "input"}},
            {"id": "graph.cook", "params": {"full": True}},
        ],
        "save": sbs_out,
    }


if __name__ == "__main__":
    import sys
    print(json.dumps(batch(sys.argv[1], sys.argv[2], {"nodes": [], "output": 0})))
