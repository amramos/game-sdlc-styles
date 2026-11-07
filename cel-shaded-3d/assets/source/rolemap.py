"""Flatten a Meshy base-colour texture to palette-role slots and repack the GLB.
Each texel becomes a slot index (R = slot*16) from nearest reference colour; the demo's shader
looks the slot up in a palette uniform, so the model follows the palette switcher."""
import json, struct, sys, io
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

def run(glb_in, glb_out, refs, size=512, preview=None, drop=None):
    b = open(glb_in, 'rb').read()
    n = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + n])
    bin_off = 20 + n + 8
    binc = b[bin_off:]
    img_bv = j['images'][0]['bufferView']
    bv = j['bufferViews'][img_bv]
    src = Image.open(io.BytesIO(binc[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']])).convert('RGB')
    a = np.asarray(src.resize((size, size), Image.BOX)).astype(float)
    valid = a.sum(2) > 24
    cols = np.array([c for c, _ in refs], float)
    slots = np.array([s for _, s in refs])
    d = ((a[:, :, None, :] - cols[None, None]) ** 2).sum(3)
    lab = slots[d.argmin(2)].astype(np.uint8)
    # mode filter drops speckles; then grow charts into the empty background so seams never sample black
    lab = np.asarray(Image.fromarray(np.where(valid, lab, 255).astype(np.uint8)).filter(ImageFilter.ModeFilter(5)))
    lab = lab.copy(); bad = lab == 255
    idx = ndimage.distance_transform_edt(bad, return_distances=False, return_indices=True)
    lab = lab[idx[0], idx[1]]
    out = Image.fromarray((lab * 16).astype(np.uint8), 'L')
    buf = io.BytesIO(); out.save(buf, 'PNG', optimize=True); png = buf.getvalue()
    if preview:
        pal = np.array([[0,0,0]]*16, np.uint8)
        for c, s in refs: pal[s] = c
        Image.fromarray(pal[lab]).save(preview)
    # optional: drop triangles (drop(P, T) -> bool mask), rewriting the index buffer
    repl = {img_bv: png}
    if drop:
        prim = j['meshes'][0]['primitives'][0]
        def acc(i):
            a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]
            dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a['componentType']]
            nc = {'SCALAR': 1, 'VEC3': 3}[a['type']]
            return a, np.frombuffer(binc, dt, a['count'] * nc, v.get('byteOffset', 0) + a.get('byteOffset', 0))
        _, P = acc(prim['attributes']['POSITION']); P = P.reshape(-1, 3)
        ia, I = acc(prim['indices']); T = I.reshape(-1, 3)
        keep = T[~drop(P, T)].astype(I.dtype)
        print('dropped', len(T) - len(keep), 'of', len(T), 'triangles')
        ia['count'] = keep.size; ia['byteOffset'] = 0
        repl[ia['bufferView']] = keep.tobytes()
    parts = []; off = 0
    for i, v in enumerate(j['bufferViews']):
        data = repl[i] if i in repl else binc[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
        pad = (-len(data)) % 4
        v['byteOffset'] = off; v['byteLength'] = len(data)
        v.pop('byteStride', None) if i in repl and i != img_bv else None
        parts.append(data + b'\0' * pad); off += len(data) + pad
    newbin = b''.join(parts)
    j['buffers'][0]['byteLength'] = len(newbin)
    js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((-len(js)) % 4)
    total = 12 + 8 + len(js) + 8 + len(newbin)
    with open(glb_out, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total))
        f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack('<II', len(newbin), 0x004E4942)); f.write(newbin)
    print(glb_out, total, 'bytes; slots used', sorted(set(np.unique(lab).tolist())))
