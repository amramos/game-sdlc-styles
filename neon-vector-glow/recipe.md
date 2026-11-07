# Recipe: the core, in any framing and engine

All sizes are screen pixels at 1080p output. Scale them with the output height (×2/3 at 720p, ×2 at
2160p). `demo.html` draws at 720p, so its numbers are two thirds of these.

## Generator

- **Needs:** nothing generated. Every gameplay shape, effect and panel is drawn in code from line
  segments, arcs and polygons. No image model is required.
- **Optional:** a title or menu backdrop may be an image, kept under value 0.06 except its line art,
  so it obeys the void rule.
- **Never images:** gameplay shapes, particles, the grid, HUD text and numbers. They must stay
  resolution-independent and recolourable from the palette roles.

## Lines

| Thing | Core line | Notes |
|---|---|---|
| Player | 4 px | the widest bloom on screen (bloom source ×1.3) |
| Enemies | 3–4 px | 1–4 strokes per shape; radius 24–34 px |
| Player shots | 3–4 px | a 20 px dash along the velocity |
| Enemy shots | filled dot r 7–8 px, 3–4 px ring | 4–5 px rim in the void colour around it |
| Pickups | 3 px | radius 12 px |
| Grid | 1.5 px minor, 2–2.5 px every 4th line | never in the bloom |
| Sparks | 2–2.5 px | feed the bloom at 60% |
| HUD lines | 1–2 px | the HUD's tight glow |

- Floor: no gameplay core line under 2 px at the output resolution, whatever the scaling.
- Joins and caps: round, so corners glow evenly.
- Shapes are closed polygons, open polylines or rings, 3–8 vertices each; anything with more detail
  reads as noise at speed.
- Size a shape by its radius: enemies 2.3–3% of screen height, the player 2–2.5%, pickups 1–1.2%.

## Glow: a bloom pass (preferred)

The look is light, not outlines: a near-white core, a coloured line, a tight halo, and a wide soft
bloom that tints the void around each shape. Per-line halo strokes alone (wider, fainter copies of
the line) read as outlined shapes at 720p; a blurred bloom reads as neon.

1. **Two layers per glow pass.** Draw every glowing path twice:
   - a *line* layer: the core in its colour at full width, normal blending, then a near-white centre
     (the colour 75% toward white, 0.45 × the width) on top;
   - a *bloom source*: the same path in pure colour, width + 3 px, additive, so overlapping shapes
     add their light.
2. **Blur the bloom source at three radii** and add each copy onto the frame, with a gain above 1
   (the blurred copy added several times):

| Copy | Blur radius (1080p) | Gain | Working resolution |
|---|---|---|---|
| Inner halo | 3 px | 1.2 | full |
| Glow | 10–11 px | 1.8 | half |
| Wide bloom | 36 px (about 3% of screen height) | 3.2 | quarter |

3. **Put the line layer on top**, normal blending, so cores keep their hue where shapes overlap.

- Wide blurs run at half or quarter resolution and are scaled back up: cheaper, and smoother.
- The grid and the background are drawn before the pass and never enter it.
- **Small bright shapes** (pickups) feed the bloom source at about half strength, or they bloom
  into blobs; large shapes (the player, the core) may feed it at full strength and wider (×1.3).
- **Danger after the bloom:** cut a void-coloured disc 6 px wider than each enemy shot into the
  finished world bloom, then draw the shots in their own pass with only the inner two copies
  (3 and 9 px, gains 1.0 and 1.2). Nothing can swallow them.
- **HUD in its own pass**, with a tight glow: blur the HUD's own line layer at 2 and 7–8 px with gains
  0.55 and 0.45. Digits stay sharp and still glow.
- Engines with HDR bloom: emit gameplay cores above 1.0, keep the grid, HUD and background below
  the threshold, threshold 0.85–1.0, and check the result against the table above (the inner halo
  and the wide bloom must both show). Draw the HUD after the bloom, with its own tight glow, or on a
  layer the world bloom never sees.

## Glow: per-line passes (fallback, cheapest)

Where a blur is too costly (very low-end hardware), stroke each path four times: halo (width + 12
px, alpha 0.12, additive), glow (width + 5 px, alpha 0.35, additive), core (normal), hot centre
(0.4 × width, 50% toward white, alpha 0.45, additive). It holds the rules but looks like outlines,
not neon; push halo alpha toward 0.15 and keep the near-white centre.

## Blending

- Additive: the bloom source and its blurred copies, sparks, the grid's warp highlight.
- Normal: core lines and their near-white centres, enemy-shot rims and centres, edge fades, dim
  overlays.
- The void is drawn opaque every frame; no trails from skipping the clear (they smear threats).
  For a trail effect, draw the trail as its own fading polyline.

## Particles

| Event | Count | Speed (px/s) | Lifetime |
|---|---|---|---|
| Shot hits | 4–6 | 90–300 | 0.15 s |
| Small enemy dies | 30–40 + 5 white-hot | 180–720 | 0.4–0.7 s |
| Large enemy dies | 80–120 + 15 white-hot | 240–840 | 0.7–0.9 s |
| Pickup collected | 10–14 | 90–300 | 0.25 s |
| Player hit or dies | 200–300 | 120–780 | 1.2 s |
| Hazard pulse | 40 | 150–450 | 0.4 s |

- A spark is a line from its position back along its velocity: length = speed × 0.035 s.
- Speed falls to 5% per second: multiply velocity by 0.05^dt each frame.
- Alpha = 0.8 × remaining life / lifetime; sparks feed the bloom source at 60% of that.
- Colour: the dying object's hue; "white-hot" sparks are that hue 50% toward white. Never the
  danger hue.
- Cap: 2,000 live sparks at 1080p; when full, drop new sparks, never old danger.
- Lifetime jitter: each spark 60–100% of the event's lifetime, so a burst thins out instead of
  vanishing at once.

## The grid: a spring mesh

- Points every 60 px (1/18 of the screen height); the border row and column are pinned.
- Per 1/60 s step, for each free point with rest position R and offset O = P − R:
  `force = (−O) × 0.025 + Σ over 4 neighbours (O_neighbour − O) × 0.06`;
  `velocity = (velocity + force) × (1 − 0.07)`; `P += velocity`.
- Update all velocities first, then all positions (stable at these constants). Step at a fixed
  60 Hz with an accumulator, at most 6 steps a frame.
- Cap each point's offset at 0.6 × spacing, so lines never cross.
- Impulse at (x, y): for each point closer than radius r, add `strength × (1 − d/r)²` to its velocity,
  pointing away (negative strength pulls in).

| Event | Strength (px/step at 1080p) | Radius |
|---|---|---|
| Small enemy dies | 12 | 240 px |
| Large enemy dies, core hit | 18 | 330 px |
| Player hit | 24 | 420 px |
| Implosion or hazard pulse | −15 | 270 px |

- At these values the peak dent is 0.3–0.5 × spacing and it settles within 1–1.5 s.
- Draw: minor lines at 55% of the grid colour, every 4th line at 100%; then each segment whose
  average offset is over 3 px adds the grid colour again (additive) at alpha min(1, offset / 21 px).
  The warp brightens the grid at most 2×, which keeps it under value 0.7.
- Reduced motion: impulse strengths × 0.3.

## Screen shake and motion

- Shake: translation only, never rotation; at most 8 px; adds per event (small kill 2 px, large
  kill 4.5 px, core hit 6 px, player hit 8 px) and decays linearly to zero in 0.25 s.
- The HUD never shakes.
- Hit-stop: at most 0.05 s on a large kill, 0.1 s on a player hit; never on small kills.
- Enemy shots move at 300–360 px/s, slower than the player (630 px/s), so they can be dodged on
  sight; player shots at 1,350 px/s.
- Rotation: enemies that don't aim spin at 0.5–2 rad/s; the player and aiming enemies face their
  heading.
- Telegraph every hazard for at least 1.5 s with a dashed ring in the danger colour, before it
  hurts.

## Flashes

- At most 3 full-screen flashes in any 1 s window; keep a rolling list of flash times and refuse a
  4th.
- A full-screen flash is an overlay of the HUD ink at ≤ 0.15 opacity, fading in ≤ 0.1 s.
- Any change covering more than ~10% of the screen counts as a flash, including a large spark
  burst or a bloomed explosion close to the camera.
- No colour strobing: no area larger than a pickup alternates hues faster than 3 Hz.
- Reduced flash: zero full-screen flashes; the hit object pulses instead (its bloom source at 1.5×
  for 0.15 s).

## Colour budget

- On screen at once: void, grid, player, at most one ally hue, one pickup hue, one danger hue, 2–5
  enemy hues, HUD ink and panel: 8–12 colours, each a palette role.
- No gradients inside shapes; variation comes only from the bloom and additive overlap.
- Enemy variants of one class share its hue and silhouette and differ in size (×0.5–1.0) or in
  stroke count.

## HUD

- Drawn after the world and its bloom, in its own glow pass with the tight HUD glow above.
- **No panels or boxes.** Text and icons sit on the void; a void-coloured fade from the screen edge
  (85% at the edge to 0 about 170 px in) keeps the world's bloom off the digits.
- Text: smallest 24 px; the few labels upper case and letter-spaced; key numbers 48–54 px in a
  monospace face with tabular digits; numbers group thousands. Prefer a number or an icon to a
  word: the score needs no label, the multiplier is "×24", lives are icons.
- Placement: corners and edges, inside a 3% safe margin; the centre 60% of the screen stays clear
  during play. State that lives in the world (the core's integrity arcs) is not repeated in the HUD.
- Icons: the gameplay shape drawn at 13–20 px radius, core line only, in its role colour.
- Choice screens: dim the fight with the void colour at about 70%; vector frames with cut corners
  (no rounded cards), filled with the void at 90%, 1.5 px `hud-ink` outline at 35%; body text
  26–28 px, at most three lines; an icon per choice; key glyphs drawn as small vector keycaps.
  Focus = 2–3 px `hud-ink` outline plus corner brackets 15 px outside, 45 px long.
- Life icons use the player's shape and colour; nothing else in the HUD uses the player's colour.
