# Frames

Captured from `demo.html` in this folder, which builds every frame deterministically (fixed camera,
fixed time) in the bright matinee lighting. The setting is original: a fairy-tale birch wood, with a
wolf, a girl with a basket and a woodcutter's cart.

**Every printed piece is its own generated image** (`../assets/README.md` lists the prompts and
seeds): the proscenium, the valance, the two side drapes, the back cloth, each of the three ground
rows, the birch and oak wings, the girl, the wolf, the cart and the floor planks. Each was generated
alone on flat magenta, keyed, cropped and given a paper border; the page stands them in a real 3D
box as cut-out planes, adds the dark card edge behind each, and lights them, so their shadows fall
on the layers behind. Only the interface is drawn by the page: live text on paper slips, pinned,
flown on wires or tagged to figures, with printed glyphs and pips.

**Capture:** viewport exactly 1280×720, device scale 1. In frame mode the page pins a fixed
1280×720 canvas at the top-left corner, whatever the window size. Open the URL, wait until
`document.title === 'ready'` (every image loaded, then about 10 rendered frames), then screenshot the
1280×720 region at the top-left. Saved as JPEG at quality 85. The page needs network access to load
three.js 0.160.0 from jsdelivr, and, from `file://`, a browser allowed to read local files for the
textures (headless Chrome: `--allow-file-access-from-files`).

| File | URL | Shows |
|---|---|---|
| `key-scene.jpg` | `demo.html?frame=key-scene` | the whole stage from the audience: generated proscenium, valance and drapes, the back cloth, three ground rows, birch and oak wings, the girl and the wolf on slides, the cart, accent markers on wires over the wolf and the cart, the title placard flown in, the basket slip pinned to the left pillar; key, fill and footlight shadows |
| `character.jpg` | `demo.html?frame=character` | the girl with her basket, close and turned so the paper border and card edge show, against the rows and back cloth |
| `prop.jpg` | `demo.html?frame=prop` | the woodcutter's cart with its logs and axe, with its accent marker |
| `text-heavy.jpg` | `demo.html?frame=text-heavy` | the busiest screen at worst-case content: the basket (five items, courage and daylight pips, a warning chip) on the left pillar, the playbill on the right, the wolf's longest line with four numbered choices (one focused, one blocked) flown in on wires, name tags under the girl and the cart, and the wolf's detail card in place of his tag |
| `dont.jpg` | `demo.html?frame=dont` | the look broken: no card edges or shadows, flat unlit prints, mixed art scales (a coarse pixel girl, an airbrushed wolf without outlines or border, a real 3D cart), oversaturated colour |
| `godot-key-scene.jpg` | Godot 4.7.1, Compatibility renderer, `godot.md`'s code | the key scene rebuilt in Godot from this entry's images (unpacked from `../assets/images.js`, imported lossless, mipmaps rebuilt in linear light at start-up) with the paper, depth, vignette and slip code in `../godot.md`: same camera, matinee lighting plot, self-rendered key and footlight shadow maps, card edges, placard, markers and basket slip, posed at t = 0.4 s; captured from the 1280×720 window, saved as JPEG quality 85. Mean difference from `key-scene.jpg` about 3/255 per channel, mostly texture detail and glyph edges |

Add `&mood=night` to any URL except `dont` to see the same printed set under the ominous night
lighting plot.
