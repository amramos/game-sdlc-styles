# Frames

Screenshots of `demo.html` in this folder, which builds every frame deterministically (fixed
camera, fixed seed, fixed animation time) in `example-palette.gpl`'s sunny-kitchen palette and
lighting. The setting is original: a miniature bakery street on a kitchen table.

**What is generated and what is code.** The four main pieces are Meshy models made from ComfyUI
concept images: the shop (one mesh, repainted four ways in TextureCraft, plus a fifth in bare
wood), the baker, the handcart (green and red repaints) and the market stall. The kitchen table and
the cobbled street are MaterialCraft tiling materials. Code draws the base, the two small
figurines, the loose loaves, the full-size cup, rolling pin, cards and candle, the accent ring, and
every word: shop signs and cards are live text. `assets/README.md` lists every file and how it was
made.

**Capture:** open each URL, wait until `document.title === 'ready'` (the page loads every model and
texture, renders 10 frames and stops), then capture the region 1280×720 at the page's top-left at
device scale factor 1. Save as JPEG at quality 85. The page needs network access for three.js
0.160.0 from jsdelivr, and Chrome needs `--allow-file-access-from-files` to load the textures from
`file://` (or serve the folder over http).

| File | URL | Shows |
|---|---|---|
| `key-scene.jpg` | `demo.html?frame=key-scene` | the whole table from the seated camera: five shops (one still in bare wood) behind the cobbled street, the baker, the loaded green cart in its accent ring, the stall, the red cart, the full-size cup, rolling pin, cards and candle; a day card and one spoken line; tilt-shift, vignette and grade on |
| `character.jpg` | `demo.html?frame=character` | the baker figurine close up, three-quarter view, the shops soft behind; tilt-shift at half radius |
| `prop.jpg` | `demo.html?frame=prop` | the loaded handcart close up, from about 30° above |
| `text-heavy.jpg` | `demo.html?frame=text-heavy` | the key scene under the busiest screen at worst-case content: the day card with every counter, six orders with the longest names and stamps, the selected figure's card with a long name, stats, a note and three stamps, a two-line spoken line and three spoken choices; nothing truncated or overlapping |
| `dont.jpg` | `demo.html?frame=dont` | the key scene with the look broken: glossy plastic with reflections, smooth shading with no facets or grain, a harsh overhead light, no fill, no fog, no tilt-shift, vignette or grade |
| `godot-key-scene.jpg` | Godot 4.7.1, Compatibility renderer, `godot.md`'s code | the key scene rebuilt in Godot from this entry's four GLBs (decoded from `../assets/*.glb.js`, flat-shaded), its painted maps and tiling materials (linearised at load) and three.js-compatible primitives carved with the demo's seed, with the shaders in `../godot.md`: same camera, sun, hemisphere fill, fog, shadows, tilt-shift, vignette, grade and ACES, and the same two paper cards; captured from the 1280×720 window, saved as JPEG quality 85. Mean difference from `key-scene.jpg` about 2.6/255 per channel, mostly glyph rasterisation on the cards and antialiased or shadow edges |

Other lighting schemes: add `&mood=candle` (evening candlelight) or `&mood=morning` (cool morning
window) to any URL. The table, street and code-drawn pieces take the scheme's palette; the painted
models keep their sunny paints and change only with the light.
