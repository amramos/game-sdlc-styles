---
id: pixel-sprites-lit-diorama
version: 1
name: Pixel sprites in a lit diorama
---

# Pixel sprites in a lit diorama

## The look

Small, crisp pixel-art people stand on a real 3D set lit like a stage. The set is a diorama:
toon-shaded, brushy-grained wood, stone and plaster built from simple pieces, a painted backdrop on
a far curve, fog that softens the distance, an animated banded surface beyond the set. A high
camera looks down at about 20°, and tilt-shift blurs the top and bottom of the frame, so the scene
reads as a miniature on a table. Text floats in the world beside what it names, like stage
captions. The tension: chunky, nearest-filtered pixels against smooth bloom, fog
and depth of field.

## Signature elements

1. **Pixel sprites as camera-facing billboards:** nearest filtering, no mipmaps, alpha-tested
   cut-outs, yaw-only facing, a soft round contact shadow under each. They are lit by a tint, not by
   the scene's lights, so their pixels stay clean.
2. **Tilt-shift and bloom in post:** a narrow band in focus, and only light sources bloom.
3. **Toon-shaded, grained set:** a stepped 4-band light ramp and brushy grain on every set material;
   never smooth plastic.
4. **Atmospheric depth:** a painted backdrop, fog, faint light shafts and drifting
   mist.
5. **The cast outshines the set:** sprites are more saturated than anything built.

## Readability and interface

- **Every word is live text:** names in small capitals over an italic status line, on a soft
  `plate` backing at 85%, so they read over pale tiles and sky. Smallest size 16 px at 720p.
- **Captions never overlap each other or cover any sprite;** placed by priority (selected person,
  then the stall in focus), they slide up or aside. Past four, the rest shrink to a short name.
- **Captions carry hints and consequences,** not only names ("pays double before the rain").
- **Every interactive thing has a generous 3D hit volume;** the caption is never the only target.
- **The accent has one job:** what the player can act on now. It colours the selection ring (an
  additive circle on the ground) and the selected name, and nothing else.
- **Panels** are a `plate` gradient with a thin left rule in `ink`.
- **Close-ups** hide captions, add letterbox bars and a lower-third title card.

## Colour structure

```yaml
colour-roles:
  sky:          the painted backdrop's upper colour
  fog:          fog, far haze and the backdrop's horizon
  key:          the main light (sun, moon, lamp); no rule: the lighting scheme is the game's
  fill-sky:     hemisphere fill from above; no rule
  fill-ground:  hemisphere fill from below; also the grade's shadow tint; no rule
  rim:          separation light from behind; no rule
  glow:         [light sources]   # lamp cores, lit windows; the only things that bloom
  ground:       the floor the cast stands on
  material:     [by material]     # plaster, roof, wood, stone, leaf, cloth… as the set needs
  outline:      the sprites' single dark outline; also contact shadows
  tint:         the scene light as the sprites receive it
  sprite:       [cast colours]    # skin, hair, cloth…
  accent:       ONE job: what the player can act on now
  signal:       [danger, info, …] # text on plate; each also has a symbol and a word
  ink:          text
  plate:        text shadow and panel
colour-rules:
  - contrast(ink, plate) >= 7
  - contrast(accent, signal-*, plate) >= 4.5
  - contrast(ink, accent; plate at 85% over white) >= 4.5   # caption backing over the palest surface
  - chroma(sky, fog, ground, material-*) <= 0.40
  - max(chroma(sprite-*)) >= max(chroma(ground, material-*)) + 0.10
  - value(ground, material-*) <= 0.80
  - value(glow-*) >= 0.90 and min(value(glow-*)) >= max(value(ground, material-*)) + 0.10
  - value(outline) <= 0.22 and value(ground) - value(outline) >= 0.20
  - contrast(outline, fog) >= 3
  - value(tint) >= 0.70 and chroma(tint) <= 0.25
  - chroma(accent) >= 0.5 and chroma(accent) >= max(chroma(ground, material-*)) + 0.20
  - huedist(accent, any ground, material-*, signal-*) >= 30   # skip roles with chroma < 0.1
# value = HSV V; chroma = S × V; contrast = WCAG ratio; huedist = HSV hue difference in degrees
```

The set's value ceiling leaves headroom so only `glow-*` blooms; its chroma ceiling keeps the cast
in front; `contrast(outline, fog)` keeps silhouettes readable at range. How dark the scene is and
where warmth goes belong to the game.
`example-palette.gpl` (a bright day) is one instance; `demo.html` also has a night palette with a
single warm light that passes the same rules.

## Pitfalls

- **Captions that only describe read as tooltips;** add a consequence.
- **Text-only click targets are finicky.** Add invisible 3D hit volumes, about 1.5 m across.
- **Pips alone are hard to read** at this size; pair them with a short phrase or number.
- **Captions crowd** past about four live in one view; set a cap and a priority order.
- **An eased camera must reliably come home.** Give every close-up a timeout and an escape key.
- **Low-key scenes swallow distant props.** Give far things their own light or a silhouette against
  a lighter haze band.
- **Reserving a hue for one meaning costs signal elsewhere.** If only the accent may be warm, fire
  and danger lose their natural colour; decide which matters more.
- **Big untextured surfaces read as holes** in a dark scene; give them grain, windows or edge light.
- **Detailed bought models can hide the play surface** from a high camera; use simple pieces.
- **Sprites lit by scene lights** band across their pixels; tint them instead.
- **Linear filtering or mipmaps** smear the pixels into mush (the `dont` frame).
- **Camera yaw beyond about ±30° from the home view** shows that sprites are flat cards.
- **The post stack is heavy without a graphics card;** offer a low setting (no bloom, half-resolution
  tilt-shift).

## Variations

Lighting schemes (each a palette plus light ratios, under the same rules):

- **One warm light in a cold night:** cold key and rim, dark fill, a single warm point light;
  sprites near it tint toward its colour.
- **Bright daylight:** warm-white sun about 3:1 over fill, crisp shadows, light vignette.
- **Overcast:** key and fill near 1:1, soft shadows, low grade, thicker fog.
- **Golden hour:** low warm key (15–25°), long shadows, cool fill, warm haze.

Other variations:

- **Pixel-art set too:** render the 3D set at a low resolution and upscale with nearest filtering,
  keeping bloom and tilt-shift on top.
- **Larger sprites** (32–64 px tall) for close-up-heavy games.
- **Dollhouse cutaway:** remove the near wall of every building so rooms read from the fixed camera.

## Make it your own

A game in this style changes, from the example:

- the palette and the lighting scheme (the example palettes are never shipped as is);
- the sprite size, proportions and outline treatment;
- the set's kit of pieces, its signature set piece and its animated surface (grass, sand, snow,
  a cloud layer);
- the caption typography and the accent's job.

## Evidence

Built in a fixed-stage web prototype; unshipped. Generated sprites and value-mapped surfaces work (recipe.md).

## Inspired by

Octopath Traveler and Triangle Strategy (pixel sprites in lit 3D dioramas); Final Fantasy Tactics
(sprites on a 3D board); tilt-shift miniature photography; painted theatre backdrops. Principles
only: no characters, layouts or logos from them.
