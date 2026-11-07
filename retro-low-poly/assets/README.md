# Assets

Everything `demo.html` loads. It runs from `file://`, so images come in as data URIs
(`textures.js`) and the model as a base64 GLB (`cook.glb.js`); the PNG and GLB beside them are the
same data, kept for reuse. Every texture is point-sampled (nearest, no mipmaps) and cut to 5 bits per
channel, like the rest of the scene.

| File | Size | What it is | How it was made |
|---|---|---|---|
| `floor.png` | 64×64, 1 KB | checkerboard linoleum, 4×4 tiles, tiled every 1 m | MaterialCraft, `src/make_textures.py` (`floor_tex`) |
| `brick.png` | 64×64, 1.4 KB | running-bond brick, 16×8-texel bricks, tiled every 0.6 m | MaterialCraft, `src/make_textures.py` (`brick_tex`) |
| `formica.png` | 64×64, 2 KB | speckled counter laminate, tiled every 0.8 m | MaterialCraft, `src/make_textures.py` (`formica_tex`) |
| `textures.js` | 6 KB | the three PNGs as data URIs (`window.TEXTURES`) | written from the PNGs |
| `cook.glb` | 160 KB | the cook: 2,647 triangles, one 256 px base-colour texture | ComfyUI concept → Meshy image-to-3D → `src/shrink_glb.py` |
| `cook.glb.js` | 214 KB | `cook.glb` as base64 (`window.MODELS.cook`) | written by `src/shrink_glb.py` |
| `cook_tex0.png` | 256×256, 42 KB | the cook's texture as it is inside `cook.glb` | written by `src/shrink_glb.py` |

## Textures (MaterialCraft)

`python src/make_textures.py` makes one `pbr` package per material at 64 px
(`materialcraft-cli new pbr`), adds one colour pixel processor whose function graph draws the
pattern from `$pos`, wires it to basecolor, cooks and exports at 64 px, then cuts the result to
5 bits per channel. All colours are palette roles from `example-palette.gpl` (`material-floor-*`,
`material-brick`, `material-chrome` for mortar, `material-formica`, `material-wall`,
`material-vinyl`, `material-wood`) times a shade factor; per-tile variation comes from a position
hash, so each texture tiles exactly. The packages are kept in `src/*.sbs`; `src/mcfun.py` builds
the function graphs.

- **Floor:** tiles vary 0.93–1.03 in value; a one-texel bevel (light top-left, dark bottom-right);
  sparse scuffs.
- **Brick:** each brick its own shade (0.80–1.12), one in seven a darker burnt brick; lit top row,
  shaded bottom rows; one-texel grey mortar; a few pits.
- **Counter laminate:** flecks two texels wide, one shade darker, a few teal and warm ones mixed at
  low contrast, and a faint grain. No thin bright marks: at grazing angles, high-contrast one-texel
  marks stretch into long coloured streaks.

## The cook (ComfyUI + Meshy)

1. **Concept:** ComfyUI, profile `zimage-int8`, 768×1024, seed 303 of 101/202/303/404
   (`src/cook_concept_seed303.jpg`, a reduced copy). Prompt: a full-body roadside-diner
   short-order cook with realistic adult proportions (head a seventh of his height), white
   short-sleeved cook's shirt and apron, dark trousers, cook's cap, a spatula in his right hand,
   standing relaxed in a three-quarter view, flat even studio light, on a plain flat light-grey
   background with no ground or shadow, one figure only.
2. **Model:** Meshy image-to-3D, `ai_model meshy-t2.5` (smart topology), `texture_model meshy-n1`,
   `target_polycount 2500`, GLB only. Task `01a1b74e-bba3-77fc-bdd7-cca3257bf0b2`, 15 credits.
   Result: 2,647 triangles, a 2048 px base-colour atlas.
3. **Shrink:** `python -I src/shrink_glb.py <meshy.glb> cook.glb cook 256 "#C68462"` keeps the mesh,
   drops every map but base colour, grows each UV island's colours outward into the empty texels
   (otherwise shrinking bleeds black into the seams), box-filters the atlas to 256 px, pulls
   saturated skin texels toward `material-skin`, cuts to 5 bits per channel, and writes the GLB
   and its `.glb.js`.
4. **In the demo:** `GLTFLoader.parse`, every mesh gets the scene's own shader (vertex snap, affine
   UVs, per-vertex light, fog), the texture is sampled raw (`colorSpace = NoColorSpace`; an sRGB
   decode darkens and over-saturates it, turning skin red) and nearest-filtered; scaled to 1.95 m
   to the top of the cap, feet on the floor.
