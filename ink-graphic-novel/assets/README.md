# Assets

Every picture in `demo.html` is generated art; the page draws only the interface (panels, captions,
balloons, slips, icons, the note) and the falling snow. Each file is a PNG stored as a data URI in a
small script (`window.ART['<name>'] = 'data:image/png;base64,…'`), so the page can read its pixels
from `file://` to recolour it for the other palettes. Total about 0.94 MB.

**Generator:** ComfyUI 0.37.0, profile `zimage-int8` (Z-Image Turbo int8, cfg 1, the profile's
defaults), RTX 4070 Ti. Two seeds (101, 102) per prompt; the kept seed is listed.

**Prompt core** (from `recipe.md`), with the palette as words and hex: *Graphic novel ink
illustration: heavy solid black shadow shapes covering the side away from the light, bold thick
brush ink outlines that swell on the shadow side, simple graphic shapes, flat colour fills with no
gradients and no painterly texture, a very limited palette of dark night navy (#1C2A3C), slate blue
(#3E5872), pale icy blue (#8EA9C2), warm cream (#ECE4CE) and black (#080A10)*, then either "with no
orange anywhere" or "with one bright orange (#F4923A) accent on <the focal thing>".
Cutouts replace the first clause with *the side away from the light is filled with flat solid black
ink inside the drawn outline* and end with *A sticker cut-out: the background is untouched pure
magenta right up to the drawn object's outline, with no dark halo, no dark cloud, no shadow shape
and no splash behind it. Isolated on a plain flat solid pure magenta (#FF00FF) background,
completely empty, no ground, no cast shadow, no scene. No text, no lettering, no border.*
Backdrops end with *One full-bleed illustration that fills the whole frame, plain unmarked corners.
No people, no animals. No text, no lettering, no border.*

**Cleanup** (`process.py`, the same for every cutout): median 5 px; key: pixels whose red and blue
both stand well above green (magenta to the pink the model often paints instead); background is
only the key joined to the image border; every hole inside the silhouette is then filled (closed
silhouette), except enclosed holes of key colour of 150 px or more (gaps between legs closed by the
ground shadow); crumbs under 1% of the largest shape dropped; the 3 px band inside the cut edge set
to ink (this also outlines pale edges the model drew without a line); every pixel snapped to the
nearest night role (ink, field-1..3, paper, accent), with paper allowed only for warm creams (cold
whites are snow, so field-3) and the accent only for clearly orange pixels; downscaled with Lanczos
to the size below; quantized to 48 colours. Only `rescuer-flare` has a sticker halo; for it alone,
light pixels joined to the background are keyed too (`--halo`).

| File | Kind | Subject (after the prompt core) | Size | Seed | Notes |
|---|---|---|---|---|---|
| `bg-exterior.png.js` | backdrop, 1536×960 | rescue station hut with two lit windows, radio mast, jagged peaks with black flanks, night sky, empty snowfield in the lower 40% | 1008×630 | 101 | snapped without the accent |
| `bg-radio-room.png.js` | backdrop, 1536×1024 | radio room: plank wall, window onto snowy night, desk, shelf | 600×387 | 101 | cropped to the window and desk (40,120)–(1080,790) |
| `bg-slope.png.js` | backdrop, 1536×1024 | snowy slope at night, black pines on the left | 1008×672 | 102 | paper disabled (all snow is field-3) |
| `rescuer-pull.png.js` | cutout, 1024×1536 | rescuer in a hooded parka walking right, one arm back on a tow rope | 614×1000 | 101 | the rope to the sled is drawn by the page |
| `rescuer-flare.png.js` | cutout, 1024×1536 | rescuer facing right, a hand flare raised (the accent) | 397×1000 | 102 | sticker halo removed (`--halo`) |
| `dog.png.js` | cutout, 1024×1024 | search dog in a harness, side view facing right, tail up | 777×683 | 102 | |
| `dog-close.png.js` | cutout, 1024×1024 | dog head and neck, nose raised, collar beacon (the accent) | 639×640 | 101 | accent limited to the collar's box |
| `sled.png.js` | cutout, 1536×1024 | rescue toboggan with a tarp-wrapped load, "empty of people" | 899×343 | 101 | |
| `operator.png.js` | cutout, 1024×1024 | seated radio operator with headset and hand microphone, facing right | 505×600 | 101 | |
| `radio-set.png.js` | cutout, 1536×1024 | field radio: dial, grille, antenna, transmit lamp (the accent) | 456×500 | 101 | |
| `thermos.png.js` | cutout, 1024×1024 | metal flask with a black cap | 300×470 | 101 | |
| `rope.png.js` | cutout, 1024×1024 | coil of climbing rope | 400×155 | 102 | |
| `ice-axe.png.js` | cutout, 1024×1024 | ice axe standing upright | 300×497 | 102 | |
| `paper-grain.png.js` | texture, 1024×1024 | *A flat scan of one sheet of plain uncoated cream newsprint paper… fine soft paper grain with faint short fibres and very slight mottling…* | 512×512 | 101 | greyscale high-pass (minus a 24 px blur), made tileable by cross-fading with a half-offset copy, mapped to 0.86–0.97; multiplied over every paper surface |

## Rounds

- First round: the prompt core's "heavy solid black shadow shapes" made the model paint a black
  cloud behind every cutout. Saying where the black goes ("inside the drawn outline") and that the
  magenta is untouched up to the outline fixed it.
- The word "subject" in the cutout line made the model draw a person into every prop picture (a man
  on the sled, behind the rope, holding the axe). Rewritten as "the drawn object"; props re-run.
- "A sticker cut-out" sometimes adds a pale sticker border around the cutout. Keying light pixels
  joined to the border on every cutout also ate the dogs' cream muzzles and throats (the panel
  showed through); the halo key now runs only on the one image with a halo, and every cutout's
  silhouette is filled closed.
- MaterialCraft was tried for the paper grain; this build's node library has no noise generators,
  so the grain was generated instead.
- Generation needed about 25 images over three rounds, roughly 10 minutes of GPU time.
