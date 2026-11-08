# Frames

Rendered by `demo.html` in this folder: generated ink art (ComfyUI, cleaned onto the palette roles;
see `assets/README.md`) laid out in panels, with every word, number, icon, balloon, slip and note
drawn live on a canvas. Frames use `example-palette.gpl`'s stark night palette; the setting is
original: a mountain rescue station in winter (two rescuers bringing in a sled, a search dog, the
radio room).

**Capture:** `demo.html?frame=<name>` draws once on a fixed 1280×720 canvas at the page's top-left,
after every image has decoded, then sets `document.title` to `ready`; no animation runs. Captured
with headless Chrome on the GPU, saved as JPEG quality 85. Every word uses the fonts bundled in
`assets/fonts/` (Comic Neue lettering, Alegreya titles, Arimo for the `dont` frame's small sans-serif),
so captures look the same on every system.

| File | URL | Shows |
|---|---|---|
| `key-scene.jpg` | `demo.html?frame=key-scene` | a comic page: the station at night with the team, sled and dog coming in (the flare as the panel's one accent), the radio room (the transmit lamp as accent), the dog close-up with a sound word (the collar beacon as accent); below, the question as a bare title, wind and battery as icons with their numbers, three answers as torn paper slips with their keys (the first lifted), and a pinned note |
| `character.jpg` | `demo.html?frame=character` | the rescuer with the flare and the dog large on the night slope; the silhouette test of both cutouts; the eight role swatches |
| `prop.jpg` | `demo.html?frame=prop` | the rescue sled large; the radio set; flask, rope coil and ice axe, each named on a paper tag |
| `text-heavy.jpg` | `demo.html?frame=text-heavy` | the busiest screen at worst-case content: title caption, wind, visibility, battery and contact-lost icons with numbers, the radio room panel, a four-entry radio log, three roster cards with the longest names and a stamped condition each, four orders on slips (one lifted, one unavailable with its reason) and a note; text fits by measured wrapping, nothing truncated |
| `dont.jpg` | `demo.html?frame=dont` | the key scene breaking the rules: blurred, oversaturated art under a gradient wash, soft drop shadows, warm glows on several things at once, the boxed question, pill chips and equal rounded buttons in small sans-serif |
| `godot-key-scene.jpg` | Godot 4.7.1, Compatibility renderer, from the code in `godot.md` | the key scene rebuilt in Godot from `Control`/`Node2D` scenes and the same generated images: panels, captions, balloon, sound word, icons, slips and note drawn by the component scripts, the paper grain multiplied over the page and every paper shape; rendered on the GPU at 1280×720 and saved as JPEG quality 85, to compare with `key-scene.jpg` |

Add `&palette=pulp` (bright daytime) or `&palette=noir` (grey) to any URL to see the same frame in
another palette: the page recolours the art by luminance onto that palette's roles. Without
`?frame`, the interactive demo opens on the bright palette; keys 1–3 and the arrows move the lifted
slip.
