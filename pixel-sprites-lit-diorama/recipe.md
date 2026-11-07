# Recipe: the core, in any framing and engine

Units: 1 unit = 1 metre; an adult sprite stands 1.6–1.8 units. Screen sizes are at 720p; multiply
by 1.5 for 1080p. Colours are named by the roles in style.md.

## Sprites

| Thing | Value |
|---|---|
| Canvas | 16×24 px (chunky) to 64×64 px; the demo uses 32×48; one size per game |
| World size | 1.8 units for 24 px (0.075 unit per pixel) or 48 px (0.0375); keep one pixel size for the whole cast |
| On screen | 3–5 screen px per sprite pixel at the home camera; 10–14 in close-ups |
| Filtering | nearest for magnification and minification, no mipmaps |
| Cut-out | alpha test at 0.5; no alpha blending (sorting and soft fringes) |
| Facing | yaw-only billboard: `yaw = atan2(cam.x − x, cam.z − z)`; flip by scale x = −1 |
| Feet | on the canvas's bottom drawn row; the plane's origin at that row, so feet touch the floor |
| Outline | one dark colour (`outline`), 1 px, outside the silhouette |
| Shading | inside the sprite only: a shaded pixel is its role colour × 0.72 (sRGB) |
| Contact shadow | radial-gradient disc, radius 0.42 unit (0.23× the sprite height), colour `outline`, opacity 0.45, 0.012 above the floor, no depth write |

- **Lit by tint, not by lights:** an unlit material whose colour multiplies the texture. Base
  `tint`; within a lit point light's reach, lerp toward `glow-*` by
  `0.55 × (1 − smoothstep(0.8, 4.5, distance))`. The scene's lights never touch sprite pixels.
- Motion moves in whole sprite pixels: idle bob 1 px at 0.8 Hz, walk cycles 6–8 frames at 8 fps.
- Fog applies to sprites like the set, so far figures sink into the haze with it.

## The set

- Toon shading with a 4-step light ramp: `[70, 140, 205, 255] / 255`, nearest-sampled, indexed by
  `0.5 × N·L + 0.5`. Faces turned away land at 0.27, edge-on faces at 0.80, lit faces at 1.0.
- Grain on every set material: a 128² greyscale texture of 900 short horizontal strokes (4–22 ×
  1–3 px) at 0.77–1.0 on white, multiplied into the base colour. Floors add a tile or plank grid at
  28% darkness every 32 px of a 256² texture, repeated 4–6 times across the set.
- Pieces are primitives: boxes, 6–8 sided cylinders, icosahedra at detail 0 for foliage and goods,
  4-sided cones for roofs. A stall is 6–10 primitives; a house 2.
- The near side of the set stays open (no wall or parapet toward the camera).
- One contact disc under every free-standing piece: radius 0.6× its footprint's long side.
- Distant scenery (beyond 2× the set's depth) is boxes and roofs only, stepped down or up in
  rows 6–7 units apart so the fog grades them.

## Light, as ratios

- No tone mapping: palette colours land as authored. Tune intensities so a lit top face is
  1.0–1.1× its material colour and a face turned from the key is 0.3–0.55×.
- Key from 40–60° elevation and 30–90° off the camera's yaw, so tops and one side face read lit.
- Fill (hemisphere, `fill-sky` over `fill-ground`) supplies 25–35% of a lit top face.
- Rim from behind and above at 15–30% of the key.
- Point lights (lamps): range 7.5–9 units, decay 1.6; flicker ±6% from two sines (3.1 and 7.3
  rad/s), never random per frame. The pool under a lamp reaches about 1.5× the floor colour.
- Glow cores are unlit, drawn at 2.5× `glow-*` so they pass the bloom threshold; unlit lamps at
  0.8×. A soft additive sprite 2.6 units across, opacity 0.55, around each lit core.
- Shadows from the key only: soft filtering, 2048² map covering the set plus 30%.

## Sky and atmosphere

- Backdrop: an open cylinder arc, radius at least 10× the set's width, 2.5 rad wide, centred on the
  view direction, unfogged and unlit. Painted: `sky` to `fog` toward the horizon, 50–80 soft cloud
  strokes (alpha 0.12–0.3), a sun or moon disc in `key`, two layers of far hills, `fog` below the
  horizon. Put the horizon where the camera's eye height meets the cylinder.
- Fog: exponential squared in `fog`; density so the set loses under 3% and the far ground 40–60%
  (0.0085–0.012 per unit for a 15-unit set seen from 15 units).
- Light shafts: 4–5 additive planes 2–4 units wide, 40 tall, tilted about 24°, colour `key`,
  opacity 0.025–0.08, unfogged, behind the set.
- Mist: 18–26 soft sprites 9–16 units across in `fog`, opacity 0.05–0.1, drifting ±2 units over
  about two minutes.

## The animated banded surface

The ground beyond the set (grass, sand, snow, a cloud layer) is one shaded plane:

- Height: three sines, `0.9 sin(0.11x + 0.6t) + 0.6 sin(0.17z − 0.45t + 0.04x) + 0.25 sin(0.37(x + z) + 1.1t)`.
- Normal from screen-space derivatives of the world position; light `N·L` floored to 4 bands
  (`floor(4l) / 4`), times key plus fill.
- Brush noise: ±10% per cell of 1.25 × 0.33 units (streaks along x); crests above 1.1 height mix
  50% toward a pale crest colour.
- Fog computed in the shader with the scene's density.
- 200 × 110 segments over 320 × 180 units is enough at the home camera.

## Camera

- Perspective, vertical field of view 46°, pitch 18–22° down; the horizon in the top 5–10% of the
  frame; the set fills 60–90% of the width.
- Eased moves: `k = 1 − exp(−dt × speed)`, speed 1.2, 0.8 for close-ups.
- Close-up: camera at (subject x + 2.7, 2.3, subject z + 4.05), looking at the subject 0.85 up; letterbox
  bars 64 px sliding in over 1.2 s; captions hidden; a centred lower-third card.
- Every close-up returns home after 8 s or on escape or a click on nothing.

## Post chain

Render (4× multisampled, half-float) → bloom → horizontal tilt-shift → vertical tilt-shift →
grade → output conversion to sRGB.

| Pass | Values |
|---|---|
| Bloom | threshold 0.88 linear luminance (above every lit set colour); strength 0.55; radius 0.6 |
| Tilt-shift | blur step = amount ÷ screen size × distance from the focus line; amount 2.4 (close-ups 3.2); focus 0.40 of height from the bottom (0.45) |
| Grade | below luminance 0.35, multiply toward `fill-ground` normalised to its brightest channel, by 0.15 (day) to 0.4 (night) |
| Vignette | `1 − smoothstep(0.25, 0.85, length(uv − 0.5) × (1.1, 1.3))`, mixed in at 0.35–0.7 |
| Grain | ±0.006 per pixel, static in captures |

Off in the low setting: bloom; tilt-shift at half resolution.

## Interface

- Captions anchored 4 px above the sprite's head or the prop's top, centred, max 240 px wide.
  Names 17 px small capitals, letter-spacing 0.06 em; status 16 px italic.
- Backing: `plate` at 85% opacity, radius 4 px, padding 3 × 9 px, a 10 px soft glow of `plate` at
  60% around it, text shadow 0 1 px 2 px `plate`. Over pure white it still gives ink and accent
  at least 4.5:1, so it holds over any surface.
- Layout each frame, in screen space:
  1. Obstacles: every sprite's drawn rectangle (head top to feet, 0.6× its height wide), its own
     included; every stall or prop's projected bounding box (soft: avoided when possible).
  2. Order by priority: the selected person, the stall in focus, then the rest.
  3. For each caption, try in turn: centred above its subject, then slid 50, 100, 150 px sideways
     and raised in 14 px steps up to 84 px; then beside the sprite (6 px gap); then below its feet.
     Take the first spot inside the free area that touches no placed caption (4 px gap) and no
     sprite (2 px gap). Retry without the soft obstacles before giving up.
  4. The first 4 placed captions are full; the rest show a short name only (one word, no status).
     A caption with no free spot is hidden for that frame.
- A capture check counts overlapping boxes, clipped text and captions over sprites; all must be 0.
- Hit volumes: spheres radius 0.75 at chest height on people, boxes on props, invisible.
- Selection ring: inner 0.50, outer 0.64 unit, additive `accent`, 0.02 above the floor.
- Panels: `plate` from 90% to 60% opacity left to right, 2 px `ink` left rule; padding 12–16 px.

## Generation

- **Sprites:** drawn in a pixel editor, in code from character grids, or (as in the demo) from an
  image model's pixel-art mode at the final size with a fixed seed. Prompt core: "pixel art game
  sprite, full body, standing still, three-quarter view, [setting], [palette words], simple shading,
  single dark outline," plus one line per character. Remove stray backgrounds, then snap every pixel
  to the palette roles.
- **Backdrop:** painted in code, or an image model at about 1536 × 640, cropped to the band the
  camera sees and desaturated to 0.75–0.8. Prompt core: "hand-painted gouache matte painting of a
  [time of day] sky over [setting], wide panorama, visible brush strokes, stylised like a theatre
  backdrop, no text."
- **Set surfaces:** tileable grey value maps, 128–256 px, posterised to four values (0.60, 0.76,
  0.89, 1.00) and multiplied into the role colour, so one map serves every palette. One map covers
  2–8 units, so a texel is about the size of a sprite pixel. Box UVs in world units, nearest
  magnification, mipmaps for distance. A node-graph material tool works when it can posterise in
  the graph; realistic PBR materials need re-grading and are not worth it.
- **Generated sprites:** clean in this order: key, crop to the silhouette, scale so every figure
  keeps one pixel size (children shorter), snap, mode-downscale, then redraw the 1-px outline and
  fix colours by meaning (a basket that snapped to the costume red). Reserve the cast's colours to
  the sprites so props never take them.
- **Set:** procedural primitives first. Image-to-3D only for background pieces, at most 15,000–
  25,000 faces, never for the surface where play happens.
- **Text and numbers:** always live, never baked into images.
