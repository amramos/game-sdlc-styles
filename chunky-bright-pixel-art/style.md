---
id: chunky-bright-pixel-art
version: 1
name: Chunky bright pixel art
---

# Chunky bright pixel art

## The look

Saturated, highly readable pixel art at a low base resolution (320×180 by default), scaled to the
screen by a whole number with nearest-neighbour sampling, so every art pixel is a crisp square of
the same size. A fixed palette of 16 colours covers the whole game, interface included. Characters
are small (about 20 px tall) but read instantly: a 1 px dark outline around every sprite, a clear
silhouette, two or three hue-shifted shades per material and light from one direction. Motion is
expressive and cheap: few frames, held poses, squash on landing. The recognizable thing is the
grid: one pixel size, one palette and one outline everywhere.

## Signature elements

1. **One pixel size on screen.** Every sprite, tile, glyph and interface line is drawn at the base
   resolution and scaled by the same integer. Nothing is drawn at 2× inside a 1× world, rotated or
   moved by a fraction of a pixel.
2. **A fixed palette of 16 colours** for everything: ink, paper, one accent, three signals, two
   4-step ramps (warm and cool) and two backdrop colours. Dimming and shadows are made with these
   colours (darker ramp steps, a 50% ink checker), never with alpha or blending.
3. **A 1 px ink outline on the outside of every sprite**, added by code or one consistent hand rule,
   with no outline on the backdrop. The outline, not the fill, separates the cast from the world.
4. **Hue-shifted ramps:** each step darker is also rotated 10–40° in hue toward purple or blue;
   each step lighter toward yellow. Shading uses 2–3 steps per material with light from the upper
   left.
5. **Few frames, big poses:** idle 2 frames, walk 4–6, action 3–5 with a held anticipation frame.
   Silhouette and timing carry the motion, not frame count.

## Readability and interface

- **Every word and number is live text** in a pixel font drawn on the same grid (a 3×5 caps font
  at minimum, 5×7 or larger for long dialogue). Never paint words into sprites or generated images.
- **Smallest text:** glyphs 5 px tall at the base resolution, shown at ×4 or more (20 px tall at
  720p, 30 px at 1080p). If the output scale would fall below ×3, raise the base resolution's text
  instead of shrinking the font.
- **Panels:** ink fill, a 1 px inner rule in a mid ramp step, paper text.
- **The accent has one job,** named by the game (in the example: what the player can act on now:
  the interaction marker, the focused button, the selected row). Nothing else uses it.
- **Signal colours** (good, bad, rare by default) appear only as chip fills with ink text, and each
  chip says its meaning in a word or a number, so colour is never the only cue.
- **Busy screens dim the world** with a 50% ink checker, never a translucent overlay.
- **Silhouette test:** every cast sprite, filled solid ink on the backdrop colour, must still say
  what it is and which way it faces.

## Colour structure

```yaml
colour-roles:
  ink:     outlines, panel fill, text on chips; the darkest colour, hue-shifted, never #000
  paper:   interface text, the brightest highlight
  accent:  ONE job, named by the game (what the player acts on now)
  signal:  [good, bad, rare]     # chips only; each chip names its meaning
  warm:    [warm-1 .. warm-4]    # one 4-step ramp: skin, wood, sand, cloth
  cool:    [cool-1 .. cool-4]    # one 4-step ramp: cloth, metal, water, cool shadows
  bg:      [bg-sky, bg-far]      # backdrop only; no outline, lowest chroma
colour-rules:
  - count(colours) == 16                         # the whole game, interface included
  - contrast(ink, paper) >= 7
  - contrast(ink, accent) >= 4.5                 # ink text on the accent
  - contrast(ink, signal-*) >= 4.5               # ink text on every chip
  - contrast(ink, bg-*) >= 4.5                   # outlines separate sprites from the backdrop
  - value(ink) <= 0.20 and chroma(ink) >= 0.05
  - value climbs along each ramp, and contrast(step n, step n+1) >= 1.3
  - hue shift between ramp steps is 8–40°; the darkest step is nearer 270° (purple) than the lightest
  - chroma(accent) >= 0.70 and its hue is >= 20° from every signal and ramp step
  - chroma(signal-*) >= 0.50
  - chroma(bg-*) <= 0.30 and below every signal
# value = HSV V; chroma = S × V; contrast = WCAG ratio
```

Variants change the count to a fixed 8, 24 or 32, decided once. `example-palette.gpl` is one instance (the demo's "market"); the
demo's "dusk" and "oasis" palettes pass the same rules with different hexes.

## Pitfalls

- **Mixed pixel scales.** A sprite drawn at 2×, a smoothly scaled portrait or a rotated item breaks
  the grid at once. Make a larger asset at true size instead of scaling a small one.
- **Non-integer scaling.** A 1366×768 window over a 320×180 base gives ×4.27: some pixel rows
  double, and with filtering on everything blurs. Scale by an integer and fill
  the remainder with a border.
- **Filtering left on.** One linear-filtered texture or canvas turns edges soft; check every import.
- **Sub-pixel jitter.** Positions kept as floats and drawn unrounded make sprites shimmer and
  outlines thicken by one pixel as the camera moves. Round the camera first, then each sprite.
- **Palette creep.** Generated sprites, gradients, fades and smooth text add hundreds of colours.
  Snap every asset to the palette and count the colours in a capture.
- **Outline drift.** Hand outlines end up 1 px here, 2 px there. One rule, applied by code.
- **Unreadable small text:** a 3×5 font below ×3 fails on handhelds.
- **Pillow shading** (lit centre, dark rim on every side): light comes from one direction.
- **Noise on tiles.** Single stray pixels flicker when scrolling; keep detail in clusters of 2+.

## Variations

- **Base resolution:** 384×216 (×5 to 1080p), 480×270 (×4) or 640×360 (×3) for more detail and
  denser interfaces; sprite sizes scale with it.
- **Palette size:** 8 colours (one ramp, very graphic) up to 32 (two extra ramps for a wider world).
- **Outline colour:** sel-out (outline in the darkest step of the sprite's own ramp instead of ink)
  for a softer read; keep ink on the interface.
- **Dither:** none by default; ordered 2×2 dither as a texture for sky or shade.

## Make it your own

A game in this look changes, from the example:

- the palette: every role re-chosen for its tone (the example palette is never shipped as is);
- the base resolution and the sprite sizes that follow from it;
- the pixel font (draw one or pick a licence-safe pixel font) and the panel shape;
- the setting, the cast's designs and their silhouettes;
- the accent's one job.

art-direction's critic checks these before approving the style guide.

## Evidence

Not yet built in a game. The demo's cast is generated, then palette-cleaned (recipe.md).

## Inspired by

Celeste (expressive motion at small sprite sizes), Shovel Knight (a strict limited palette),
Into the Breach (readability first on a tactics grid), Stardew Valley (warm, legible world and
interface at one pixel scale). Principles only: no characters, logos, layouts or trademarks.
