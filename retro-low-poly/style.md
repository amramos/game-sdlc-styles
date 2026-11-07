---
id: retro-low-poly
version: 1
name: Retro low-poly
---

# Retro low-poly

## The look

Late-90s console 3D, made on purpose. The scene renders at 240 lines and is scaled up with no
smoothing, so edges stair-step. Vertices snap to that coarse grid and hop as the camera moves;
textures are mapped without perspective correction, so they swim across big polygons. Objects are a
few chunky primitives (six- and eight-sided cylinders, boxes) in tiny nearest-filtered textures.
Light is computed per vertex, falling across faces in soft triangles. Linear fog closes the world
at a short distance. A 4×4 ordered dither and 5-bit colour lie over the frame; the interface sits on
top at full resolution. The look carries any mood: bright racers, cheerful platformers, comedies and
horror all used it. Palette and lighting decide which.

## Signature elements

1. **Low internal resolution, vertex snapping and affine texture warping together.** Without the
   jitter and the swim it is only low-poly.
2. **Small, nearest-filtered textures** at 32–64 px, quantised to 5 bits per channel, tiled by world
   size so every surface keeps the same texel density.
3. **Per-vertex light:** one ambient term, one key and up to a few local lights, all evaluated at
   vertices and interpolated. Big faces are split so light has somewhere to land.
4. **Ordered dither and 5-bit colour** over the final frame (31 levels per channel).
5. **Short linear fog** that ends the world. Distance is part of the set, and it caps the scene budget.

## Readability and interface

- **Every word and number is live text** at full resolution, never drawn into the low-res, dithered
  image. Dither and quantisation destroy small type.
- **Panels are solid** `panel` with an `ink` border (2 px at 720p) and a hard 3 px offset shadow;
  no blur, glass or gradients. Small radius (0–4 px) matches the pixel edges.
- **Smallest readable size:** 16 px at 720p (24 px at 1080p). Dialogue 20 px at 720p.
- **Never truncate.** Lists and order names wrap; panels grow with their content.
- **Interactive versus decor:** whatever the player can use gets an additive `accent` pulse
  (`0.25 + 0.2 sin 6t`) on its surfaces and an `accent`-bordered prompt; nothing else uses the accent.
- **World prompts never cover a readable world sign:** offset them below or above it.
- **Make targets bigger than feels right:** at least 12 low-res pixels on their short side at play
  distance.
- **Dragging:** snap to the nearest valid slot with a see-through preview; mark valid targets and
  react to invalid drops. Silent no-ops read as broken in a fuzzy image.

## Colour structure

```yaml
colour-roles:
  ink:       interface text and borders
  panel:     interface fill (full resolution, outside the low-res image)
  key:       the main light: sun, ceiling tubes, a hanging lamp, a torch
  ambient:   the fill every vertex gets; sets how dark the unlit side goes
  fog:       linear fog and the far background; the world ends in it
  sky:       the backdrop above the horizon, fading into fog
  glow:      [by source]    # emissive surfaces and the local lights they cast: signs, screens, lamps
  accent:    ONE job: what the player can use now (highlight pulse, prompts)
  signal:    [by kind]      # interface chips only; each also says its kind in a word or symbol
  material:  [by material]  # texture base colours: floor, wall, wood, metal, cloth, skin, paint…
colour-rules:
  - contrast(ink, panel) >= 7
  - contrast(ink, signal-*) >= 4.5
  - max(value(material-*)) - min(value(material-*)) >= 0.35
  - every pair of material-* differs by >= 0.08 in value, or >= 0.15 in chroma, or >= 30° in hue with both chroma >= 0.1
  - abs(value(fog) - mean(value(material-*))) >= 0.25
  - contrast(sky, fog) <= 2.0
  - value(key) >= 0.85 and chroma(key) <= 0.25
  - value(ambient) >= 0.12 and value(key) - value(ambient) >= 0.25
  - chroma(accent) >= 0.55 and contrast(accent, fog) >= 3
  - huedist(accent, any material-*, glow-*, signal-*) >= 30   # skip roles with chroma < 0.1
  - value(glow-*) >= 0.85
# value = HSV V; chroma = S × V; contrast = WCAG ratio; huedist = HSV hue difference in degrees
```

The rules hold for any mood: materials stay apart after 31-level quantisation, fog reads as
distance (light haze or dark fog), and the key stays pale enough that textures keep their colour.
`example-palette.gpl` (sunny afternoon) is one instance; `demo.html` adds a late-night neon palette
with the same materials: light, fog and glow carry the mood.

## Pitfalls

- **Dim scenes swallow small targets.** With dark ambient, small objects vanish into the dither.
  Raise the ambient, give interactive pieces their own light, or enlarge them.
- **Look-alike states vanish.** A subtle tint is one or two quantisation steps. Change shape or
  position, or add a symbol.
- **Smooth anything and it is gone.** Mipmaps, linear filtering, anti-aliasing or a high render
  height turn it into plain low-poly.
- **Too much warp.** Split faces and decals every 0.5 m: some swim, never a fold.
- **Snapped surfaces cut through.** Lift decals 4–5 cm; never stack planes closely.
- **Jitter on small, close geometry** shakes at rest. Keep near props chunky; still the camera while
  the player aims.
- **Camera moves the targets.** A staged camera move shifts what the player was about to click.
  Lock input during it, or return to exactly the same framing.
- **A flat page breaks the spell.** A sub-view in plain 2D drops the look; draw it in the same
  renderer, or as an object in the scene.
- **Half-built sets.** Build wherever the camera can look, or hide the gap with fog or framing.
- **Text in the 3D layer** dies under dither; world signs use a few large letters.

## Variations

- **Lighting schemes:** bright daylight (pale fog 30–60 m, high ambient); overcast (grey fog, small
  key–ambient gap); one warm lamp in a dark room (fog 4–9 m, dark ambient); neon and fluorescent
  night (dark fog, coloured `glow` lights); a handheld torch as the key.
- **Push it:** 180 or 160 lines, a coarser snap (grid ÷ 2), 4-bit textures, a CRT curve and scanlines.
- **Softer:** 360 lines, dither only, no snap; reads as a modern homage.
- **Glitch effects:** row tearing, chromatic split, frame freezes; short and rare.
- **Aged or tinted** versions of a scene from one term in the post pass.

## Make it your own

A game in this style changes, from the example:

- the palette and the lighting scheme, chosen for the game's tone (never the example's as is);
- the render height and how hard the snap and warp are pushed;
- the primitive kit and texture set: the shapes and surfaces of its setting;
- the interface: font, panel shape and the accent's job;
- the framing and its camera values.

art-direction's critic checks these five before approving the style guide.

## Evidence

Built in a web prototype (first-person framing); not yet in a shipped game.

## Inspired by

Original PlayStation-era 3D (vertex jitter, warping textures, 15-bit colour, short fog); Crash
Bandicoot and Spyro the Dragon (bright worlds in the same limits); Silent Hill (fog as the edge of the
world); modern retro-3D indie horror and comedy. Principles only: no characters, layouts, logos or
trademarks from them.
