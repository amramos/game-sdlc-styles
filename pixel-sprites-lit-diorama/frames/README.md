# Frames

Captured from `demo.html` in this folder, which builds every frame deterministically (fixed camera,
fixed seed, fixed animation time) in `example-palette.gpl`'s day palette. The setting is original: a
garden market on a rooftop at the top of a hill town.

**What is generated and what is code.** The four townsfolk and the three stall signs are ComfyUI
images cleaned with PixelForge onto the entry's roles (`assets/cast-palette.gpl`, `assets/pixelforge.toml`).
The floor, plaster, roof and plank surfaces wear tileable value maps made in MaterialCraft. The page
builds the set from primitives, paints the sky, and draws only the interface. How each asset was
made, with prompts and seeds: `assets/README.md`.

**Capture:** in frame mode the page draws a fixed 1280×720 canvas pinned at its top-left, whatever
the viewport. It waits for every sprite, sign and texture to load, renders about 10 frames, then
sets `document.title = 'ready'`. Screenshot the 1280×720 region at the top-left with headless Chrome
on the GPU and `--allow-file-access-from-files` (the textures load by relative path). Saved as JPEG
quality 85: the frames are lit 3D with tilt-shift, bloom and grain, which PNG cannot fit under
300 KB; the sprites' edges hold at that quality. The page needs network access for three.js
0.160.0 from jsdelivr.

After a capture, `document.body.dataset.textAudit` reports `overlaps=0 clipped=0 outside=0 covers=0`
when no text box overlaps another, is cut off, leaves the frame, or covers a sprite.

| File | URL | Shows |
|---|---|---|
| `key-scene.jpg` | `demo.html?frame=key-scene` | the market from the fixed stage: three stalls with striped awnings and painted signs, bunting, tiled floor, planters, potted trees, crates, four generated townsfolk, the selected one on its accent ring, three stage captions, the plastered hill town with tiled roofs falling away behind, the banded valley surface, the painted backdrop; tilt-shift and bloom on |
| `character.jpg` | `demo.html?frame=character` | an eased-in close-up of the selected townsperson: letterbox bars, the lower-third title card, captions hidden, stronger tilt-shift; the point-sampled floor and plank textures read as pixels |
| `prop.jpg` | `demo.html?frame=prop` | the fig stall close up with its painted sign, lamp, goods and awning, no people |
| `text-heavy.jpg` | `demo.html?frame=text-heavy` | the busiest screen: an icon status bar (day and time, coins, stalls, standing meter), two signal chips, five live captions, the buyer's order pinned as a paper slip, key hints, and the portrait strip cut from the sprites |
| `godot-key-scene.jpg` | Godot 4.7.1, Compatibility, `godot.md` | the key scene rebuilt in Godot from `godot.md`'s code and this entry's own sprites, signs and value maps: same camera, set, cast, captions, tilt-shift and grade; rendered windowed on the GPU at 1280×720 with 4× MSAA, saved as JPEG quality 85, and compared with `key-scene.jpg` (mean difference about 3/255; the caption glyphs differ most) |
| `dont.jpg` | `demo.html?frame=dont` | the key scene breaking the look: smooth-filtered, blended sprites, glossy untextured plastic instead of toon paint and point-sampled maps, no signs, no tilt-shift |

Add `&palette=night` to any URL for the same frame in the night palette: the page repaints each
sprite and sign pixel by its role, and the value maps multiply the night role colours.

## TextureCraft and MaterialCraft, as tried here

- **MaterialCraft** made all four surfaces. Good: headless, fast, deterministic, tileable by
  construction, and posterising inside the graph gives a pixel-art value ramp directly; the saved
  `.sbs` keeps each map editable. Bad: version 0.2.0 ships only atomic nodes, so there is no brick,
  tile or noise generator to start from: every pattern had to be written as a per-pixel function
  graph (72–274 nodes), which needs a small compiler script and is not something to do by hand.
  The function ops are not listed by the CLI; their names had to be probed through `unknown
  function` errors. Exports are 16-bit grey PNGs, which look white in tools that clip to 8 bits.
- **TextureCraft** was tried on its built-in plane with the `tiles_ceramic`, `brick`, `plaster`,
  `wood_painted`, `wood_pine`, `clay`, `cobblestone`, `sandstone` and `linen` materials. Good: one
  batch call gives a full PBR set, and `brick` and `tiles_ceramic` are clean patterns. Bad for this
  look: the materials are realistic in tone (smooth gradients, fine noise, fixed colours), plaster
  and painted wood come out nearly flat, and nothing maps to a palette role without re-grading. It
  paints a specific mesh rather than making tiling swatches, so it suits a hero prop more than set
  surfaces in a palette-led style.
