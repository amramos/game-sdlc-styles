# Frames

Screenshots of `demo.html` in this folder, which builds every frame deterministically (fixed
camera, fixed seed, fixed animation time) in `example-palette.gpl`'s sunny-afternoon palette. The
setting is original: a roadside diner (counter and stools, booths, a cook at the pass, a jukebox, a
car parked outside).

**How the scene is made:** the set is chunky primitives built in code, every face split every
0.5 m so the affine texture swim stays subtle. The floor, brick and counter-top textures are 64 px
MaterialCraft materials; the other small textures are drawn in code from the palette roles. The
cook is a Meshy model made from a ComfyUI concept, its texture cut to 256 px. Everything is drawn
by one shader (vertex snap to the 240-line grid, affine UVs, per-vertex light, linear fog) and a
post pass (nearest upscale, 4×4 ordered dither, 5 bits per channel). `../assets/README.md` lists
each asset and how it was made.

**Capture:** open the URL; in frame mode the page loads its assets, draws a fixed 1280×720 canvas
pinned at the top-left, renders about 10 frames, stops and sets `document.title === 'ready'`.
Capture the 1280×720 region at the top-left at device scale 1. The dithered frames stay PNG (the
dither smears in JPEG); `dont` is a smooth render, saved as JPEG quality 85. The page needs
network access to load three.js 0.160.0 from jsdelivr.

| File | URL | Shows |
|---|---|---|
| `key-scene.png` | `demo.html?frame=key-scene` | first person from a counter stool: the counter with a cup and pie in front, the cook behind it, a menu board, the pass into the brick-walled kitchen, the jukebox in the far corner with the `accent` pulse, the end window with the roadside sign outside, booths at the left edge, fog in the distance |
| `character.png` | `demo.html?frame=character` | the cook alone, three-quarter view, on a checker-floor disc against the sky dome |
| `prop.png` | `demo.html?frame=prop` | the jukebox alone, three-quarter view, on the same disc |
| `text-heavy.png` | `demo.html?frame=text-heavy` | the key scene under the busiest screen at worst-case content: status bar, four signal chips, six open orders with the longest names, the cook's longest line with three options, and a prompt over the jukebox, all live text, nothing truncated or overlapping |
| `dont.jpg` | `demo.html?frame=dont` | the key scene with the look broken: full-resolution smooth render with 4× multisampling, perspective-correct mipmapped linear textures, per-pixel light, no vertex snap, no dither or quantisation |
| `godot-key-scene.png` | Godot 4.7.1, Compatibility renderer, `godot.md`'s code | the key scene rebuilt in Godot from this entry's assets (the three MaterialCraft PNGs, the cook GLB) and `godot.md`'s code: the same set, camera, shaders and post pass, posed at the same time; captured from the 1280×720 window. Mean difference from `key-scene.png` under 1/255 per channel |

Add `&palette=night` to any URL for the same frame late at night under neon and fluorescent light.
It fills the same roles, passes the same rules, and keeps every material: only light, fog, sky and
glow change.
