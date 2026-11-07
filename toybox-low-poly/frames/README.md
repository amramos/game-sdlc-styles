# Frames: to be captured

This entry has no frames yet. They are captured from `demo.html` in this folder, which builds every
frame deterministically (fixed camera, fixed seed, fixed animation time) in `example-palette.gpl`'s
autumn palette. The setting is original: a mushroom village being built in autumn.

**Capture:** viewport exactly 1280×720, device scale 1. Open the URL, wait until
`document.title === 'ready'` (about 10 rendered frames), then screenshot the viewport. Save as JPEG
or WebP at quality ~85, named after the frame. The page needs network access to load three.js
0.160.0 from jsdelivr.

| File | URL | Shows |
|---|---|---|
| `key-scene.jpg` | `demo.html?frame=key-scene` | the village from the isometric camera: mushroom houses, paths, fences, leaf piles, trees, a building site and two villagers with accent markers, the placement ghost on its accent ring; tilt-shift on |
| `character.jpg` | `demo.html?frame=character` | the villager carrying a plank, three-quarter view, on a small ground disc against the sky gradient |
| `prop.jpg` | `demo.html?frame=prop` | one mushroom house on a ground disc |
| `text-heavy.jpg` | `demo.html?frame=text-heavy` | the key scene under the busiest interface at worst-case content: six resource counters, all four signal chips, the long tooltip of the selected building with costs and rule chips, and the full build menu of nine items with costs, one unaffordable |
| `dont.jpg` | `demo.html?frame=dont` | the key scene breaking the rules: smooth high-poly shapes, hard black shadows, saturated clashing colours, paths coplanar with the ground (z-fighting), the accent reused on decor, no fog or tilt-shift |

Add `&palette=spring` or `&palette=winter` to any URL to capture the same frame in another palette
that fills the same roles.
