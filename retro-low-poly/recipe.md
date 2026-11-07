# Recipe: the core, in any framing and engine

Units: metres. Screen sizes are at 720p; multiply by 1.5 for 1080p. "Low-res pixel" means one pixel
of the internal render target.

## Render target and upscale

- Internal height 240 lines; width = round(240 × aspect) (427 at 16:9). Depth buffer on, no
  multisampling, no anti-aliasing.
- Upscale to the output with nearest filtering. At 720p each low-res pixel is 3×3 output pixels.
- Pixel ratio 1. Tone mapping off. Colours lit in gamma space as authored (no linear conversion), so
  palette hexes and light ratios land as written.
- Interface drawn after the upscale, at output resolution.

## Vertex snap

- In the vertex shader, after projection: `grid = res × 0.5 / snap`;
  `p.xy = floor(p.xy / p.w × grid + 0.5) / grid × p.w`, with `res` the low-res size.
- `snap` 1 = one low-res pixel (the default). 2 halves the grid for a harder look; 0 turns it off.

## Affine textures

- Pass `vec3(uv × w, w)` from the vertex shader (w = clip w after snapping); in the fragment shader
  `uv = v.xy / v.z`. Interpolation becomes screen-linear: textures swim.
- Split faces every 0.5 m wherever the camera comes close (floors, walls, counters, and decal
  quads too). At 1.6 m, checker floors and brick bend visibly and a single-quad sign folds along its
  diagonal; at 0.5 m some swim stays and folds go. Far ground can stay at 2 m.

## Textures

- 32×32 for most surfaces, 64×64 for hero surfaces (a counter top, a machine's face), 8×8 solid
  swatches for emissive tubes. Power-of-two sizes only.
- Quantise each texture to 5 bits per channel (`v >> 3 << 3`) after drawing.
- Nearest filtering, no mipmaps, repeat wrapping.
- UVs from world position, by face normal (x-facing: z, y; y-facing: x, z; z-facing: x, y), divided by
  a tile size in metres: floors 1 m, walls 1 m, metal trim 0.5 m, props 0.2–0.5 m, terrain 2–3 m.
  Texel density stays even: 32 px per metre on floors and walls.
- World text needs at least 1.5 render pixels per glyph row at the base resolution (a 5×7 letter
  ≥ 10.5 lines tall at play distance; lines per metre = 240 / (2 × distance × tan(FOV / 2))). Below
  that, enlarge the sign or cut the word.
- Signs and machine fronts are separate quads with 0..1 UVs, 4–5 cm in front of the surface. Vertex
  snap moves each triangle's corners but not its depth, so a decal 1 cm off a wall, or a ground plane
  2 cm under a floor, cuts through once snapped. Cut ground around floors instead of under them.
- Thin, high-contrast one-texel marks (flecks on a counter, scuffs on a floor) stretch into long
  coloured streaks at grazing angles without mipmaps: keep flecks two texels wide and a shade or
  two from the base.
- Detail is a few hard-edged shapes per texture (seams every 8 or 16 px, specks, stripes). No
  gradients wider than 8 px, no photo noise.

## Shapes and polygon budgets

| Kind | Triangles | Built from |
|---|---|---|
| Small prop (cup, bottle, can) | 12–60 | one cylinder of 6–8 sides, or a box |
| Furniture, machine | 60–400 | 3–10 boxes and cylinders |
| Character | 150–500 | box limbs and torso, box head with a face quad, a 6-sided hat or hair block |
| Vehicle | 200–600 | stacked boxes, 8-sided wheels |
| Room or set | 1,000–6,000 | boxes for walls, split every 1.6 m |
| Whole frame | ≤ 30,000 | |

- Round things 6–8 sides; domes 6 × 3 segments. Never smooth a silhouette with more segments.
- Proportions slightly chunky: limbs 0.11–0.15 m thick on a 1.8 m figure.

## Light (per vertex)

- Light = `ambient + key × max(N·L, 0) + Σ local × wrap / (1 + k × d²)`, computed in the vertex
  shader and interpolated; `wrap = max(N·L, 0) × 0.8 + 0.2`.
- Up to 6 local lights. Attenuation k: 0.06–0.15 for room lights, 0.3 for a work light, 0.8–0.9 for a
  small glowing object, 0.08 for a big sign seen from afar.
- Ratios: key – ambient value gap ≥ 0.25. Lit faces of a material sit at 0.9–1.1 of its colour; clamp.
- Emissive surfaces: add `texture × emit` where the texel is bright (smoothstep 0.55–0.85 on its max
  channel), so a sign's letters glow and its backing doesn't. Each emissive source also gets a local
  light in its `glow` colour.
- Flicker for signs and lamps: `0.92 + 0.05 sin(13t) + 0.03 sin(31t)`.
- No shadow maps. Contact darkness, if wanted, is baked: a darker texture row at the base.

## Fog

- Linear on view depth, per vertex, colour `fog`.
- Interior: start 3–6 m, end 9–26 m. Exterior day: start 6–20 m, end 40–60 m. Horror: end 4–9 m.
- The background clears to `fog`. A sky dome (8 × 6 segments, unlit, no fog) fades from `sky` at the
  top to `fog` at the horizon (power curve 1.5 over the upper half).
- Far geometry stops before the fog end: nothing is drawn that the fog fully hides.

## Post pass

- Sample the low-res target at the pixel centre (`(floor(uv × res) + 0.5) / res`).
- 4×4 Bayer dither on low-res pixels: `c += ((B[i] + 0.5) / 16 − 0.5) × 1.2 / 31`, where
  B = 0 8 2 10 / 12 4 14 6 / 3 11 1 9 / 15 7 13 5.
- Quantise: `c = floor(clamp(c, 0, 1) × 31 + 0.5) / 31`.
- Optional effects in the same pass: tint or desaturation (`mix(c, luma, 0.3–0.6)`), row tearing
  (shift rows by `0.01–0.03 × sin(y × 9 + t × 7)`), chromatic split (≤ 0.012 of width), fade to black.

## Interaction highlight

- Additive `accent × (0.25 + 0.2 sin 6t)` on every surface of a usable object, added before fog.
- Prompt: an `accent`-bordered panel (3 px) above the object's top, clamped clear of every interface
  panel, and moved below (else above) any readable world sign it would cover.
- Hold the camera still (sway off) while the pointer is within 40 output pixels of a target.

## Interface layout

- Panels: `panel` fill, 2 px `ink` border, radius 0–4 px, hard shadow 3 px right and down in `ink`.
- Type: bold sans 16–20 px at 720p; labels and speaker names in caps on an `ink` plate.
- Lists grow with their content (height auto); text wraps; no ellipsis.

## Motion

| Moment | Values |
|---|---|
| Camera ease | `k = 1 − exp(−dt × 7)` under player control; `exp(−dt × 2.6)` for a scripted move |
| Idle sway | roll `sin(0.55t) × 0.018 + sin(0.23t) × 0.01` rad × 0.3; bob 0.004 m at `sin(0.9t)` |
| Object idle | one limb or part swings ±0.25 rad at 0.27 Hz; ≤ 2 moving things per screen |
| Highlight pulse | 0.95 Hz (sin 6t) |
| Reduced motion | no sway, bob or flicker; highlight steady at 0.35 |

## Generation

- Build shapes from primitives in code: every kind in the table fits, and code keeps counts exact.
- Textures drawn in code from palette roles at true size. An image model may make source
  textures (flat orthographic, even lighting, no shadows, seamless), then box-downscale to 32–64 px
  and quantise to 5 bits.
- Image-to-3D for a character or hero object: a concept on a plain background, three-quarter view,
  then smart topology at 1,500–3,000 triangles. Fill the empty texels around each UV island with the
  island's colour before shrinking the atlas (128–256 px, box filter, 5 bits), or seams bleed black.
  Draw it with the scene's own shader and sample its texture raw: an sRGB decode darkens it and
  turns skin red.
- Tiling surfaces (floor, brick, counter) from a node-graph material tool work well when built at
  the final 64 px from palette roles, with per-tile variation from a position hash so they tile.
- Interface, icons, text and numbers: drawn by the engine.
