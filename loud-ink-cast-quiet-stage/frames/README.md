# Frames: to be captured

This entry's frames are made fresh for the catalog, with an original setting and cast: a night
market's food stall run by monsters, haggling with customers. **No frame, asset, prompt text or
screenshot from the game this look was proven in may be used**, even as a stand-in: that game is a
commercial release, and the catalog must not become a way to clone it.

They are captured from `demo.html` in this folder. The stage and cast are images in `../cast/`
(generated with ComfyUI; prompts and seeds in `../cast/README.md`); every panel, chip, label, word
and number is drawn by the page. The page needs no network.

**Capture:** viewport exactly 1280×720, device scale 1. Open the URL, wait until
`document.title === 'ready'`, then screenshot the viewport. In frame mode the page draws at a
fixed 1280×720 pinned to the top-left, whatever the window size, with no animation. Save as JPEG at quality ~85 (illustrated art),
named after the frame.

| File | URL | Shows |
|---|---|---|
| `key-scene` | `demo.html?frame=key-scene` | the stall at night: a quiet stage of wood, canvas, metal and tile; one loud customer haggling, left of centre; their line in a paper panel pointing at them, with a halftone shadow; their offer on a tilted tag; one signal chip; three options on the near-black counter, the focused one lifted inside four corner brackets; the primary action with its hard accent shadow |
| `character` | `demo.html?frame=character` | the stall keeper, waist-up, neutral pose, on the flat key colour, with a tilted name label |
| `prop` | `demo.html?frame=prop` | one cooking tool (a wok), centred on the flat key colour, with a tilted label |
| `text-heavy` | `demo.html?frame=text-heavy` | the key scene at worst-case content: the longest line of dialogue, all three signal chips (each printing its kind), the full row of five options and the running total on a receipt |
| `dont` | `demo.html?frame=dont` | the same key scene on a busy, bright stage: glowing lanterns and string lights, a glowing sign, saturated colours and halftone on the set, so the stage outshouts the cast |
| `godot-key-scene` | (Godot 4.7.1 test, Compatibility) | the key scene rebuilt in Godot by the code in `../godot.md`: the same stage and customer PNGs from `../cast/` in `TextureRect`s, and every panel, tail, chip, card, bracket and word drawn by the engine from one theme, with the same bundled font files as the web page. Captured from the 1280×720 window, saved as JPEG quality 85. Mean difference from `key-scene.jpg` under 2/255 per channel; what differs is glyph rasterisation, not layout |

Add `&palette=day` to any URL to capture the same frame in a bright daytime-market palette that
fills the same roles (the default, `night`, is `example-palette.gpl`). Both pass every colour rule
in `style.md`. The day palette tints only the interface and the stage; the cast art keeps its night
shadow colour.

Without `?frame`, the page fits the screen to the window and adds a palette and screen switcher;
options take hover, arrow keys and clicks, and "Loudest moment" (or the action button) plays the
cut-in: a diagonal paper band with the keeper's outraged pose and a stamped title, under 1.4 s,
the bottom fifth left clear. Idle motion runs at about 10 fps and stops while the tab is hidden.

## Evidence

Building these frames found three things the entry's text did not say:

- **The prompt core's background half draws a background.** On cast art meant for a flat key
  colour, its sentences about "the background" made the model paint a stage (a stall, a crowd)
  behind the subject in most seeds. Dropping the background half and the setting line for
  characters and props fixed it.
- **Cast art comes back with a drop shadow on the key colour.** Key the shadow with the backdrop.
- **A daylight stage can't pass `value(stage-*) <= 0.30`.** The day palette passes it, so its mood
  comes from the paper, accent and stage hues, not from a bright set.
