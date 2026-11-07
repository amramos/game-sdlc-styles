---
id: tabletop-diorama
version: 1
name: Tabletop diorama
---

# Tabletop diorama

## The look

A handmade miniature sits on a real table, and the game happens on it. Every piece is a carved,
painted wooden toy: chunky low-poly shapes with uneven knife facets, matte folk-art paint over
visible grain, bare wood where a piece is unfinished. Full-size objects lie around the base (a cup,
a tool, paper cards), so the scale reads at once. The camera looks across the table as if seated
at it. Real lights cast real shadows; tilt-shift, a vignette and a grade make the frame read as a
small thing seen up close. Text lives on paper cards and painted signs.

## Signature elements

1. **Carved and painted wood, nothing else.** Flat-shaded pieces with jittered facets, one matte
   paint per part, grain multiplied over every surface. Bare wood means unfinished or unknown.
2. **One figure body, many characters.** The same carved figurine on a round base, repainted in
   bands and told apart by one silhouette piece: a hat, an apron, a basket.
3. **A real light over a real table.** One key, a weaker fill, soft shadows, and a room that falls
   away into fog past the table's edge.
4. **The miniature lens.** Tilt-shift outside a focus band, vignette, a grade toward the key's
   colour, bloom only on light sources.
5. **Interface as objects.** Cards, tokens, dials, signs and rings; no glass panels or HUD bars.

## Readability and interface

- **Every word and number is live text**, on paper cards in screen space or on signs inside the
  focus band.
- **Paper, not panels:** `paper` with `ink` text, a 1–3° tilt, a soft shadow, no border. Body text
  at least 16 px at 720p.
- **Never truncate what the player chooses by;** reserve height for the worst case.
- **Tokens over overlays:** a dial or badge on the piece reads at low resolution better than a tint
  or a floating bar.
- **Click a piece, then its target.** Select-then-place works on small pieces; dragging needs
  visible drop targets and a visible result on every drop.
- **The `accent` ring** marks what can be acted on now; decor never takes it.
- **Dramatic moments are lighting:** dim the room, slow the text, let the key flicker.

## Colour structure

```yaml
colour-roles:
  room:       everything past the table: background and fog
  table:      the surface the miniature stands on (wood, oilcloth, felt)
  wood-bare:  unpainted carved wood; also "unfinished" or "unknown"
  paint:      [by part]   # folk-art paints the setting needs: red, ochre, blue, green, cream…
  key:        the key light's colour
  fill:       the fill light's colour
  paper:      cards and slips
  ink:        text on paper
  signal:     [warn, ok, …]   # inked stamps on paper only; each also says its word
  accent:     ONE job: what the player can act on now; unlit
colour-rules:
  - contrast(ink, paper) >= 7
  - contrast(signal-*, paper) >= 4.5
  - 0.15 <= chroma(paint-*) <= 0.60              # matte paint: never neon, never grey
  - 0.30 <= value(paint-*) <= 0.92
  - max(value(paint-*)) - min(value(paint-*)) >= 0.30
  - 0.15 <= chroma(wood-bare) <= 0.40 and 0.60 <= value(wood-bare) <= 0.92
  - chroma(table) <= 0.35 and max(chroma(paint-*)) >= chroma(table) + 0.20   # the table stays quieter
  - 0.20 <= value(table) <= 0.80
  - contrast(wood-bare, table) >= 1.5
  - each paint-*: contrast(paint, table) >= 1.25 or huedist(paint, table) >= 40
  - abs(value(room) - value(table)) >= 0.10     # the table's edge reads
  - chroma(room) <= 0.25
  - value(key) >= 0.90 and chroma(key) <= 0.45  # tinted light, so the paints survive it
  - chroma(fill) <= 0.40
  - value(paper) >= 0.80 and chroma(paper) <= 0.30
  - chroma(accent) >= max(chroma(paint-*)) + 0.10
  - huedist(accent, table) >= 30 and huedist(accent, paint-*) >= 20   # skip paints with chroma < 0.10
# value = HSV V; chroma = S × V; contrast = WCAG ratio; huedist = HSV hue difference in degrees
```

The rules hold under any lighting. `example-palette.gpl` is a sunny kitchen; `demo.html` adds an
evening candlelight and a cool morning window that pass the same rules.

## Pitfalls

- **Small pieces are hard to target.** Hit areas at least as large as the visible piece; drop
  targets as rings on the table, not screen distance to a model's base.
- **Silent drops** lose trust fast. Every placement shows a result.
- **A shape's meaning fades after the tutorial.** Keep it on the piece (a badge, a dial, a band);
  captions and unlabelled letters on tokens are never learned.
- **Grey faceted clumps read as rocks.** Smoke or a cloud in grey low-poly reads as stone; lift it
  on a stand and paint it.
- **Too much paper reads as a manual.** Keep instruction cards rare.
- **Tiled textures show seams.** Crop generated textures and use plain repeat; mirrored repeat on
  non-power-of-two images fails on some renderers.
- **One NaN pixel blacks out the frame** through bloom. Clamp colour before bloom.
- **The far edge falls into darkness** under a pool of light. Keep important pieces in the cone,
  or add a practical light behind.
- **Tall pieces hide targets behind them.** Put rings on the camera side.
- **What the player must find goes on the table,** lit and pulsing where it sits.
- **Loudness must match stakes.** The deadliest threat gets the most visible piece.
- **Typed-out text slows play.** A click finishes the line.
- **Complex objects melt in text-to-3D** (rope, lattices, spokes). Concept image first, then
  image-to-3D, or build them from primitives.

## Variations

Lighting schemes keep the colour rules and change `room`, `key`, `fill` and the post.

- **Sunny kitchen:** warm window key from one side, cool sky fill, a light blurred room, light
  vignette.
- **Evening candlelight:** a warm spot from above, a candle, a near-black room, heavy vignette,
  bloom on flame and windows. Hushed.
- **Cool morning window:** pale blue-white key low from the side, warm bounce fill, long shadows.
- **Afternoon toy room:** high warm key, strong fill, paints near the chroma limit. Playful.
- **Moonlit:** a cold key and one candle; bare wood reads as bone. Eerie.
- **Clay or felt:** swap the grain for a fingerprinted or fibrous texture.
- **A new table per chapter:** another cloth, surface or lamp marks a new place.

## Make it your own

A game in this style changes, from the example:

- the lighting scheme and the palette, every role re-chosen;
- the table, the full-size objects around the base, and what bare wood means;
- the figurine's proportions and its silhouette pieces;
- the interface objects that carry the game's information, and the fonts.

art-direction's critic checks these four before approving the style guide.

## Evidence

Built in a web prototype with image-to-3D models repainted part by part and procedural tiling
materials for the table and street; not yet in a shipped game.

## Inspired by

Folk-art carved toys and painted figurines; model dioramas and tabletop war-gaming; tilt-shift
miniature photography; candlelit genre painting (for the evening scheme); Inscryption (a whole game
at one table). Principles only: no characters, layouts, logos or trademarks from them.
