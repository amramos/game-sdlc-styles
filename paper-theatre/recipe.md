# Recipe: the core, in any framing and engine

Units: the proscenium opening is 7.8 × 5.0 units; scale everything together. Pixel sizes are at
720p; multiply by 1.5 for 1080p. demo.html builds every value below.

## The stage box, back to front

| Layer | Distance behind the frame | Size (w × h) | Notes |
|---|---|---|---|
| Back cloth | 14.5 | 20 × 7.1 | one printed sheet, not cut; covers the opening's view at that depth plus 10% |
| Ground row, far | 13 | 20 × 2.6 | tree-line or skyline top edge; tallest |
| Ground row, mid | 11 | 20 × 1.9 | rounded masses |
| Ground row, near | 9 | 20 × 1.0 | low fringe (grass, rubble, a fence) |
| Wings | 6.5 and 2.5 | 2.5 × 5.6 | two pairs at the sides, turned 11–14° toward the centre |
| Cast and props | 5.5–7.5 | figure 2.0 tall, animal 1.5, cart-sized prop 1.95 | spread across the width; no two closer than 1.2 |
| Border (valance) | 0.7 | 8.2 × 0.85 | hangs 0.65 into the opening, scalloped |
| Frame | 0 | 11.6 × 6.5, opening 7.8 × 5.0 | pillars 1.9 wide, header 0.6, base band 0.9; top corners of the opening rounded 0.45 |
| House wall | 0.1 | fills the view, with the opening cut | `house`; hides the set's sides |
| Floor | from the frame back to 15 | 20 wide, top at the opening's bottom edge | planks 0.3 wide running away from the audience |
| Footlight hoods | 0.35 | 9 hoods, 0.42 × 0.1 × 0.16 | dark metal along the stage lip |

Each ground row is shorter than the one behind it, so every row's top edge shows over the next.

## Cut-out construction

- Front: one plane with the print as a texture with alpha; alpha test at 0.5 (no blending, so
  sorting never breaks); roughness 0.9, metalness 0.
- Paper border: under the art, the silhouette filled and stroked 0.06 unit wide (4–5 px) in
  `paper`, round joins, so overlapping parts share one cut line.
- Card back: a second plane 0.018 behind, `card`, its silhouette grown by the border plus 0.025 and
  offset 0.02 down and away from the key (an edge of 1.5–2 px).
- Shadows: both planes cast, through a depth pass alpha-tested on the same textures, rendered
  double-sided (a plane seen from the light's side otherwise casts nothing).
- Turn every cut-out 5–15° off the camera's axis (wings 11–14°), so the edge and the light falloff
  read. Never edge-on.
- Bottom edge sunk into the floor (the paper margin below the feet goes through it, like a slot).
- Held: a slide along the floor from the wings (radius 0.012), a wire from the fly (radius 0.008)
  or a card foot. One method per kind of piece.
- Texture density: 200 px per unit for figures and props (about 2.7× their screen size), 100–120
  for rows, wings, frame and back cloth; mipmaps on.

## Engraving

- Outlines: 0.02 unit (about 1.4 px), `ink`, round joins. Details (eyes, folds, planks, bark):
  0.012–0.03.
- Hatching: parallel `ink` lines 0.011 unit wide (0.8 px) every 0.045 unit (3–3.5 px), at 0.8
  opacity over the tint. Small dense textures (weave, bark, metal) every 0.03–0.035; large calm
  areas (sky, pale bark, the far row) every 0.06–0.08.
- Cross-hatching for shadowed or dark materials: a second set at +80–90° (+25° on a night sky).
- Shading: fade the hatching's opacity across each piece toward the lit side, from 1.0 at the
  shadow corner to 0.2–0.3 at the lit corner; 0 at the lit corner for skin and paper-coloured
  areas. Light from the upper left, the same on every print.
- Sky: horizontal hatching at 0.7 opacity, full at the top, fading to 0.1 at 70% of its height.
- The frame: hatching at 0.55 opacity, double rules in `paper` and `ink` around its edge and the
  opening, fluting on the pillars.
- Darker schemes multiply the hatch spacing by 0.7–0.75 and add the cross-set to the sky. Tints
  stay within the colour rules.

## Light, as ratios

With tone mapping off, lit paper on a front-facing cut-out lands at 0.9–1.0 of its colour in a
bright scheme. Tune each engine's absolute intensities to reach that.

| Light | Placement | Cone, penumbra | Intensity (× key) | Shadows |
|---|---|---|---|---|
| Key spot | in front, 15–25° to one side, 30–35° up | 0.5 rad, 0.55 | 1 | yes, map 2048, soft |
| Fill spot | in front, 20–30° to the other side, 25–30° up | 0.6 rad, 0.7 | 0.4–0.45 | no |
| Hemisphere | sky `light-fill`, ground `boards` | — | 0.5 (bright) to 0.25 (night) | — |
| Footlights | one wide spot from the stage lip, 0.15 above the floor, aimed up and back | 1.0 rad, 0.8 | 0.3 (bright) to 1.1 (night) | yes: the cast's shadows climb the rows |
| Pin spot | high in front, on one figure | 0.12 rad, 0.4 | 1.5 | no; held moments only |

- No falloff with distance over the stage: the box is small, and falloff would darken the back
  cloth against the rule that the prints stay mid-to-light.
- Shadow bias −0.0006, normal bias 0.02 unit.
- Light changes lerp colour and intensity over 1.5–3 s; a held moment takes 0.4 s.

## Post

- Multisample 4× before post.
- Vignette toward `house`: strength × smoothstep(0.35, 0.95, distance from the centre, with x
  stretched 1.6×); strength 0.2–0.25 in bright schemes, 0.5–0.55 at night.
- The interface is composited after post, never under it.
- Optional dither act: a 4×4 ordered (Bayer) matrix on 2-px blocks, luminance quantised to five
  tones, mixed in at 0.6 at most, interface excluded.

## Interface

- Text 16 px minimum; titles 18–20 px in small caps; line height 1.3; an old-style serif.
- Slip: `paper` fill, a torn edge (each point 0–2.4 px inward, every 12 px), a hard 2–3 px drop in `card`, held
  by a tack (pillars) or two wires (flown cards).
- Chip: signal fill, `paper` text, the symbol (✓ ! × i) in a 17 px circle, 16 px bold word.
- Focus: a 5 px `accent` bar on the row's left edge plus a ▸ in `ink`.
- Name tags: 8–10 px below the figure's feet, centred, small caps.
- Detail card: beside the figure on the side with room, at least 14 px from its edge, inside the
  opening.
- Accent marker: an unlit diamond 0.2 × 0.28 unit with a 35% wider `ink` outline, on a wire 0.3–0.6
  above the figure, bobbing ±0.04 at 0.5 Hz.
- In-scene text: emissive at 0.35 of its own texture.

## Motion

| Moment | Values |
|---|---|
| Enter or exit | slide along the floor from the wings, 0.6–0.9 s ease-in-out; a 1–2° rock when it stops |
| Fly in | drop from above in 0.5 s, ease-out with a 3% overshoot; swing ±2° decaying over 1 s |
| Idle | a hop of 0.015 unit at 0.4 Hz or a 0.5° rock; at most two pieces move at once |
| Scene change | back cloth flies out upward in 0.8 s and the next flies in; or a curtain in 0.6 s |
| Pointer | parallax ±0.25 unit sideways, ±0.12 vertically; off while figure-anchored slips are open |
| Reduced motion | no rock, swing or hop; changes cross-fade in 0.2 s |

## Generation

- Every print is its own image-model generation (demo.html's set: frame, border, drapes, back
  cloth, three rows, two wing trees, three cast pieces, floor), with the prompt core below and the
  same tint words, so line weight and paper match. Cut-outs on flat magenta (when the cast has no
  pinks) at 1024–1792 px; two seeds a piece was enough for most.
- What the generator does anyway, and the fix: it draws its own cream cut-out border and a drop
  shadow (keep the border, add only a thin one in code, key the shadow); it lays a blank cream
  sheet or a ruled frame behind about a third of the pieces (flood the cream from the border too,
  or reroll); it paints a box interior inside any "opening" (cut the opening yourself by a measured
  rectangle); it adds a strip of ground under props ("drawn alone, no ground" helps).
- Keying: flood-fill the key from the border, remove enclosed pockets of key even when shaded to a
  dull mauve, fill only pinholes, erode one pixel, despill. Crop to the alpha's box.
- Size the stage from the frame: the generated frame's opening sets the opening's aspect (the
  demo's came out about 1.9:1, so its opening is 7.8 × 4.1 rather than the table's 7.8 × 5.0);
  stretching a frame to fit a fixed opening shows. Widen the field of view until the frame fits
  with a strip of house around it (38° here).
- Rows: repeat a generated strip along the width (texture repeat) rather than stretching it, so
  each row keeps its height. Back cloth: extend it past its print with a mirrored repeat where only
  the wings see it.
- The card edge and the shadows come from the engine (a second plane that uses only the image's
  alpha), so one set of prints serves every lighting plot; the prints themselves never recolour.
- Never generated: text, the card edge, counts of repeated parts (spokes, rows, windows).

## Prompt core

Fill `<…>` from the game; keep the rest verbatim.

> Hand-tinted copperplate engraving printed on cream card: bold black ink outlines, fine parallel
> hatching and cross-hatching, flat muted watercolour tints of <role colours as names or hex>,
> light from the upper left, naive nineteenth-century print, no text. <subject>, <pose>, side view,
> a single flat paper cut-out piece isolated on a plain flat solid pure <key colour> background,
> no stage, no frame, no shadow.

Original content only: no existing characters, logos or trademarks.
