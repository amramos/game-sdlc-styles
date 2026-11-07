# Recipe: the core, in any framing and engine

## Base resolution and scaling

| Base | ×Scale to 1280×720 | to 1920×1080 | to 2560×1440 | Use |
|---|---|---|---|---|
| 320×180 (default) | ×4 | ×6 | ×8 | small cast, chunky look |
| 480×270 | ×2 + border | ×4 | ×5 + border | more on screen, tactics |
| 640×360 | ×2 | ×3 | ×4 | dense interfaces, management |

- Render the whole frame into a target at the base resolution, then scale by
  `floor(min(screenW / baseW, screenH / baseH))` in device pixels; fill the rest with ink.
- Sampling: nearest-neighbour everywhere (textures, render target, interface). Mipmaps off.
- Sprites and tiles are drawn at their true size. Never scale, rotate or skew a sprite at runtime
  except by 90° steps and horizontal flips.

## Sizes per role (at 320×180)

| Role | Size (before outline) | Notes |
|---|---|---|
| Tile | 16×16 | ground detail in clusters of ≥ 2 px |
| Player character | 10–14 × 18–22, in a 16×24 box | head 6–8 px wide, eyes 1 px |
| Other characters | same box as the player | bosses and beasts up to 32×32 |
| Prop | 8–32 px | stacks of props instead of one big prop |
| Icon | 8×8 (+1 px outline = 10×10) | 12×12 for the item the player inspects |
| Portrait | 24×24 to 32×32 | a crop of the sprite or a separate drawing at true size |

At 480×270 multiply by 1.5 (24×24 tiles); at 640×360 by 2 (32×32 tiles, 16×16 icons).

## Palette

- 16 colours for the whole game, assigned to roles in `style.md` (ink, paper, accent, three
  signals, warm-1..4, cool-1..4, bg-sky, bg-far). Pick the count once; never add a colour mid-way.
- Store the game's palette as one `.gpl` with role names and check it against `colour-rules`.
- Draw in role indices where the engine allows (an indexed buffer or a palette-lookup shader), so a
  palette swap is one table and nothing drifts off palette.

## Outline and shading

- Outline: 1 px of `ink` on every outside edge of a sprite, 4-connected (no diagonal corners
  needed); interior lines (eyes, seams) in `ink` or the darkest ramp step. Backdrop: no outline.
- Light from the upper left: top and left faces one step lighter, bottom and right one step darker.
- 2–3 ramp steps per material; the 4th step only for a highlight 1–2 px big.
- Shadow on the ground: a flat 2-row shape in the ground's next-darker step, 2 px narrower than the
  sprite on each side.
- Lines: only 1:1, 1:2, 2:1 or 1:3 steps; remove pixels that make a stair uneven.
- No gradients, alpha, glow or blur. Dim with a 50% `ink` checker; fade by palette steps over 3–4
  frames.

## Sub-pixel and camera

- Keep positions as floats for physics; round when drawing: `camera = round(target)`, then
  `sprite = round(world) - camera`. Rounding the camera after the sprites causes 1 px jitter.
- Camera follow: lerp factor 0.1–0.2 per frame at 60 fps, then round; dead-zone 16–32 px wide.
- Parallax layers move at 0.25, 0.5 and 1.0 of the camera and are each rounded after scaling.
- Screen shake: integer offsets of 1–3 px for 4–8 frames.

## Animation

| Action | Frames | Rate | Technique |
|---|---|---|---|
| Idle | 2–4 | 3–5 fps | 1 px squash (drop the head 1 px), blink every 3–5 s |
| Walk | 4–6 | 8–10 fps | contact / pass / contact / pass; far limb in the darker step |
| Run | 6–8 | 12 fps | lean 1 px forward, bigger stride |
| Jump | 3 | held | crouch 1 frame (2 game frames), rise, apex held, fall |
| Land | 2 | 12 fps | squash 2 px wider, 2 px shorter, then normal |
| Attack / action | 3–5 | 10–15 fps | hold anticipation 2–3 game frames, 1 smear frame in the light step |
| Hit | 1–2 | — | flash all non-outline pixels to `paper` for 2 game frames, knock back 2–4 px |

Movement speeds are whole pixels per frame at the base resolution, or accumulate fractions and draw
the rounded value.

## Interface

- Font: 3×5 caps-only for labels and numbers (4 px advance, 8 px line); 5×7 with lowercase for long
  dialogue at 640×360. Glyphs are never smaller than 5 px tall at base; output scale at least ×3.
- Panel: `ink` fill, 1 px inner rule in a mid ramp step (`cool-2` in the example), 3–4 px padding.
- Chip: signal or accent fill, `ink` text, 1 px padding above, 2 px left and right, 7 px tall.
- Focus: `accent` fill or a 1 px `accent` frame plus a 1 px `paper` frame outside it.
- Dialogue: up to 4 lines of 69 characters at 320 px wide with a 24–32 px portrait; a continue
  marker in `accent` bobbing 1 px at 2 fps.

## Generator

- **Sprites and tiles:** draw by hand in a pixel editor, or generate with an image model and clean
  up. A generated image is a sketch: one subject per generation at 1024 px on a flat key colour,
  then key the background, snap every pixel to the palette at full size, mode-downscale to the
  canvas (most common colour per block) and fit it, in that order; then fix the outline, eyes and
  hands by hand at true size.
- **What the cleanup taught (demo cast):** reserve the backdrop and signal colours in the palette
  tool, or pale skin snaps to a backdrop colour; on a 16 px-wide figure the downscale drops 1 px
  eyes, so place them by hand; apply the outline as one rule after cleanup (every opaque pixel that
  touches transparency becomes ink); generate one walk pose and redraw the legs for the others
  (image-to-image keeps the pose); generate a portrait as its own bust and match its skin step to
  the standing sprite.
- **Never generated:** the font, icons under 12×12, interface panels and chips, any word or number.
- **Consistency:** keep one reference sheet (the player in 4 directions at true size) and pass it
  with every character request.
- **Check:** count the colours in each asset (must be ≤ palette size and all in the `.gpl`) and view
  it at ×1 and at the game's scale.

## Prompt core

Fill `<…>` from the game; keep the rest verbatim.

> Pixel art sprite, <size> pixels, 1 pixel dark outline around the whole sprite, limited palette of
> <count> colours: <role colours as hex>, flat colour shading with 2–3 hue-shifted tones, light from
> the upper left, clear readable silhouette, no anti-aliasing, no gradients, no dithering, no blur,
> no text. <subject>, <pose>, <facing>, centred on a plain flat <key colour> background.

Then one line of setting (original content only; no existing characters, logos or trademarks).
Generate at 8× the target size, then reduce and clean as above.

## Motion values

| Moment | Motion |
|---|---|
| Menu open | panel slides 8–16 px in 4 frames (≈0.07 s) from its edge, no easing past the grid |
| Button press | moves 1 px down for 2 frames; sound on every press |
| Pick up | item jumps 4 px, then flies to its slot in 6–8 frames |
| Number change | counts up in steps over 0.3 s; the final value lands with a 1 px bounce |
| Interaction marker | bob 1 px at 2–3 fps |
| Reduced motion | no shake, no bob; same final positions |
