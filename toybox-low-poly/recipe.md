# Recipe: the core, in any framing and engine

Units: 1 unit = 1 grid tile. Sizes in screen pixels are at 720p; multiply by 1.5 for 1080p.

## Shapes and polygon budgets

| Kind | Triangles | Built from |
|---|---|---|
| Scatter (single leaf, pebble) | 8–40 | one box or dodecahedron, detail 0 |
| Small prop (leaf pile, fence run, rock) | 40–300 | 1–4 primitives |
| Character | 150–400 | body cylinder (8 sides), head icosahedron (detail 1), 2 capsule arms, hat |
| Building | 200–800 | 3–8 primitives |
| Ground island | under 100 | one chamfered slab |

- Round things: cylinders 6–10 sides; half-spheres 8 segments × 3–4 rings; icosahedra at detail 0
  for foliage and piles, detail 1 only for heads.
- Boxes: a single 45° chamfer on every edge, chamfer width 3–8% of the box's smallest side.
- Proportions: height 0.8–1.5× width; caps, roofs and heads overhang their base by 30–60%.
- Smallest detail: 1/10 of a tile (0.1 unit). Anything smaller becomes noise at game zoom.
- Footprints: a building fills 0.7–0.9 of its tile, leaving a gap of ground between neighbours.
- Squash round shapes on y (0.45–0.75) instead of adding segments.

## Shading and materials

- Flat shading: per-face normals (flat-shading flag, or split vertices per face). Never smooth
  normals on primitives.
- One colour per material role; roughness 1, metalness 0, no textures, no normal maps.
- Baked ground shading in vertex colours: multiply by 0.72 at height 0, rising with a smoothstep to
  1.0 at 0.55 unit. The ground slab gets 0.8 at its underside to 1.0 at its top.
- Contact blob under every object: a radial gradient quad, radius 1.1–1.3× the footprint, colour
  `shadow`, opacity 0.45, no depth write, 0.006 unit above the ground, polygon offset −1/−2.
- Ambient occlusion: the vertex shading and blobs above are the default. Screen-space AO, if used,
  at radius 0.3–0.5 unit and intensity ≤ 0.5, tinted toward `shadow`; never both at full strength.

## Light, as ratios

- Hemisphere fill: sky colour = `sky-top` mixed 45% toward white; ground colour = `shadow`.
- One directional sun, warm white (about 5,500 K), elevation 50–60°, azimuth 60–90° off the
  camera's view direction, so shadows fall sideways and back and every object shows a lit and a
  shaded side.
- Fill : sun intensity about 1.4 : 1. Measured result: a lit top face ≈ 1.7× its shadowed value.
- Lit top faces land at 0.95–1.05 of the material's colour with tone mapping off; tune the absolute
  intensities in each engine to reach that.
- Shadows: soft filtering (PCF soft or equivalent), map 1024–2048 covering the play area plus one
  tile, penumbra about 0.1 unit at the play camera's zoom; normal bias ~0.02 unit.
- No rim light, no bloom, no specular highlights.

## Sky and fog

- Sky: a screen-space vertical gradient, `sky-top` at the top to `sky-low` at 75% height, flat below.
- Fog: linear, colour `sky-low`, starting just behind the play area's front edge and reaching full
  at about 2.5× the play area's depth behind it, so only the back edge softens (around 20% at the
  far corner).

## Tilt-shift (optional)

- Two separable blur passes (horizontal, vertical) whose radius grows with distance from a focus
  line at 0.45–0.5 of screen height.
- Strength: 2–3 px of blur per 0.1 of screen height from the focus line, at 720p; scale with height.
- Off in close-up frames (character, prop) and whenever more than half the screen is interface.
- Multisample the render target (4×) before blurring, or edges shimmer.

## Grid, snapping and layout

- Everything snaps to the tile grid; rotations snap to 90° for buildings and are free (seeded) for
  scatter.
- Paths and floor tiles: slabs 0.94 of a tile, 0.07 thick, top 0.04 above the ground. Never
  coplanar with the ground.
- Decals and rings: 0.04–0.08 above the surface plus polygon offset.
- Scatter density: 0.2–0.4 small details per free tile, seeded, never on paths.

## Interaction highlight

- Cursor ring: a square ring, inner edge 0.40 and outer edge 0.48 tile from the centre, unlit,
  colour `accent`; `signal-blocked` when the tile can't take the piece.
- Placement ghost: the real piece in `paper` with 25% `accent` emissive, opacity 0.7, no depth write,
  no shadow cast.
- Usable things: an unlit `accent` octahedron 0.11 unit, 1.4× tall, floating 0.2–0.4 above the object's
  top, bobbing ±0.05 at 0.4 Hz and turning 1.2 rad/s.
- Hover on a usable thing: scale 1.06 in 0.08 s; nothing else changes colour.

## Interface layout

- Names in cards and menus wrap to at most two lines; reserve two lines of height (2.2× the font size
  at line height 1.1) on every card so rows stay even. Never `nowrap` plus ellipsis. If a name
  needs three lines, widen the cards or drop a column.
- Tooltips sit below the status-chip column (top edge at least 12 px under the last chip at
  worst-case chip count) or beside the hovered item on the side away from the HUD; never over chips,
  counters or the build menu.

## Motion

| Moment | Values |
|---|---|
| Place | drop from 0.6 unit, ease-in, 0.19 s; scale 0.6 → 1.0 with overshoot to ~1.08 (ease-out-back), 0.42 s total |
| Remove | scale 1.0 → 0, ease-in, 0.18 s; contact blob fades over the same time |
| Idle life | ≤ 2 things move at once per screen: hop 0.03 unit at 1 Hz, sway 2–4° on foliage at 0.3 Hz |
| Camera | pan and zoom ease-in-out 0.3–0.5 s; zoom steps of 1.25× |
| Interface | panels slide 8 px and fade in 0.12 s; press drops 2 px into its drop shadow |
| Reduced motion | no bounce, bob or sway; pieces appear at final scale in 0.1 s |

## Generation

- Build from procedural primitives in code first: every kind in the table above fits in a few
  primitives, and code keeps facet counts, palette roles and proportions exact.
- Image-to-3D only for one or two hero pieces per game, with a face budget of 800 triangles (2,000
  for a mascot character), then decimate to flat facets, delete the texture and assign palette roles
  per region by hand.
- Image models: only for concept boards and the sky, never for textures on models.
- Interface, icons, text and numbers: drawn by the engine.
