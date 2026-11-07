# Assets

Everything `demo.html` loads besides three.js. Total about 30 KB.

| File | Size | Made with |
|---|---|---|
| `sprites/vendor.png`, `shopper.png`, `elder.png`, `kid.png` | 0.5–0.7 KB each, 32 × 48 | ComfyUI, then PixelForge (below) |
| `signs/fig.png`, `herb.png`, `seed.png` | 0.6–0.7 KB each, 48 × 24 | ComfyUI, then PixelForge (below) |
| `sprites.js` | 6.5 KB | the sprite and sign PNGs above as data URLs (`window.SPRITE_PNG`, `window.SIGN_PNG`), so the page can read their pixels from `file://` and repaint them in another palette |
| `textures/floor-tiles.png`, `roof-tiles.png`, `wood-planks.png` | 0.9–1.5 KB, 128 × 128 | MaterialCraft (below) |
| `textures/plaster.png` | 2 KB, 256 × 256 | MaterialCraft (below) |
| `cast-palette.gpl` | 1 KB | the sprite roles of `example-palette.gpl` and the set roles the signs use, each with its shade (× 0.72) |
| `pixelforge.toml` | 1 KB | PixelForge config: canvases `sprite` (32 × 48, bottom anchor) and `sign` (48 × 24); the set colours are reserved to `signs/**` and the cast's colours to `sprites/**` |
| `tools/*.py` | — | the scripts below, kept so every file can be remade |

`python -m pixelforge lint sprites/*.png signs/*.png` (run in this folder) passes: 0 errors.

## Sprites (ComfyUI + PixelForge)

ComfyUI 0.37, profile `zimage-int8` (Z-Image Turbo int8), txt2img 768 × 1152, seeds 11, 22, 33 per
person; picked: vendor 33, shopper 11, elder 11, kid 33. One person per generation on magenta.

Prompt core (each prompt adds one line for the person):

> Pixel art game sprite of one single person, full body, standing still, three-quarter view facing
> slightly left, whole figure centred, head near the top and feet near the bottom of the frame, the
> figure fills 85 percent of the frame height. Chunky 16-bit JRPG overworld sprite: large blocky
> pixels, head about one quarter of the body height, bold single dark outline around the whole
> figure, flat colours with exactly two tones per material (base and one shade), no gradients, no
> anti-aliasing, no dithering. Mediterranean hill-town market at morning. Plain flat solid pure
> magenta background, completely empty, no ground, no shadow, no text.

- vendor: a young woman fig seller, a bright royal blue headscarf, a short-sleeved tomato red blouse,
  a long cream white apron over a red skirt, brown sandals, warm tan skin, hands folded in front.
- shopper: a woman flower buyer in her thirties, dark brown hair in a low bun, a royal blue
  long-sleeved dress, a tomato red sash, holds exactly one small wicker basket in her right hand.
- elder: an old man with a short grey-brown beard, a wide cream white cloth sun hat, a long tomato
  red robe with a brown rope belt, one long wooden walking staff upright in his left hand.
- kid: a small boy about eight, messy dark brown hair, a loose cream white shirt, tomato red
  knee-length shorts, brown sandals, arms out a little as if ready to run.

Cleanup, in order:
1. `comfyui-art/scripts/pixel_post.py key` (flood-fill key; check images looked at).
2. `tools/frame.py`: drop stray islands, crop to the silhouette and scale so every figure is a set
   number of sprite pixels tall (elder 46, vendor 44, shopper 43, kid 34) with feet on row 46, at
   24 source pixels per sprite pixel. PixelForge's own fit would scale each figure to the canvas
   and make the child as tall as the adults.
3. `python -m pixelforge clean <framed> --canvas sprite --no-trim` (key → snap → mode-downscale).
4. `tools/fix.py`: meaning fixes (the basket from red to straw `material-cloth2`, the boy's hands
   from red to skin) and a closed 1-pixel outline outside the silhouette, which mode-downscaling
   breaks.

## Stall signs (ComfyUI + PixelForge)

Same profile, txt2img 1024 × 640, seeds 5 and 6; seed 5 kept for all three.

> Pixel art game prop, one small flat rectangular wooden shop sign board seen straight from the
> front, filling the frame from edge to edge, wide landscape shape, a thick dark brown wooden frame,
> painted plank surface in warm brown, chunky large pixels, bold dark outline, flat colours with two
> tones each, no gradients, no anti-aliasing, no letters, no text, no words. Plain flat solid pure
> magenta background, completely empty, no shadow.

plus one line: three ripe purple-brown figs with a green leaf / a bundle of green herb sprigs tied
with string, beside a small terracotta pot / a cloth seed sack spilling golden seeds, with a
sprouting green seedling.

Cleanup: `pixel_post.py key`; crop to the largest island; `tools/sign_prep.py` (board browns
darkened 0.8 so they snap to wood, not roof; purple fruit turned red-brown); `pixelforge clean
--canvas sign --no-trim -o signs/<name>.png`. The output must be written under `signs/`, or the
reserved set colours are not reachable and leaves snap to straw.

## Textures (MaterialCraft)

MaterialCraft 0.2.0 CLI (`materialcraft-cli`). Its node library has only atomic nodes (no brick,
tile or noise generators), so each map is one Pixel Processor whose per-pixel function is written
in `tools/materialcraft_values.py` and compiled to MaterialCraft's function-graph JSON (178, 72,
274 and 101 function nodes). Each script does `new empty <name>.sbs --size 128|256`,
`graph.node.add pixel_processor` (grey output), `graph.node.param function`, an output node,
`graph.cook`, `export --size 128|256`. Run: `python tools/materialcraft_values.py <outdir>`.

- **floor-tiles:** 8 × 8 square tiles (16 texels), a shade per tile from a cell hash, broad
  tileable value-noise wear, 1-texel grout, a lit lip under each joint, rare specks.
- **roof-tiles:** staggered barrel tiles, 8 per row, rounded by a sine across each tile, a dark lip
  under each row.
- **plaster:** two octaves of tileable value noise; where the noise is lowest, bricks show through;
  faint vertical weathering streaks.
- **wood-planks:** 8 planks, one butt joint per plank at a hashed position, wavy grain from two
  sines, a 1-texel gap and a lit edge.

The graph posterises to four levels; a last step (inline Python) maps them to 0.60, 0.76, 0.89 and
1.00 and saves 8-bit grey. In the page each map multiplies its role colour (`ground`,
`material-plaster`, `material-stone`, `material-roof`, `material-wood`), so surfaces keep their
palette role in every palette; UVs are in world units (`worldUV`, `roofCone`), magnified with
nearest sampling and minified with mipmaps.

TextureCraft was tried and not used: see `frames/README.md`.

## Embedded for file://

The images the page draws with WebGL are packed into `images.js` (the catalog script `embed_images.py pack`), because Chrome blocks textures loaded from neighbouring files when the page is opened from the file. To edit one, run `embed_images.py unpack` on this folder, change the file, then `pack` again.
