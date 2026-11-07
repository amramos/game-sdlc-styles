# Frames

The frames are rendered from `demo.html` in its example palette (cold core), in an original
setting: defending a data core from swarms in an arena. Everything is drawn in code (Canvas 2D);
no image or model generator is used, and the page loads no assets.

**How the glow is made:** every glowing line goes on two offscreen layers, a crisp one (colour core
plus a near-white centre) and a bloom source (pure colour, a little wider, additive). The bloom
source is blurred at three radii (2, 7 and 24 px at 720p; the wide one on a quarter-size canvas)
and added back with gains of 1.2, 1.8 and 3.2, then the crisp layer goes on top. Enemy shots get a
void rim cut into the finished bloom and a tighter pass of their own; the HUD has no panels and
its own tight glow (1.5 and 5 px). See `../recipe.md` and `../web.md`.

**Capture:** viewport 1280×720, device scale 1; in frame mode the canvas is exactly 1280×720 at the
top-left. Wait until `document.title === 'ready'`, then screenshot the page. **Save as PNG** and
re-save with Pillow `optimize=True`: thin glowing lines and dark gradients band and smear under
JPEG, and bloom gradients make the files 230–305 KB, close to the 300 KB budget. Each frame is
drawn once from a fixed seed, so every capture is identical.

| File | URL | Shows |
|---|---|---|
| `key-scene.png` | `demo.html?frame=key-scene` | a frozen moment of the fight: the player firing at a splitter that just burst, the grid dented around it, all three enemy classes, red shots with void rims, a hazard telegraph, pickups, the core at 4/6 (its arcs), and the in-play HUD: score, multiplier, life ships, wave |
| `character.png` | `demo.html?frame=character` | the attract-mode roster: the player ship and the three enemy classes drawn large with names and point values, two red shots |
| `prop.png` | `demo.html?frame=prop` | the core and the three pickups drawn large, with names and values |
| `text-heavy.png` | `demo.html?frame=text-heavy` | the busiest screen at worst case: 11-digit score, ×128, five lives, a wave banner, an upgrade choice of three cut-corner frames with icons, the longest descriptions and focus on one, key prompts |
| `dont.png` | `demo.html?frame=dont` | the key scene breaking the rules: a bright background and thick bright grid, every enemy the same circle told apart only by colour, debris in the danger colour, and a boxed HUD under the world's heavy bloom so the digits smear |
| `godot-key-scene.png` | (Godot 4.7.1 test, Compatibility) | the key scene rebuilt in Godot from `../godot.md`: the same shapes and grid drawn with `Line2D`, the bloom made as on the web (a line layer and a bloom source per pass in 2× supersampled SubViewports, the source blurred at the same radii and added with the same gains), and the boxless HUD in its own tight pass. Window 1280×720, saved as PNG; mean difference to `key-scene.png` under 1/255 per channel |

Other palettes: add `&palette=acid` or `&palette=ember` to any URL. Those show that the roles, not
the hexes, make the look; the catalog frames use the default.
