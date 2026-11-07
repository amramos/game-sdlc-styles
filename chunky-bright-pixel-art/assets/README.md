# Assets

The cast and the pack beast in `demo.html` are generated sprites, not code-drawn. Everything else
(stalls, crates, props, icons, font, interface) is still drawn by code on the same indexed grid.

## Files

| File | Size | What it is |
|---|---|---|
| `sprites.js` | 7 KB | every sprite below as rows of role letters (`k` ink, `p` paper, `1`–`4` warm, `a`–`d` cool, `.` clear); the demo loads it with `<script src>` so a palette swap reaches every pixel and nothing is read back from an image |
| `sprites/cast_traveller.png` | 16×24, 0.4 KB | the traveller, walk contact pose (generated) |
| `sprites/cast_traveller_walk2.png`, `_walk3`, `_walk4` | 16×24, 0.4 KB each | passing, other contact, passing: the generated sprite with the legs (rows 19–23) redrawn by hand |
| `sprites/cast_trader1.png` | 16×24, 0.3 KB | the turbaned spice trader (generated; eyes placed by hand) |
| `sprites/cast_trader2.png` | 16×24, 0.4 KB | the cloth trader (generated) |
| `sprites/bust_trader2.png` | 24×24, 0.4 KB | her dialogue portrait (generated; moved 1 px right and 2 px down, skin moved from warm-4 to warm-3 to match the standing sprite) |
| `sprites/beast_camel.png` | 36×28, 0.6 KB | the pack beast (generated) |
| `sprites/beast_camel_chew.png` | 36×28, 0.6 KB | its idle frame B: head and neck (columns 0–11) lowered 1 px |
| `pixelforge.toml` | 1 KB | palette (`../example-palette.gpl`), reserved colours and the three canvases |
| `tools/handedit.py`, `tools/tojs.py` | 3 KB | the hand edits above as a script, and the PNG → `sprites.js` step with the outline rule |

Total about 25 KB.

## How they were made

1. **ComfyUI**, profile `zimage-int8` (`z_image_turbo_int8_convrot`), txt2img 1024×1024, one
   subject per generation, seeds 11 22 33 44 per prompt; picks: traveller 11, trader 1 seed 33,
   trader 2 seed 44, beast seed 22, bust seed 33. Every prompt starts with this core:

   > Pixel art game sprite, large chunky pixels, hard edges, 1 pixel dark purple-black outline
   > around the whole sprite, limited palette: dark purple-black #1E1430, cream #FFF4D6, maroon
   > #6B2E3A, rust #B8543A, orange sand #E89A4C, pale yellow #FFD77A, deep indigo #2B2459, blue
   > #33589E, sky blue #3FA0C8, pale aqua #9BE8E4, flat colour shading with 2-3 hue-shifted tones,
   > light from the upper left, clear readable silhouette, no anti-aliasing, no gradients, no
   > dithering, no blur, no text, 16-bit side view game sprite, head one third of the height.

   (The bust uses "Pixel art game portrait" and drops the last clause.) Then the subject:
   - traveller: "A desert market traveller seen from the side facing right, mid-stride walking,
     wearing a deep blue hooded cloak with the hood up, sky blue scarf over the lower face, a
     rust-brown belt and satchel strap, tan trousers, dark brown boots, small and sturdy."
   - trader 1: "A stout bearded spice merchant standing facing the viewer, front view, arms at his
     sides, wearing a pale aqua and blue wrapped turban, short dark maroon beard, warm tan skin, a
     long rust-brown robe with an orange sash and a pale yellow belt buckle, dark boots."
   - trader 2: "A cheerful woman cloth merchant standing facing the viewer, front view, hands
     clasped in front, wearing a sky blue headscarf framing her face, warm tan skin, a long pale
     yellow and orange robe with a blue vest, dark sandals."
   - beast: "A dromedary camel seen from the side facing left, standing, long curved neck raised,
     one hump with a blue and aqua striped saddle blanket and two rust-brown cargo bundles tied on,
     orange sand coloured fur with rust shading, maroon hooves, a small dark eye."
   - bust: "Head and shoulders of a cheerful woman cloth merchant facing the viewer, smiling, big
     friendly dark eyes, wearing a pale aqua and sky blue headscarf framing her face, warm
     orange-tan skin, a cream robe collar and a blue vest."

   and the framing: "Full body, feet near the bottom, centred, the figure fills two thirds of the
   frame height, on a plain flat solid pure magenta background, completely empty, no ground, no
   shadow." (beast: "Whole animal visible, … fills most of the frame width"; bust: "Head and
   shoulders filling the frame").
2. **Key**: `comfyui-art/scripts/pixel_post.py key` (flood fill from the border; 69–74% removed).
3. **PixelForge**, run from this folder: `python -m pixelforge clean <keyed.png> --canvas
   cast|beast|bust -o sprites/<name>.png` (snap to the palette at full size → mode-downscale →
   fit, anchored bottom). The backdrop and signal colours are reserved, so snapping cannot put
   them on a sprite. `python -m pixelforge lint` is clean.
4. **Hand edits** at true size: `python tools/handedit.py sprites`.
5. **Outline rule and export**: `python tools/tojs.py . traveller=sprites/cast_traveller.png
   traveller2=sprites/cast_traveller_walk2.png traveller3=sprites/cast_traveller_walk3.png
   traveller4=sprites/cast_traveller_walk4.png trader=sprites/cast_trader1.png
   trader2=sprites/cast_trader2.png trader2Bust=sprites/bust_trader2.png
   camel=sprites/beast_camel.png camelChew=sprites/beast_camel_chew.png`: every opaque pixel that
   touches transparency or the canvas edge becomes ink (the PNGs are rewritten with it), then
   `sprites.js` is written.
