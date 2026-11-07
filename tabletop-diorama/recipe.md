# Recipe: the core, in any framing and engine

Units: 1 unit ≈ 10 cm of real table. Screen sizes are at 720p; multiply by 1.5 for 1080p.

## Scale and layout

| Thing | Size (units) |
|---|---|
| Table surface | at least 3.5× the miniature's width; it fills the frame edge to edge |
| Miniature base | 6–8 × 4–5, 0.15–0.3 thick, with a frame 0.1–0.15 wide in a darker paint |
| Figurine | 0.5–0.7 tall on a round base 0.25–0.3 across, 0.05 thick |
| Building | 0.9–1.9 tall, 0.9–1.6 wide; 2.5–3.5 figurines tall |
| Small prop (cart, crate, basket) | 0.3–0.8 |
| Full-size object beside the miniature | at real size: a cup 0.8 tall (1.2–2× a figurine), a card 0.9 × 0.6, a tool 2–4 long |

- Keep the important pieces inside the central 70% of the base; the edges get dressing.
- Smallest detail: 0.04 unit. Below that, the tilt-shift and texture eat it.

## Carving

- Round things: 6–10 sides; spheres 6–8 segments × 4–5 rings; heads at icosahedron detail 1.
- Boxes: one 45° chamfer on every edge, 4–8% of the smallest side.
- Knife facets: move every vertex by a seeded offset of 2–4% of the piece's size, hashed from the
  vertex position so that vertices shared between faces move together and seams stay shut. Then
  shade flat (per-face normals).
- Budgets: figurine 300–1,500 triangles from primitives, 4,000–6,000 from image-to-3D; props
  100–800 from primitives, up to 12,000 from image-to-3D; a building 200–1,200.
- Proportions: figurines' heads 1/3.5–1/4 of the height; buildings slightly too tall for their
  width (height 1.1–1.4× width) and roofs overhanging by 8–15%.

## Painted-wood material

- Diffuse = paint colour × grain texture; roughness 0.75–0.85; metalness 0; no normal map; flat
  shading.
- Grain texture: 256², mean value about 0.9, 80–100 wavy strokes 1–2 px wide at 10–25% darker,
  plus fine speckle; repeat about 1 per 0.5 unit. Neutral grey, so it never shifts the paint's hue.
- Bare wood: `wood-bare` × the same grain, roughness 0.9.
- Paint bands on a figurine by height above its base, as fractions of the figure's height: base
  0–0.075, legs 0.075–0.40, coat 0.40–0.735, skin 0.735–0.905, head or hat 0.905–1. When one mesh is
  recoloured by a shader, keep the carved texture's shading: `band × (0.42 + 0.95 × luminance)`.
- Table: `table` × a plank or cloth texture, roughness 0.6–0.75, repeat so one plank is about 1.5
  units wide.

## Light, as ratios

- One key light, one fill, at most two practical lights (a candle, a lit window, a lamp).
- Key to fill, measured as the brightness of a lit top face over a face in shadow: 2–3 : 1 for day
  schemes, 8–12 : 1 for night schemes.
- Key height: 50–65° above the table for a lamp or high sun; 25–35° for a low window light.
  Its azimuth 30–90° off the camera's, so pieces show a lit and a shaded side.
- A lamp key is a spot: cone half-angle about 50°, penumbra 0.5–0.6, aimed just behind the base's
  centre so the far edge stays inside the cone.
- Practical lights: short range (6–9 units), quadratic-ish falloff (decay 1.4–2), placed so they
  light the back half of the base.
- Flicker on flames only: intensity × (0.97 + 0.03 × sin(7.3 t) × sin(2.1 t)).
- Shadows: soft filtering, map 2048², a penumbra of about 0.05 unit at the figurine's feet, small
  negative depth bias (about −0.0004) and a normal bias of about 0.02 unit.
- A room-level factor dims every light together for dramatic moments: to 0.3, and to 0.06 at the
  darkest.
- Tone mapping: a filmic curve (ACES or equivalent), exposure tuned so a lit top face of each paint
  lands within about 10% of its hex.

## Room and fog

- Background and fog colour: `room`.
- Linear fog starting just past the base's far edge (1.3–1.4× the camera's distance to the base's
  centre) and full at 2.1–2.6×, so the table fades out before the frame's top edge.

## Post chain, in order

1. Scene render into a float target, multisampled 4×.
2. Guard: replace NaN or infinite pixels with 0, clamp colour to 0–40.
3. Bloom: threshold above the brightest lit paint (so only flames, lit windows and the sun's
   highlights bloom), strength 0.2 by day, 0.5–0.6 at night, radius 0.7.
4. Tilt-shift: blur grows with the distance from a focus line at 0.42–0.48 of the screen's height
   (from the bottom). Above the line it rises from 0 at +0.1 to full at +0.5; below it reaches only
   30% at −0.55. Full radius 4–6 px at 720p. 16 golden-angle taps (angle step 2.39996 rad, radius
   √(i/16) × r).
5. Vignette: centre (0.5, 0.52), aspect weights (1.1, 1.25), falloff from 0.25 to 1.05; strength
   0.25–0.4 by day, 0.7–0.85 at night.
6. Grade: multiply toward the key's colour, at most 10% per channel (for a warm key about
   (1.06, 0.98, 0.86) at 60%).
7. Tone mapping and output colour space.

Off in close-up frames: tilt-shift at half radius; vignette and grade stay.

## Camera, in any framing

- Field of view 30–40° for perspective framings; the narrow lens is part of the miniature read.
- Idle sway: ±0.05 unit sideways at 0.02 Hz. Shake: x × 0.08, y × 0.05 of the amount, decaying.
- Camera 8–11 units from the base's centre: closer for flat boards, farther when buildings stand at
  the back. The tallest piece stays below the top 10% of the frame.

## Interface

- Paper cards: `paper` fill, `ink` text, 1–3° rotation, shadow 0 4 px 12 px at 25–35% opacity in
  the room's darkest tone, padding 12–16 px, no border.
- Text sizes: 16 px minimum, 18–20 px for card body, 24–26 px for one line spoken over the scene,
  32–34 px for dramatic lines. Line height 1.3–1.4. Spoken lines: at most `min(640 px, 50vw)` wide.
- A spoken line over the scene sits on a paper slip; only when value(`room`) ≤ 0.3 may it sit
  straight on the room, in `paper`-coloured text over a soft radial gradient of `room` at 75%.
- Typed text: 22 ms per character, 55 ms for slow lines; queue at most three, drop the oldest; a
  click finishes the line.
- Choices: italic phrases, dotted underline, lift 2 px on hover.
- Accent ring around a target: inner radius 1.1× the piece's base radius, width 0.04 unit, unlit,
  pulsing in scale ±6% at 1.2 Hz. Hint pulse on something to find: the same ring at 0.8 Hz.
- Hover on a piece: a card slides in 12 px over 0.15 s; the piece lifts 0.03 unit.

## Motion

| Moment | Values |
|---|---|
| Place | the piece lowers 0.25 unit in 0.22 s, ease-out, with a 2° wobble that settles in 0.3 s |
| Remove | lift 0.2 unit and fade in 0.18 s |
| Idle | at most two pieces move at once: a rock of ±1.2° at 0.13 Hz, a bob of 0.01 unit |
| Rocking piece | rotation z = sin(0.8 t) × 0.02 |
| Movement under a fixed piece | scroll the base's texture offset instead of moving the piece |
| Reduced motion | no sway, flicker or wobble; pieces appear at their final place in 0.1 s |

## Generation

- **Primitives first.** Buildings, carts, loaves, crates, furniture and figurines fit in 3–15
  primitives each, and code keeps facets, paints and bands exact.
- **Image-to-3D for hero figures and complex props:** concept image first, then image-to-3D with
  quad or smart topology at the budgets above. Texture prompt core: *hand-painted carved wood,
  visible knife marks and wood grain, chipped folk-art paint*. Model prompt core: *a hand-carved
  wooden toy \<subject\>, folk-art model, chunky carved shapes with visible knife facets, painted
  wood, no base* (figurines add *on a round wooden base*).
- **One body for every figurine:** generate or build it once, in bare wood; repaint by bands.
- **Image model for the table and relief textures:** 1024², top-down flat view, *seamless*;
  crop 40 px per side, save as JPEG at quality 85, use plain repeat.
- **Painted cut-outs** (a hand, a portrait on a card): generate on a flat magenta background; key
  with alpha = clamp((colour distance − 35) / 40), despill magenta, blur the alpha 1 px, alpha test
  0.35, and give the plane a depth material so it casts a shadow.
- **Repaint generated models part by part.** Use the generator's own base colour as the ID map in a
  texture painter: one flat palette paint per part by colour selection (several generator shades
  per part), then wood grain multiplied at about 45%, edge wear revealing `wood-bare`, and a dark
  wash in the cavities at about 45%. One mesh gives a street of differently painted buildings,
  seconds per variant. Keep the generator's colours where painted detail carries the piece (faces,
  food) and add only the grain, wear and wash.
- **Drop the generator's normals** and compute flat ones: a 5,000-triangle model then reads as
  knife-carved.
- **Ask for blank sign boards** in the concept and put live text on a plane placed by a ray onto the
  board.
- **Tiling surfaces (table, street) as neutral light value maps** (mean about 0.85) multiplied by
  the palette role in the engine, so every lighting scheme still recolours them.
- Never generated: words, numbers, icons under 48 px. The engine draws them.
