# Recipe: the core, in any framing and engine

## Generator

- **Needs:** an image model that accepts reference images. Seeds help but aren't required.
- **Consistency:** the prompt core below + the game's palette + reference images chained in a fixed
  order: the first character → the key scene (with that character as reference) → the busiest
  screen (with the key scene). Record each frame's references, in order, in the style guide.
- **Never generated:** interface panels, chips, buttons, icons under ~48 px, and any word or number.
  Those are built in the engine.

## Prompt core

There are two cores, because each layer is generated alone: one for the cast (characters and
props on a flat key colour) and one for the stage. Never send both halves in one prompt: words
about a background make the model paint one behind the cast. Fill `<…>` from the game's palette;
keep the rest as written, and avoid capitalised labels (the model paints them as text).

**Cast core:**

> 2D bold graphic illustration: uniform very thick black ink outlines, flat colour fills with one
> hard-edged shadow shape in <shadow colour> on every form, halftone dot texture inside the shadow
> shapes only, jagged angular shapes, high contrast. Palette: <accent>, <signal colours>, <paper>,
> against <ink>. No gradients, no soft airbrush, no glow, no photorealism, no text, no letters.

Then the subject (original characters only; no existing characters, logos or trademarks), then
"isolated on a plain flat <key colour> backdrop, nothing behind it, no floor, no shadow on the
backdrop".

**Stage core:**

> A quiet, tame backdrop that characters will be placed in front of later. Simplified flat
> shapes, low contrast, values compressed into the dark mid-range, thin or no outlines, no
> halftone, no bright highlights, no lit lamps or glowing lights, no small detail, very slightly
> soft like a stage set in shadow. No text, no letters.

Then **colour by material**: name what each surface is made of and its muted colour (from the
`stage-*` roles), and end with "Not <one colour>-dominant. Every colour stays dim and
low-saturation. Completely empty: no people."

**Per kind:**

- *Character:* "waist-up, three-quarter view, in their '<pose>' reaction pose: <how it shows>".
  Make the neutral pose first; derive the others from it by image-to-image at high denoise
  (about 0.85–0.9: lower values change only the face).
- *Prop or card art:* "one object, centred".
- *Stage layer:* one layer per image, each on a flat key colour where it has a cut-out edge.

**After generation** (scripted, so every asset gets it):

- **Key out the backdrop and its drop shadow:** models add a soft shadow on the key colour; key
  every pixel near the key colour's hue, not only the exact colour, and remove fringes.
- **Clamp the stage:** models light lamps and windows despite the prompt. Compress every stage
  value above the stage ceiling and cap its chroma (both from the colour rules), then check.
- **Check the shadow shape:** cast art often comes back with halftone but no solid shadow shape;
  reject or repaint those, since the shadow tone is part of the look.

## Sizes

| Kind | Generate at | On screen at 1080p | Notes |
|---|---|---|---|
| Character | 1024×1536 (2:3), waist-up | ~60% of screen height | 3–4 reaction poses, derived from the neutral one |
| Prop / card art | 1024×1024 | 120–360 px | no text |
| Stage layer | 1536×1024 → upscaled to 1920×1080 | full screen, zoomed up to ×1.4 | soft by rule, so upscaling is fine |
| Loudest-moment cut-in | 1536×1024 → 1920×1080 | full screen | keep the bottom fifth clear |
| Panels, chips, buttons | built in the engine | — | never images |
| Icons < 48 px | drawn by hand or in code | — | never generated |

## Interface material (engine-drawn)

- Panel: fill `paper`, 4 px `ink` border on all sides, square corners, content margins 10–12 px.
- Primary action: fill `ink`, text `paper`, 4 px `ink` border, and a hard offset shadow in `accent`
  (6 px right, 6 px down, no blur).
- Halftone (where the engine draws a shadow): dots of `ink` or `shadow` on a 6 px grid, dot radius
  growing with shadow depth; never on the stage.
- Tilts: −3° to +3° on cards and small labels; 0° on anything read to decide.

## Motion

| Moment | Motion |
|---|---|
| Enter | slide 0.12 s with a small overshoot, settle to its tilt |
| Leave | slide or tear away in 0.10 s |
| Press | lift 12 px, scale 1.06 in 0.08 s, short wobble; every press has a sound |
| Score | each step ticks in 0.08–0.15 s with rising pitch; shake scales with the total |
| Reduced motion | no shake, wobble or tilt animation; same final position and state |

**Loudest moment:** freeze 0.15 s, a diagonal band of the interface material slashes across the
screen in 0.2 s carrying the actor's face or hand, the title lands, hold 0.8 s; the whole beat under
1.4 s and the only time input is blocked. Bottom fifth stays clear for what follows. Reserve it for
one or two events in the whole game.
