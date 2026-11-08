# Frames

This entry's frames are rendered by `demo.html`, in the example palette, with an original setting:
a desert caravan market (two stalls under striped awnings, two traders, a pack beast, crates and
sacks, a hooded traveller). The traders, the traveller (4-frame walk), the beast and the dialogue
portrait are ComfyUI sprites cleaned onto the palette and canvases with PixelForge; how is in
`../assets/README.md`. The demo draws everything into one indexed 320×180 (or 160×90) buffer and
scales it by a whole number with nearest-neighbour sampling.

Capture each URL at a **1280×720** viewport, device scale factor 1, and save as **PNG** (pixel art
must be PNG: JPEG smears pixel edges and adds off-palette colours). Each page sets
`document.title` to `ready` when the frame is drawn.

| File | URL | Shows |
|---|---|---|
| `key-scene.png` | `demo.html?frame=key-scene` | the market at noon, 320×180 at ×4: both stalls with their traders, the beast, the traveller mid-stride, the accent interaction marker and the corner HUD (purse, sun and day) |
| `character.png` | `demo.html?frame=character` | 160×90 at ×8 on a strip of the world: the two traders, the beast and the traveller standing; below, the traveller's walk (contact, passing, contact, passing) |
| `prop.png` | `demo.html?frame=prop` | 160×90 at ×8: the beast beside the goods it carries (crates, lantern, sack, pot, cloth rolls, fruit, jar); the pack bar with the 8 item icons, the focused slot in the accent, and the purse |
| `text-heavy.png` | `demo.html?frame=text-heavy` | the trade screen at worst case over the dithered scene: 8 goods with the longest name, quantities, prices, every signal chip, item detail, four buttons with focus, purse and load meter, a 3-line dialogue with her portrait and name tab |
| `godot-key-scene.png` | (Godot test) | the key scene rebuilt in Godot 4.7.1 (Compatibility) by the code in `../godot.md`, from the same sprite PNGs and draw order: the 320×180 viewport captured and scaled ×4 nearest; 0 pixels differ from `key-scene.png` |
| `dont.png` | `demo.html?frame=dont` | the key scene breaking the rules: non-integer ×4.27 scale with smoothing, off-palette gradient glow, the beast at double pixel size, a rotated sub-pixel sprite, soft drop shadow, small anti-aliased text (the pixel font at sizes off its grid, at sub-pixel positions) |

Optional palette swaps for the "roles, not hexes" claim: add `&palette=dusk` or `&palette=oasis`
to the key-scene URL (`key-scene-dusk.png`, `key-scene-oasis.png`).
