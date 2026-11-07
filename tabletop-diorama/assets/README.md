# Assets

Everything `demo.html` loads. Total about 2.5 MB. Models are Meshy image-to-3D from ComfyUI concepts,
repainted in TextureCraft; the table and the street are MaterialCraft tiling materials. Words,
signs, cards, the accent ring, the full-size props and the two small figurines stay in code.

## Models (Meshy, 15 credits each, 60 in all)

Concept: ComfyUI `z_image_turbo_int8_convrot` (profile `zimage-int8`), 1024 × 1024, seeds 11–13, one
picked per asset. Prompt = the subject line below + *"Studio product photo of a single hand-carved
and hand-painted wooden toy miniature, like a model-railway scenery piece or a painted tabletop
miniature. Chunky simplified shapes with visible flat knife facets, matte folk-art acrylic paint
over visible wood grain, slightly chipped paint at the edges. Three-quarter view from slightly
above, the whole object centred and fully in frame, filling about 70 percent of the image. Soft
even studio light. Plain flat solid light grey background, completely empty, no table, no ground,
no shadow, no other objects, no text, no letters."*

Meshy: `meshy_image_to_3d`, `ai_model: meshy-t2.5`, smart topology, `texture_model: meshy-n1`.
Each GLB was stripped to positions, UVs and indices (no normals, no Meshy texture) and stored as
base64 in `<name>.glb.js`; the page computes flat normals, so the facets read as knife cuts.

| File | Subject line | Seed | Meshy task | Triangles | Size |
|---|---|---|---|---|---|
| `bakery.glb.js` | a small narrow two-storey bakery shop, cream walls, brick-red gabled roof, short chimney, door left, shop window under a red-and-cream striped awning, blank sign board, green-shuttered upper windows | 11 | `01a1b74f-2fa7-7675-b9f9-1ee69dc00521` (target 6,000) | 5,752 | 248 KB |
| `baker.glb.js` | a carved wooden baker figurine on a round dark base, peg-doll proportions, white toque, blue coat, cream apron, holding a peel with a loaf | 12 | `01a1b74f-3506-76c6-a978-59f958e861af` (target 5,000) | 5,113 | 199 KB |
| `cart.glb.js` | a two-wheeled leaf-green handcart, low side boards, chunky brown disc wheels, pale handles, piled with loaves | 11 | `01a1b751-023d-70c7-ba63-df52c9da915e` (target 5,000) | 5,157 | 216 KB |
| `stall.glb.js` | a wooden market bread stall: counter on four legs, two pale posts, red-and-cream striped awning, loaves and buns | 11 | `01a1b751-972a-7103-abae-e50ad613f9d4` (target 6,000) | 6,116 | 241 KB |

## Painted maps (TextureCraft 0.4.0, 1024 px base colour, JPEG q82)

One script per asset (`texturecraft-cli batch`), about 5 s each: bake every mesh map at 1024;
import Meshy's base colour and set it as the **ID mesh map**; layers from bottom to top:

1. fill `wood-bare` (#E6CFA6), roughness 0.9 — bare wood under everything;
2. Meshy's base colour as an image fill — keeps the small painted details (faces, loaves, windows);
3. one flat fill per part in a palette paint, masked by `mask.add.colorSelection` on the ID map
   (tolerance 0.10–0.15; several Meshy shades per part);
4. `woodGrain` procedural, triplanar, multiplied at 45 % — the carved grain;
5. fill `wood-bare` with a black mask + `edgeWear` generator (level 0.35) — chipped edges;
6. fill #3B2A1C with a black mask + `dirt` generator, 45 % — a wash in the cavities.

Exported with the "glTF PBR Metal Roughness" preset; only the base colour is shipped (the recipe's
material is matte and flat-shaded, no normal map).

| File | Parts repainted (Meshy colour → palette paint) | Size |
|---|---|---|
| `bakery_cream.jpg` | walls → paint-cream, roof and awning → paint-red, shutters → paint-green, trim, door and plinth → paint-brown | 136 KB |
| `bakery_blue.jpg` | walls → paint-blue, roof → paint-brown, shutters → paint-cream | 143 KB |
| `bakery_ochre.jpg` | walls → paint-ochre, roof → paint-red, shutters → paint-green | 128 KB |
| `bakery_green.jpg` | walls → paint-green, roof → paint-brown, shutters → paint-cream | 139 KB |
| `baker_finish.jpg` | none: Meshy's colours kept, layers 4–6 only (the full repaint lost the figure's contrast) | 157 KB |
| `cart_tc.jpg` | bed → paint-green, wheels → paint-brown | 153 KB |
| `cart_red.jpg` | bed → paint-red, wheels → paint-brown | 152 KB |
| `stall_finish.jpg` | none: Meshy's colours kept, layers 4–6 only | 171 KB |

The fifth, unbuilt shop is the same bakery mesh in the page's `wood-bare` material.

## Tiling materials (MaterialCraft 0.2.0, 1024 px, JPEG)

Both are graphs of atomic nodes built by script (`materialcraft-cli batch`); the patterns are
Pixel Processor functions (hash noise, rounded-rectangle distance). The colour maps are near-neutral
light values, so the page multiplies them by the palette's `table` and `wood-bare` and the lighting
schemes keep working. Normal maps downscaled to 512 px.

| File | Graph | Size |
|---|---|---|
| `table_color.jpg`, `table_normal.jpg` | four long boards per tile (smoothstep seams), per-board tone from a hash, grain = 64 × 512 hash cells → Motion Blur → Warp by a blurred low-frequency hash → Levels; Gradient Map to five neutral greys; Normal from seams + 25 % grain. Shown 12 × 6 units per tile | 149 + 98 KB |
| `cobble_color.jpg`, `cobble_normal.jpg` | running-bond setts, 6 × 8 per tile: rounded-rectangle distance per cell, a tilted dome, per-sett tone and size from hashes, 3 % fine knife noise; Gradient Map to neutral greys; Normal at 6×. Shown 1.5 units per tile | 63 + 89 KB |

## Embedded for file://

The images the page draws with WebGL are packed into `images.js` (the catalog script `embed_images.py pack`), because Chrome blocks textures loaded from neighbouring files when the page is opened from the file. To edit one, run `embed_images.py unpack` on this folder, change the file, then `pack` again.
