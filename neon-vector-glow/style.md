---
id: neon-vector-glow
version: 1
name: Neon vector glow
---

# Neon vector glow

## The look

Glowing lines and simple geometric shapes on a near-black field, like neon tubes or a vector
arcade monitor. Every gameplay object is an outline, never a filled sprite: a near-white core, a
coloured line, and a wide soft bloom that lights the dark around it. Light adds up: overlapping
glows brighten toward white. Kills throw dense bursts of short sparks, and a dim background grid
bends away from every impact and springs back. Colour carries the meaning: the player owns one hue, each enemy class owns another plus its own silhouette, and danger
owns a hue nothing else may use.

## Signature elements

1. **Line, not fill.** Every gameplay object is 1–4 strokes, about 4 px at 1080p, with a
   near-white centre. Solid fills only on tiny things (shot centres, dots).
2. **Real bloom on near-black.** The lines are blurred at three radii and added back: a tight
   coloured halo, a mid glow, and a wide bloom that tints the void. The background stays at HSV
   value ≤ 0.06 so every glow reads.
3. **The cast glows wide, the HUD tight.** HUD text gets a glow of a few pixels that never blurs a
   digit; the grid and the background never glow.
4. **The living grid.** A spring mesh behind the action dents outward on kills and inward on
   implosions, then settles in about a second.
5. **Spark bursts.** Kills burst into 30–120 short line-sparks in the enemy's colour that fade in
   under a second.

## Readability and interface

- **Silhouette first, colour second.** Each enemy class has a shape no other class shares (an open
  triangle, a cluster of rings, a pair of brackets). Colour confirms; it never identifies alone.
- **Draw order is threat order:** background, grid, particles, pickups, allies, player shots,
  enemies, player, danger (enemy shots and hazard zones) on top, then the HUD.
- **Danger always reads:** enemy shots get a 6 px rim (at 1080p) in the void colour, cut after
  the bloom, so they read through sparks and glow.
- **The HUD has no panels:** glowing live text and icons straight on the void, over a soft void
  fade from the screen edge so the world's bloom never reaches digits. Lives are the player's
  own shape. Smallest text 24 px at 1080p. Numbers in a monospace face with tabular digits so a
  rising score doesn't jitter.
- **Focus** in menus: a 2 px border in the HUD ink plus four corner brackets 8–12 px outside the
  frame. Never the player's colour.
- **Choices pause the fight** and dim it under the void colour at about 70%.

## Colour structure

```yaml
colour-roles:
  void:      the background; near-black
  grid:      the background grid; the only other background colour
  player:    the player's ship, shots and life icons; unique
  core:      what the player defends or allies; optional
  pickup:    everything the player collects
  danger:    enemy shots and hazard zones only; never debris, never decoration
  enemy:     [2–5 classes]   # each its own hue AND its own silhouette
  hud-ink:   interface text, outlines and focus
  hud-panel: interface panel fill
colour-rules:
  - value(void) <= 0.06
  - 0.15 <= value(grid) <= 0.35 and chroma(grid) <= 0.25
  - chroma(player, core, pickup, danger, enemy-*) >= 0.6 and value(...) >= 0.85
  - contrast(player, void) >= 7
  - contrast(every gameplay role, void) >= 4.5
  - contrast(every gameplay role, grid) >= 3
  - hue(enemy-*, danger) >= 60° from hue(player) and hue(core)
  - hue(enemy-*) pairwise >= 40°
  - hue(danger) >= 30° from every enemy-* and pickup
  - hue(pickup) >= 30° from every enemy-*
  - hue(core) >= 30° from hue(player)
  - contrast(hud-ink, hud-panel) >= 12 and contrast(hud-ink, void) >= 12
  - chroma(hud-ink) <= 0.15
# value = HSV V; chroma = S × V; contrast = WCAG ratio; hue distance on the HSV wheel
```

The hue wheel is a budget: friends take one region, foes another, danger sits apart. Past four
enemy classes the 40° gaps run out; add silhouettes, not hues.
`example-palette.gpl` is one instance, not the default; `demo.html` holds two more.

## Pitfalls

- **Bloom washes everything out.** Blooming the whole frame turns the grid, the HUD and the
  background into haze. Bloom only the gameplay lines, drawn on their own layer.
- **Bloom swallows small targets.** A small, bright shape (a pickup, an enemy shot) blooms into a
  blob. Lower its bloom, and cut a void rim around enemy shots after the bloom pass.
- **Particle overload hides threats.** Cap live particles, draw them under enemies and danger,
  below 0.8 alpha, never in the danger hue.
- **Colour-only identity fails colour-blind players** and fails everyone in a white-hot
  cluster. Silhouette must carry identity alone.
- **Overlap burns to white.** Additive cores on top of each other lose hue. Add the bloom; draw
  the core lines with normal blending.
- **Thin lines vanish at low resolution.** Gameplay cores never go below 2 px at the output
  resolution.
- **The UI drowns in glow.** A HUD under the world's wide bloom smears its digits.
- **A bright background kills the look.** Above value 0.06 the halos lose their edge and the scene
  turns grey.

## Variations

- **Mono-glow:** one hue for friends, one for foes, silhouettes doing the rest; for few kinds.
- **Wireframe 3D:** the same line and halo rules on 3D edges, depth shown by line brightness (far
  lines dimmer).
- **Grid as level:** the grid is the floor or track and also pulses on the music.
- **Warm field:** a deep red or brown void instead of blue-black, still under the value ceiling.

## Make it your own

A game in this style changes, from the example:

- the palette: every role re-chosen under the rules (the example palette is never shipped as is);
- the silhouettes of the player and every enemy class;
- the grid's spacing, shape (square, hexagonal, polar rings, a tunnel) and how it reacts;
- the HUD's fonts and panel shapes.

## Accessibility

- **At most three full-screen flashes per second**, and a full-screen flash is an overlay of at most
  15% opacity. Any bright change covering more than about a tenth of the screen counts as a flash.
- **No strobing:** nothing flickers between bright and dark faster than 3 Hz. Invulnerability
  blinks at no more than 4 Hz and only on the small player shape.
- **Reduced flash** option: removes full-screen flashes and replaces them with a pulse on the
  affected object.
- **Reduced motion** option, on by default when the system asks for it: no screen shake, grid warp
  at 30%, no camera roll.
- **A colour-blind check:** play a level with the image in greyscale; every class must still be
  told apart.

## Evidence

Not yet built in a game; demo.html renders the core. Halos drawn as wider, fainter strokes read
as outlines, not light; blurred bloom at three radii reads as neon.

## Inspired by

Vector arcade displays; Geometry Wars (the warping grid, spark bursts); Rez (lines on a void,
music-led effects); Thumper (a glowing track rushing into the screen); Tempest 4000 (vector shapes
on a tube). Principles only: no ship or enemy designs, layouts, logos or trademarks from them.
