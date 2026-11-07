---
id: toybox-low-poly
version: 1
name: Toybox low-poly
---

# Toybox low-poly

## The look

Flat-shaded low-poly 3D that reads as painted wooden toys. Every object is a few chunky,
chamfered primitives (cylinders of 6–10 sides, half-spheres of 3–4 rings, boxes with a 45° bevel),
one flat colour per material, no textures. Light is soft: a strong sky fill, one gentle sun, cool
shadows never darker than mid-value, a soft dark band where things meet the ground. The palette is
pastel by rule, with one saturated accent for what the player can act on. From a high camera with light
tilt-shift, the world looks small, calm and tidy: things snap to a grid and land with a
bounce.

## Signature elements

1. **Chunky primitives with visible facets:** per-face normals, 6–10 sides on round things, a 45°
   chamfer on every box edge. Proportions are stubby: heights 0.8–1.5× widths, details no smaller
   than 1/10 of a grid tile.
2. **One flat colour per material,** chosen from named roles. Variety comes from material, value
   and shape, never from texture or noise.
3. **Soft light, coloured shadow:** sky fill to sun about 1.4:1 in intensity, so lit faces are about
   1.7× the brightness of shadowed ones; the shadow side is tinted by the shadow role, never black.
4. **Ground contact:** a darkened base on every object (baked vertex shading, 0.72 at the ground to
   1.0 at half a tile up) plus a soft round contact blob. Things look set down, not floating.
5. **One loud accent:** the only saturated colour in the frame, used for interaction alone: the
   cursor ring, the placement ghost's tint, markers over things the player can use.

## Readability and interface

- **Every word and number is live text,** drawn by the engine.
- **The interface is a toy too:** rounded panels (radius 12–16 px at 720p), a 3 px ink border and a
  solid 4 px drop in the shadow role, no blur and no glass. Weight 700–800 for everything; a thin
  font vanishes over a pastel scene.
- **Smallest readable size:** 16 px at 720p, 24 px at 1080p, costs and counters included.
- **Never truncate a name the player chooses by.** Card and menu names wrap to two lines, with that
  height reserved, or the cards widen; no ellipsis at worst-case content.
- **Ink outline on every panel and chip.** Pastel panels over a pastel world measure under 1.5:1;
  the border, not the fill, separates them.
- **Signal colours** (ok, warning, blocked, info) live only on chips, and each chip carries a symbol
  and a word.
- **Interactive versus decor:** whatever the player can act on gets the accent marker or ring;
  decor never uses the accent, never bobs and never highlights.
- **One placement at a time:** while building, show the ghost, its ring, its cost and the reason it
  can't go there. The build menu hides while nothing is being placed.

## Colour structure

```yaml
colour-roles:
  ink:        outlines and text on the interface
  paper:      the interface material
  sky-top:    upper sky; tints the hemisphere fill
  sky-low:    horizon; fog colour
  ground:     the field everything stands on
  path:       built paths and plazas; must read on the ground
  shadow:     shadow tint: hemisphere ground colour, contact blobs, panel drop
  accent:     ONE job: what the player can act on now
  signal:     [ok, warn, blocked, info]   # chips only; each also says its kind
  material:   [by material]   # cap, stem, wood, leaf, foliage, stone, cloth… as the setting needs
colour-rules:
  - contrast(ink, paper) >= 7
  - contrast(ink, signal-*) >= 4.5
  - chroma(material-*, ground, path, sky-*, paper) <= 0.45
  - 0.55 <= value(material-*, ground, path) <= 0.97
  - value(sky-*) >= 0.75
  - max(value(material-*)) - min(value(material-*)) >= 0.25
  - chroma(accent) >= 0.6 and chroma(accent) >= max(chroma(material-*)) + 0.2
  - huedist(accent, any material-*, signal-*, ground, path) >= 30   # skip roles with chroma < 0.1
  - 0.35 <= value(shadow) <= 0.65 and chroma(shadow) <= 0.30
  - value(ground) - value(shadow) >= 0.20
  - contrast(path, ground) >= 1.4
# value = HSV V; chroma = S × V; contrast = WCAG ratio; huedist = HSV hue difference in degrees
```

The chroma ceiling keeps it pastel; the value spread stops it turning to mush. `example-palette.gpl` (autumn) is one instance;
`demo.html` also has spring and winter palettes that fill the same roles and pass the same rules.

## Pitfalls

- **Everything the same pastel.** All materials at value 0.85–0.95 makes a frame that reads as fog.
  Keep the value spread of at least 0.25, and give buildings and ground different values, not only
  different hues.
- **Shadow too dark.** A sun much stronger than the fill, or a black hemisphere ground, gives hard
  black pools and the toys turn harsh. Keep the shadow role at value 0.35–0.65 and the light ratio.
- **Too many polygons.** Smooth spheres and 32-sided cylinders read as plastic or clay, not painted
  wood. Above about 800 triangles for a house, the facets stop showing.
- **Z-fighting on flat tiles.** Paths, decals and floor tiles coplanar with the ground flicker as the
  camera moves. Raise them 0.02–0.05 tile above it, and give decals a polygon offset.
- **Thin interface.** Light fonts, 1 px borders and translucent panels disappear against a bright
  pastel scene. Use the weight, border and drop above.
- **Interactive things look like decor.** If a villager, a building site and a fence share the same
  treatment, the player can't tell what to click. Only interactive things get the accent marker.
- **A tooltip over the status chips.** A long tooltip anchored near the top right covers the last
  chip. Place it below the chip column, or beside the hovered item on the side away from the HUD.
- **Tilt-shift everywhere.** A strong blur on the whole frame hides the interface's targets and
  looks like a filter. Keep the focus band on the play area and drop the blur in close-ups.

## Variations

- **Seasons:** swap the material roles per season (autumn caps and leaf piles; spring petals;
  winter snow ground with a darker earth path) and keep the rules.
- **Night:** lower sky value to 0.5, keep materials pastel, add a `glow` role for emissive windows
  at least 30° of hue from the accent. This breaks the sky rule on purpose; write the changed rule
  into the game's guide.
- **No tilt-shift:** for games played close to the camera, or with lots of interface over the scene.

## Make it your own

A game in this style changes, from the example:

- the palette: every role re-chosen for its tone (the example palette is never shipped as is);
- the primitive kit: which shapes make a building, a creature, a tree, and their proportions;
- the interface: font, panel radius, and the accent's job;
- the setting, its materials and its one signature object.

art-direction's critic checks these four before approving the style guide.

## Evidence

Not yet built in a game. Written from established technique; demo.html renders the core.

## Inspired by

Townscaper (calm building, things settling into place); Islanders (pastel palette, clean low-poly
shapes); Monument Valley (soft gradients, tidy geometry); Mini Motorways (one loud colour against a
calm field). Principles only: no buildings, layouts, logos or trademarks from them.
