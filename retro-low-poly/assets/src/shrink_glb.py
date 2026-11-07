"""Shrink a Meshy GLB for the retro look: keep the mesh, replace every image with a small,
5-bit-per-channel PNG (box-filtered down, then point-sampled in the demo), drop extra maps, and write
the GLB plus a .glb.js wrapper (window.MODELS[name] = base64) that the demo loads from file://.

usage: python -I shrink_glb.py <in.glb> <out.glb> <name> [texture px, default 128] [skin hex]
"""
import base64, io, json, struct, sys
from PIL import Image


def read_glb(path):
    data = open(path, "rb").read()
    magic, ver, length = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF"
    off, js, binc = 12, None, b""
    while off < length:
        clen, ctype = struct.unpack_from("<I4s", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == b"JSON": js = json.loads(chunk)
        elif ctype == b"BIN\x00": binc = chunk
        off += 8 + clen
    return js, binc


def write_glb(js, binc, path):
    j = json.dumps(js, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    binc += b"\x00" * (-len(binc) % 4)
    out = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(j) + 8 + len(binc))
    out += struct.pack("<I4s", len(j), b"JSON") + j + struct.pack("<I4s", len(binc), b"BIN\x00") + binc
    open(path, "wb").write(out)
    return out


def accessor(js, binc, i):
    import numpy as np
    a = js["accessors"][i]; bv = js["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[a["type"]]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a["componentType"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(binc, dt, a["count"] * n, off).reshape(-1, n) if n > 1 else np.frombuffer(binc, dt, a["count"], off)


def uv_mask(js, binc, w, h):
    """Where the UV islands are: rasterise every triangle in texture space (Meshy leaves black between them)."""
    from PIL import ImageDraw
    m = Image.new("L", (w, h), 0); d = ImageDraw.Draw(m)
    for mesh in js["meshes"]:
        for p in mesh["primitives"]:
            uv = accessor(js, binc, p["attributes"]["TEXCOORD_0"]); idx = accessor(js, binc, p["indices"])
            for t in idx.reshape(-1, 3):
                d.polygon([(float(uv[k][0]) * w, float(uv[k][1]) * h) for k in t], fill=255)
    return m


def dilate(im, mask, steps=48):
    """Grow each island's colours outward into the empty texels, so shrinking never bleeds black in."""
    import numpy as np
    c = np.asarray(im, np.float32); m = np.asarray(mask) > 0
    for _ in range(steps):
        acc = np.zeros_like(c); cnt = np.zeros(m.shape, np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            mm = np.roll(m, (dy, dx), (0, 1)); cc = np.roll(c, (dy, dx), (0, 1))
            acc += cc * mm[..., None]; cnt += mm
        grow = (~m) & (cnt > 0)
        c[grow] = acc[grow] / cnt[grow][:, None]; m = m | grow
        if m.all(): break
    return Image.fromarray(c.clip(0, 255).astype("uint8"))


SKIN = None   # optional palette skin hex: the generator's saturated orange skin is pulled onto it


def to_skin(im, hexc, amount=0.75):
    """Pull skin-hued texels (orange-red, saturated) onto the palette's skin colour, keeping their shading."""
    import numpy as np, colorsys
    a = np.asarray(im, np.float32) / 255
    mx, mn = a.max(2), a.min(2); s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    hue = np.where(mx == r, ((g - b) / np.maximum(mx - mn, 1e-6)) % 6, 0) * 60
    sel = (mx == r) & (hue < 40) & (s > 0.3) & (mx > 0.25)
    t = np.array([int(hexc[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255
    shade = (mx / t.max())[..., None]
    out = np.where(sel[..., None], a * (1 - amount) + np.clip(t * shade, 0, 1) * amount, a)
    return Image.fromarray((out * 255).round().astype("uint8"))


def main(src, dst, name, px=128):
    js, binc = read_glb(src)
    # keep only base colour on every material
    for m in js.get("materials", []):
        pbr = m.setdefault("pbrMetallicRoughness", {})
        pbr.pop("metallicRoughnessTexture", None)
        pbr["metallicFactor"], pbr["roughnessFactor"] = 0.0, 1.0
        for k in ("normalTexture", "occlusionTexture", "emissiveTexture"):
            m.pop(k, None)
    used = {m["pbrMetallicRoughness"]["baseColorTexture"]["index"]
            for m in js.get("materials", []) if "baseColorTexture" in m.get("pbrMetallicRoughness", {})}
    used_img = {js["textures"][t]["source"] for t in used}
    new_imgs = {}
    for i, img in enumerate(js.get("images", [])):
        if i not in used_img: continue
        bv = js["bufferViews"][img["bufferView"]]
        raw = binc[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
        im = dilate(Image.open(io.BytesIO(raw)).convert("RGB"), uv_mask(js, binc, *Image.open(io.BytesIO(raw)).size))
        im = im.resize((px, px), Image.BOX)
        if SKIN: im = to_skin(im, SKIN)
        im = im.point(lambda v: v >> 3 << 3)
        im.save(dst.replace(".glb", f"_tex{i}.png"))
        b = io.BytesIO(); im.save(b, "PNG", optimize=True); new_imgs[i] = b.getvalue()
    # rebuild the binary chunk: every buffer view except dropped images, images replaced
    keep_bv = {}
    image_bv = {img["bufferView"]: i for i, img in enumerate(js.get("images", []))}
    newbin = bytearray()
    new_views = []
    for vi, bv in enumerate(js["bufferViews"]):
        if vi in image_bv and image_bv[vi] not in new_imgs: continue
        if vi in image_bv: chunk = new_imgs[image_bv[vi]]
        else: chunk = binc[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
        newbin += b"\x00" * (-len(newbin) % 4)
        nb = dict(bv); nb["byteOffset"] = len(newbin); nb["byteLength"] = len(chunk); nb["buffer"] = 0
        newbin += chunk
        keep_bv[vi] = len(new_views); new_views.append(nb)
    js["bufferViews"] = new_views
    for acc in js.get("accessors", []):
        if "bufferView" in acc: acc["bufferView"] = keep_bv[acc["bufferView"]]
    # images and textures: keep the used ones, renumbered
    img_map, imgs = {}, []
    for i, img in enumerate(js.get("images", [])):
        if i in new_imgs:
            img = dict(img); img["bufferView"] = keep_bv[img["bufferView"]]; img["mimeType"] = "image/png"
            img_map[i] = len(imgs); imgs.append(img)
    tex_map, texs = {}, []
    for t, tex in enumerate(js.get("textures", [])):
        if t in used:
            tex = dict(tex); tex["source"] = img_map[tex["source"]]; tex.pop("sampler", None)
            tex_map[t] = len(texs); texs.append(tex)
    js["images"], js["textures"] = imgs, texs
    js.pop("samplers", None)
    for m in js.get("materials", []):
        bt = m["pbrMetallicRoughness"].get("baseColorTexture")
        if bt: bt["index"] = tex_map[bt["index"]]
    js["buffers"] = [{"byteLength": len(newbin) + (-len(newbin) % 4)}]
    out = write_glb(js, bytes(newbin), dst)
    with open(dst + ".js", "w") as fh:
        fh.write(f"window.MODELS = window.MODELS || {{}};\nMODELS['{name}'] = '{base64.b64encode(out).decode()}';\n")
    tris = sum(js["accessors"][p["indices"]]["count"] // 3 for m in js["meshes"] for p in m["primitives"] if "indices" in p)
    print(f"{dst}: {len(out)} bytes, {tris} triangles, textures {px}px")


if __name__ == "__main__":
    SKIN = sys.argv[5] if len(sys.argv) > 5 else None
    main(sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]) if len(sys.argv) > 4 else 128)
