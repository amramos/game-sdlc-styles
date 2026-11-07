# Recipe: the core, in any framing and engine

Sizes in screen pixels are at 720p; multiply by 1.5 for 1080p. Light comes from the upper left
(direction −0.6, −0.8 on screen) unless the game's lighting scheme says otherwise.

## Black masses

- Share of solid ink per picture: 25–45% (count it on a capture: pixels at `ink`). Under 20% the
  look turns into flat colouring; over 55% figures merge.
- Form shadow: the shape minus a copy of itself moved toward the light by 18–30% of its largest
  side; what is left is filled solid `ink`. Heads and round forms 20–25%, large masses 30–45%,
  flat walls 5–10%.
- Cast shadow: a flat `ink` polygon on the ground, 1.2–2× the object's width, skewed 30–60 px down
  and away from the light. No blur and no alpha.
- Faces: eye sockets or the whole far half in `ink`; small paper highlights (eyes, goggles, teeth)
  carry the expression.
- Merge shadows into neighbouring blacks where they touch: the joined shape is the look.

## Line

| Line | Width at 720p | Rule |
|---|---|---|
| Contour, lit side | 2.5–4 px | per-vertex width `wMin + (wMax − wMin) · max(0, n·(−light))²`, ±12% jitter |
| Contour, shadow side | 6–14 px | 2–3× the lit side; scales with the figure's size |
| Interior lines (folds, seams, mullions) | 3–5 px | tapered both ends: width × `sin(π(0.1 + 0.8t))^0.5` |
| Hatching | 2 px, every 7–9 px | angle −40° to −50°; one direction only; cross-hatch only for a deeper step |
| Panel border | 5 px | `ink`, square corners |
| Caption border | 3 px | `ink`; offset shadow 5 px right and down, solid `ink` |

- Build a stroke as one quad per segment plus a round dab at each point; never the engine's even
  line for contours.
- Distant things get thinner lines (×0.5–0.7) and less black, never a fade or blur.

## Fills and tone

- Every surface is one flat role colour: `field-1` (dark), `field-2` (mid), `field-3` (light),
  `paper` (highlight and lit windows), `ink`.
- Middle tones are hatching in `ink` over a field fill: the base of a mountain range, a wall in
  half-shade, a transition band 40–80 px tall. Never a gradient.
- Depth order: sky and far shapes in one field step, the middle ground a step darker or lighter, the
  foreground figures separated by their contour and black mass, not by colour.
- Weather and particles (snow, rain, sparks, dust) in `paper` or `ink` dots 1.5–4 px, no alpha.

## The accent

- One accented object per picture (a panel is a picture). It may be a light source, an object or a
  piece of clothing: the game names its job.
- Size: 0.5–4% of the picture's area. As a light: a flat star or disc with a 2–3 px ink contour,
  flicker by radius only (`R · (1 + 0.15 sin 7.3t + 0.1 sin 13.1t)`), never a glow.
- Rim (only in a one-light scheme): the holder's parts minus a copy moved 4–8 px away from the
  light, filled `accent`. Nothing else gets accent spill.
- Recolouring a picture to a new ramp leaves accent pixels untouched: skip pixels whose hue is
  within 25° of the accent's and whose chroma is above 0.45.

## Ramp swap per chapter

Map each pixel's luminance `L = 0.3R + 0.55G + 0.15B` onto the new ramp (ink, field-1, field-2,
field-3): `f = min(2.999, L × 3.2)`, `k = floor(f)`, mix ramp[k] → ramp[k+1] by `f − k`. Paper
captions and the accent are excluded. One set of art then serves every ramp.

## Page and interface

- Gutters 16 px of `paper`; panels 5 px `ink` border; 2–4 panels per screen, the main one 55–70%
  of the screen.
- Caption: `paper` fill, padding 10 px, capitals, line height 1.22, text 18–22 px; dark caption:
  `ink` fill, `paper` letters and border, for focus and logs.
- Wrap every text to its box by measuring it; a box grows by whole lines and never truncates. If a
  column overflows, step the font down by 1 px to a floor of 16 px, then widen the column.
- Status: an ink icon drawn in code (battery outline with 5 charge cells, cells in `signal-ok`, or
  `signal-alert` at 20% and below; wind as three tapered streamlines, two curling back) with its
  number in 28 px lettering and the unit at 16 px beside it. No box around either.
- Question: bare title lettering, 30 px, straight on the page.
- Answer slip: `paper` with the grain, long edges nearly straight, short edges torn (a jitter of
  ±1.5 px every 3 px), 2 px ink edge, a 4 px hard ink shadow, tilted ±0.7–1.7°; its key in a 14 px
  ink disc at the left; capitals 20 px.
- Paper grain: a tileable greyscale texture (0.86–0.97) multiplied over every `paper` surface;
  stronger than about 0.15 starts to grey the letters.
- Sound word: small-caps serif 44–120 px, rotated −3° to −8°, a 6–10 px `ink` stroke, `paper` fill,
  a hard `ink` copy offset 6 px.
- Note: `paper`, rotated −1.5° to −3°, ruled lines in `field-3` every 1.3 × the font size, a
  4 px hard shadow, lowercase hand lettering.
- Focus: the slip lifts 7 px, its shadow grows to 10 px and a brush underline appears. Press: it
  drops 2–3 px into its shadow. Unavailable: no shadow, `field-3` edge, `field-2` letters, the
  reason as text.

## Motion

| Moment | Values |
|---|---|
| Impact | screen shake 4–8 px for 0.2 s, one sound word scaling 1.3 → 1.0 in 0.12 s |
| Panel in | slide 24–40 px from its gutter side in 0.18 s, no fade |
| Something approaching | grows by steps (scale 0.17 → 0.23 → 0.31 → 0.44 → 0.62) and its line weight grows with it |
| Idle life | ≤ 10 fps: particles fall, the accent flickers; everything else holds |
| Reduced motion | no shake or flicker; sound words appear at final size |

## Toon 3D in ink (optional)

For a few 3D objects inside a panel:

- Stepped light: 3 steps (0.27 / 0.63 / 1.0) from a nearest-sampled ramp; no specular.
- Outline: an inverted hull (back faces, `ink`) grown by 3.5–8% of the part's size, or 2–6 px in
  screen space.
- Post pass with depth: edge lines where `smoothstep(0.10, 0.22, depth difference)` over a 1.3 px
  sample step, mixed toward `ink`; posterise luminance to 5 levels keeping hue
  (`c = hue · floor(l · 5 + 0.5) / 5`); optional print grain ±0.03 changing 8 times a second.
- Ground: a value-noise texture stretched 0.32 × 2.4 and thresholded at 0.70–0.765 into thin ink
  strokes.
- Camera: perspective, FOV 25–35° (a narrow FOV keeps the silhouettes graphic).

## Generation

- **Image models** for backdrops, figures and props, each generated alone (a figure or object on
  magenta, a backdrop with nobody in it) and composed in the panel by the game; then snap every
  pixel to the nearest role colour and check the black share. Generated figures tend to carry less
  black than the look asks; push "solid black" in the prompt or add ink masses in cleanup.
- **Code** for the page: panels, captions, balloons, slips, icons, particles and the tow-rope kind
  of connecting line between separately generated things.
- **Never generated:** letters, numbers, interface boxes, slips, icons.
- **Where the black goes:** "heavy black shadow shapes" in a cutout prompt makes the model paint a
  black cloud behind the object; say "filled with solid black ink inside the drawn outline" and
  "the magenta is untouched up to the outline". Never write "subject" in a prop prompt: the model
  draws a person.
- **Snapping:** let `paper` take only warm creams and the accent only clearly saturated warm
  pixels (or a box around the focal thing); cold whites are snow in `field-3`, and tan fur or skin
  must not become a second accent.
- **Cutouts:** generate on flat magenta (the model often paints pink: key on red and blue both well
  above green). Flood the key only from the image border, then fill every hole inside the
  silhouette, so a pale muzzle, throat or cream patch with a gap in its outline stays opaque; leave
  transparent only enclosed holes that are themselves key colour (gaps between legs closed by a
  ground shadow). Remove a pale sticker halo only on images that have one, never as a default: a
  light flood eats pale parts of the subject. Alpha ramp `(d − 28) / 40` on the distance from the edge
  colour; pull fringe pixels 70% toward `ink`; fade the bottom 14–30% so the cutout sits in the panel.
- **img2img from existing art:** denoise 0.62–0.70 keeps likeness and goes inked; 0.8 loses the
  likeness; under 0.55 stays painterly. Add a one-line description of the subject.
- **Sizes:** generate at 1024² (cutouts, portraits) or 1536 × 640–864 (backdrops), two seeds each;
  ship at the size on screen.

## Prompt core

Fill `<…>` from the game; keep the rest verbatim.

> Graphic novel ink illustration: heavy solid black shadow shapes covering the side away from the
> light, bold thick brush ink outlines that swell on the shadow side, simple graphic shapes, flat
> colour fills with no gradients and no painterly texture, a very limited palette of <field
> colours as words and hex> and black, with one <accent colour> accent on <the focal thing>.
> <subject>, <pose or action>, <where it sits in the frame, e.g. "centred, fills 70 percent of the
> frame">. <lighting scheme, e.g. "one hard light from the upper left" or "flat daylight">. No text,
> no lettering, no border.

Then, for a cutout: *"Plain flat solid pure magenta background, completely empty."* For a backdrop:
*"One full-bleed illustration that fills the whole frame, plain unmarked corners."* Original content
only: no existing characters, logos or trademarks.
