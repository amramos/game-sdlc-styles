# Frames

Screenshots of `demo.html`: sky islands linked by a glider courier route (floating rocks, a
windmill, a courier with a scarf, crates, route rings), in `example-palette.gpl` (the demo's
`noon` palette). The courier and the windmill are generated models (ComfyUI concept → Meshy
image-to-3D, texture flattened to palette slots; see `../assets/README.md`); the islands, trees,
crates, rings, clouds and sky are primitives, and the interface is live HTML. The sky is four flat
steps from `sky-horizon` to `sky-top` (two more below the horizon); clouds sit at three depths;
linear fog in `sky-horizon` (30–210 m) pales far islands and clouds. The windmill's sails turn in
the interactive demo and are still in the frames.

**Capture:** viewport 1280×720, device scale factor 1, GPU. Open each URL, wait until
`document.title === 'ready'` (the page waits for both models, renders 10 frames at a fixed time
and stops), capture, crop to 1280×720, save as JPEG quality 85.

| File | URL | Shows |
|---|---|---|
| `key-scene.jpg` | `demo.html?frame=key-scene` | the main island seen from the air beside it: the courier with crates near its edge, the rocky drop beneath, the windmill behind, the route rings against open sky leading to a far island, more islands and clouds beyond |
| `character.jpg` | `demo.html?frame=character` | the courier alone, full body, three-quarter view, on a flat `sky-horizon` backdrop |
| `prop.jpg` | `demo.html?frame=prop` | one delivery crate with its strap and `accent` tag, from 30° above, on the same backdrop |
| `text-heavy.jpg` | `demo.html?frame=text-heavy` | the key scene under the busiest screen at worst-case content: the longest dialogue line with three options, five deliveries with chips, a full satchel with a tooltip, altitude and wind, all four signal chips, the glide meter |
| `dont.jpg` | `demo.html?frame=dont` | the key scene breaking the look: smooth PBR shading, grey shadows, no outlines, six bands on the courier, grey fog, filmic tone mapping |
| `godot-key-scene.jpg` | Godot 4.7.1, Compatibility renderer, `godot.md`'s code | the key scene rebuilt in Godot from this entry's two GLBs (decoded from `../assets/*.glb.js`, slot maps imported uncompressed) and primitives, with the toon, slot, outline and sky shaders in `../godot.md`: same camera, light, fog and pose (t = 1.25 s, sails at angle 0); captured from the 1280×720 window, saved as JPEG quality 85. Mean difference from `key-scene.jpg` about 2/255 per channel, mostly on antialiased edges |

Other palettes: add `&palette=dusk` or `&palette=mint` to any URL. The generated models follow the
palette too, since their textures hold palette slots, not colours.
