"""Split the windmill's sail assembly (sails, spars, hub) from its tower so the demo can turn it,
drop the strip of wood-textured membrane image-to-3D stretched along one spar, and point every
sail-canvas triangle at a canvas texel (no wood smears on the cloth).
usage: python millsplit.py windmill.glb.js   (rewrites it in place; run once, after rolemap/millcut)"""
import base64, json, re, struct, sys, io
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

CANVAS = 5                               # slot index of the sail cloth (see WINDMILL_SLOTS in demo.html)
HUB = np.array([0.0, 0.132])             # hub centre, model x/y


def load(path):
    s = open(path).read()
    b = base64.b64decode(re.search(r"MODELS\['windmill'\]\s*=\s*'([^']+)'", s).group(1))
    n = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + n])
    binc = b[20 + n + 8:]

    def bv(i):
        v = j['bufferViews'][i]
        return binc[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]

    prim = j['meshes'][0]['primitives'][0]
    acc = j['accessors']

    def get(a, dt, k):
        return np.frombuffer(bv(acc[a]['bufferView']), dt)[:acc[a]['count'] * k].reshape(-1, k).copy()

    T = get(prim['indices'], np.uint32, 3).astype(np.int64)
    P = get(prim['attributes']['POSITION'], np.float32, 3)
    UV = get(prim['attributes']['TEXCOORD_0'], np.float32, 2)
    N = get(prim['attributes']['NORMAL'], np.float32, 3)
    return T, P, UV, N, bv(j['images'][0]['bufferView'])


def components(T, P):
    _, inv = np.unique(np.round(P, 5), axis=0, return_inverse=True)
    inv = inv.ravel()
    A = coo_matrix((np.ones(T.size), (np.repeat(np.arange(len(T)), 3), inv[T].ravel())),
                   shape=(len(T), inv.max() + 1)).tocsr()
    return connected_components(A @ A.T, directed=False)[1]


def main(path):
    T, P, UV, N, png = load(path)
    tex = np.asarray(Image.open(io.BytesIO(png))) // 16
    lab = components(T, P)
    V = P[T]
    c = V.mean(1)
    nc = lab.max() + 1
    zmin = np.asarray(ndimage.minimum(V[:, :, 2].min(1), lab, range(nc)))
    ymin = np.asarray(ndimage.minimum(V[:, :, 1].min(1), lab, range(nc)))
    # sail assembly: every part in the sail plane in front of the tower, except the door below it,
    # plus the hub and axle (components that sit within 0.07 of the hub centre and reach the sail plane)
    rmax = np.asarray(ndimage.maximum(np.hypot(V[:, :, 0] - HUB[0], V[:, :, 1] - HUB[1]).max(1), lab, range(nc)))
    zmax = np.asarray(ndimage.maximum(V[:, :, 2].max(1), lab, range(nc)))
    hubks = np.where((rmax < 0.07) & (zmax > 0.15))[0]
    hubk = hubks[np.argmax(np.bincount(lab)[hubks])]
    sailk = set(np.where((zmin > 0.165) & (ymin > -0.3))[0].tolist()) | set(hubks.tolist())
    sail = np.isin(lab, list(sailk))

    # membrane along a spar: triangles of a long thin component with a corner far off its axis
    keep = np.ones(len(T), bool)
    for k in sailk:
        m = lab == k
        pts = V[m].reshape(-1, 3)[:, :2]
        ctr = pts.mean(0)
        _, sv, vt = np.linalg.svd(pts - ctr, full_matrices=False)
        if sv[0] / np.sqrt(len(pts)) < 0.15:                  # not a long spar
            continue
        off = np.abs((V[m][:, :, :2] - ctr) @ vt[1])
        bad = off.max(1) > 0.02
        if bad.any():
            print('component', k, 'membrane triangles dropped:', int(bad.sum()))
            keep[np.where(m)[0][bad]] = False

    # canvas: components whose texels are mostly cloth -> every vertex samples deep inside a cloth chart
    cuv = UV[T].mean(1)
    tslot = tex[np.clip((cuv[:, 1] * 512).astype(int), 0, 511), np.clip((cuv[:, 0] * 512).astype(int), 0, 511)]
    dist = ndimage.distance_transform_edt(tex == CANVAS)
    y, x = np.unravel_index(dist.argmax(), dist.shape)
    canvas_uv = np.array([(x + 0.5) / 512, (y + 0.5) / 512], np.float32)
    for k in sailk:
        m = lab == k
        if (tslot[m] == CANVAS).mean() > 0.6:
            UV[np.unique(T[m])] = canvas_uv
            print('component', k, 'set to cloth,', int(m.sum()), 'triangles')

    # pivot: hub centre; spin axis: the sail plane's normal (stored in the node's extras)
    sp = P[np.unique(T[sail & keep])]
    axis = np.linalg.svd(sp - sp.mean(0), full_matrices=False)[2][2]
    axis *= np.sign(axis[2])
    hv = P[np.unique(T[lab == hubk])]
    pivot = np.array([HUB[0], HUB[1], hv[:, 2].mean()])
    print('pivot', pivot.round(4), 'axis', axis.round(4))
    parts = []
    for name, msk, origin in [('tower', ~sail & keep, np.zeros(3)), ('sails', sail & keep, pivot)]:
        vid, tt = np.unique(T[msk], return_inverse=True)
        parts.append((name, (P[vid] - origin).astype(np.float32), UV[vid], N[vid],
                      tt.reshape(-1, 3).astype(np.uint32), origin))
    write(path, parts, png, axis)


def write(path, parts, png, axis):
    blobs, views, accs, meshes, nodes = [], [], [], [], []

    def add(data, **acc):
        off = sum(len(b) for b in blobs)
        data = data.tobytes() if hasattr(data, 'tobytes') else data
        blobs.append(data + b'\0' * ((-len(data)) % 4))
        views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(data)})
        if acc:
            accs.append(dict(bufferView=len(views) - 1, **acc))
            return len(accs) - 1
        return len(views) - 1

    for name, Pp, U, Nn, Tt, origin in parts:
        ia = add(Tt.ravel(), componentType=5125, type='SCALAR', count=int(Tt.size))
        pa = add(Pp, componentType=5126, type='VEC3', count=len(Pp), min=Pp.min(0).tolist(), max=Pp.max(0).tolist())
        ua = add(U.astype(np.float32), componentType=5126, type='VEC2', count=len(U))
        na = add(Nn.astype(np.float32), componentType=5126, type='VEC3', count=len(Nn))
        meshes.append({'name': name, 'primitives': [{'attributes': {'POSITION': pa, 'TEXCOORD_0': ua, 'NORMAL': na},
                                                     'indices': ia, 'material': 0}]})
        node = {'name': name, 'mesh': len(meshes) - 1, 'translation': origin.tolist()}
        if name == 'sails':
            node['extras'] = {'spinAxis': axis.tolist()}
        nodes.append(node)
        print(name, len(Tt), 'triangles')
    iv = add(png)
    j = {'asset': {'version': '2.0', 'generator': 'millsplit.py'}, 'scene': 0,
         'scenes': [{'nodes': list(range(len(nodes)))}], 'nodes': nodes, 'meshes': meshes,
         'accessors': accs, 'bufferViews': views, 'buffers': [{'byteLength': sum(len(b) for b in blobs)}],
         'images': [{'bufferView': iv, 'mimeType': 'image/png'}], 'textures': [{'source': 0}],
         'materials': [{'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0.0,
                                                 'roughnessFactor': 1.0}, 'doubleSided': True}]}
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * ((-len(js)) % 4)
    binc = b''.join(blobs)
    glb = (struct.pack('<III', 0x46546C67, 2, 28 + len(js) + len(binc)) + struct.pack('<II', len(js), 0x4E4F534A)
           + js + struct.pack('<II', len(binc), 0x004E4942) + binc)
    with open(path, 'w') as f:
        f.write("window.MODELS = window.MODELS || {};\nMODELS['windmill'] = '" + base64.b64encode(glb).decode() + "';\n")
    print(path, len(glb), 'bytes')


if __name__ == '__main__':
    main(sys.argv[1])
