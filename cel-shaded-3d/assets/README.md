# Assets

The demo's courier and windmill are generated models; everything else in the scene is built from
primitives in `demo.html`. Every word, number, panel and chip is live HTML.

| File | What | Made with | Size |
|---|---|---|---|
| `courier.glb.js` | the courier, static A-pose, 8,289 triangles, 512 px slot map | ComfyUI concept → Meshy image-to-3D → slot map | 445 KB |
| `windmill.glb.js` | the windmill: node `tower` (2,826 triangles) and node `sails` (1,756: sails, spars, hub; origin on the hub, `extras.spinAxis`), 512 px slot map | ComfyUI concept → Meshy image-to-3D → membrane cut → slot map → split | 285 KB |
| `source/courier-concept.jpg`, `source/windmill-concept.jpg` | the image-to-3D inputs, downscaled | ComfyUI | 30 KB, 23 KB |
| `source/*-prompt.txt` | the exact prompts | — | 1 KB each |
| `source/rolemap.py`, `source/millcut.py`, `source/millsplit.py` | the texture flattening and the windmill fixes | Python (numpy, Pillow, SciPy) | 12 KB |

Each `.glb.js` holds `MODELS['<name>'] = '<base64 GLB>'`; the demo decodes it and calls
`GLTFLoader.parse`.

## Concepts (ComfyUI 0.37.0, profile `zimage-int8`, default sampler settings)

- **Courier:** txt2img 1024×1536, seeds 11–14; **12 kept** (three-quarter view, scarf tail
  readable, about 6.5 heads tall). Prompt in `source/courier-prompt.txt`: flat unshaded colours,
  no outlines, plain white background, so the engine draws bands and ink itself.
- **Windmill:** round 1 (seeds 21–24) drew lattice sails, which image-to-3D turns into noisy
  geometry; round 2 asked for solid canvas sails on one spar (seeds 25–28); **26 kept**.

## Meshy image-to-3D

`ai_model meshy-t2.5`, `model_type smart-topology`, `texture_model meshy-n1`, GLB only.

| Model | Task id | target_polycount | Credits |
|---|---|---|---|
| courier | `01a1b74f-964b-7410-b0aa-e5f4dce61815` | 8,000 | 15 |
| windmill | `01a1b74f-9c20-71a0-95a1-215e619f5371` | 5,000 | 15 |

## Flattening the texture (`source/rolemap.py`)

Meshy's 2048 px base colour is already fairly flat, but it is a colour, not a palette role, so it
would ignore the palette switcher and carry soft baked shading. Instead:

1. Box-downscale to 512 px; each texel takes the nearest of a short list of reference colours
   (picked from a k-means of the texture), and each reference belongs to a **slot**.
2. 5×5 mode filter (drops speckles), then grow every chart into the empty background so seams
   never sample black.
3. Store `slot × 16` in a greyscale PNG and put it back into the GLB in place of the texture.

In the demo the material samples it with nearest filtering and no colour space, looks the slot up
in a 16-entry uniform filled from the palette (`[role, multiplier]`; a multiplier below 1 is the
material's one darker painted tone), and lets the toon ramp make the bands. Slots: courier = skin,
hair, cloth, cloth ×0.62, scarf (`base-roof`), wood, wood ×0.55, `cloud`, `ink`; windmill = rock,
rock ×0.82, roof, wood, wood ×0.7, `cloud`, `cloud` ×0.78.

## Windmill fix (`source/millcut.py`)

Image-to-3D stretched a membrane of large triangles between the four sail tips, so the sails read
as one square board. Triangles in the sail plane whose corners sit on two neighbouring arms are
dropped (38 of 4,622); spars join opposite arms and stay.

## Windmill split (`source/millsplit.py`)

Run once on `windmill.glb.js`, after the two steps above; it rewrites the file in place.

1. **Sail assembly:** connected parts (by welded position) that lie wholly in the sail plane in
   front of the tower, except the door below it, plus the hub and axle (parts within 0.07 of the
   hub centre that reach the sail plane). They go into their own node, `sails`, whose origin is the
   hub; the sail plane's normal (from a fit of its vertices, about +z) is stored as
   `extras.spinAxis`. The demo turns that node about the axis at 0.2 turns per second; in
   `?frame` mode it stays at angle 0.
2. **Spar membrane:** one spar carried a strip of large wood triangles reaching out to a sail tip
   (the brown smear across two sails). Triangles of a long thin part with a corner more than 0.02
   off its axis are dropped (2).
3. **Cloth:** parts whose texels are mostly the cloth slot (four sails, 196 triangles) get every
   UV moved to the texel deepest inside a cloth chart, so no wood texel bleeds across them. The
   toon ramp still bands them.

No new Meshy calls.

Everything the page loads is embedded: both models are base64 in their `.glb.js`, and their
textures travel inside the GLB, so the page works when opened straight from `file://`.

Total folder size about 0.8 MB.
