---
id: loud-ink-cast-quiet-stage
version: 1
name: Loud ink cast on a quiet stage
---

# Loud ink cast on a quiet stage

## The look

Bold 2D illustration in two layers that never mix. The **cast**, meaning everything the player
looks at or acts on (characters, objects, cards, speech, the interface), is loud: uniform, very
thick black ink outlines, flat saturated fills and exactly one hard-edged shadow tone with halftone
dots inside it. The **stage** behind it is quiet: dim, low in contrast and saturation, simplified,
with thin or no outlines and no halftone. The interface is made of one physical material with the
same ink outline (cut paper by default), set at slight tilts and slapped on and off with snappy
motion. The recognizable thing is the contrast: a loud, expressive cast against a hushed set, with
one thing in focus at a time.

## Signature elements

1. **Uniform, very thick ink outlines** on every cast element: about 4 px at 1080p on engine-drawn
   panels, and matching weight in generated art.
2. **Flat fill plus one hard shadow tone,** with halftone dots only inside that shadow. No
   gradients, airbrush, glow or glass.
3. **The focus rule:** nothing on the stage is brighter or more saturated than the cast in front of
   it. One subject at a time; everything else dims, shrinks or stills until needed. A busy screen is
   fixed by removing or dimming, never by adding a frame or a glow.
4. **A physical interface:** panels are a material (paper, card stock, tape, labels), outlined in
   ink, tilted −3° to +3°, never app cards or glass.
5. **Big acting:** characters carry a few strong reaction poses that read in silhouette at game
   scale.

## Readability and interface

- **Every word and number is live text** in the game's fonts. The generator misspells, so no word is
  ever painted into an image.
- **Type roles:** a condensed heavy *display* face for titles and the numbers players decide by; a
  *body* face that suits the setting's documents (typewriter, receipt, label printer, stencil); a
  *caption* treatment (display face, upper case, small). At most three treatments in the whole game.
  Choose the faces per game; licence-safe candidates include Bebas Neue, Oswald, League Gothic
  (display) and Space Mono, IBM Plex Mono, Special Elite (body).
- **Smallest readable size:** 24 px at 1080p (16 px on a 720p handheld). Numbers that decide a move
  use the display face; a caption-sized number was found too small on a handheld.
- **Ink outline wherever the interface meets the stage or the cast.** A light panel averaged only
  2.2–2.4:1 against a dim stage, and dropped to 0.9:1 where it overlapped a pale part of a
  character. The outline, not the fill, separates them.
- **Signal colours** (kinds, categories, states) appear only on their own chips or badges, and each
  chip also says its kind in a word or an icon.
- **Focus mark:** four corner brackets cut from the interface material with the ink outline,
  standing clear of the focused thing. Corners, never a full outline, so focus can't be mistaken for
  a panel's frame. One look for mouse and gamepad.
- **One screen per step:** during the main action only the subject, the thing being answered, the
  player's options and the result are on screen. Everything else sits behind a key or a tab.

## Colour structure

```yaml
colour-roles:
  ink:       outlines, body text, the dark of every panel
  paper:     the interface material: panels, bubbles, cards
  accent:    ONE job, named by the game (what the player fights with or acts on now)
  signal:    [2–5 kinds]   # only on their own chips; each chip also names its kind
  shadow:    the one hard shadow tone of the cast; halftone lives inside it
  container: optional; one secondary material for one place (a ledger, a map case)
  stage:     [by material]   # wood, plaster, stone, cloth, metal… as the setting needs
colour-rules:
  - contrast(ink, paper) >= 7
  - contrast(ink, signal-*) >= 7          # ink text sits on every signal fill
  - value(stage-*) <= 0.30 at night; <= 0.60 for a daylight stage
  - chroma(stage-*) <= 0.15
  - chroma(stage-*) < chroma(shadow) < chroma(accent)
  - accent is not reused by any signal
  - value(shadow) <= 0.25; hue distance >= 20° from every stage colour with chroma >= 0.05
# value = HSV V; chroma = S × V; contrast = WCAG ratio
```

The stage is coloured **by material**, never one hue for everything: the wooden things are wood,
the walls are plaster or stone, cloth is cloth. A single-hue stage reads as a filter laid over the
scene, not as a place. `example-palette.gpl` is one instance, not the default.

## Pitfalls

- **The first background is almost always too busy.** Bright windows, glowing lights, small detail
  and halftone on the stage all compete with the cast. Keep one rejected busy frame as the "don't".
- **A stage prompt that names one colour family** turns everything that colour. Name colour by
  material instead.
- **Score breakdowns and labels sprawl.** Show the number the player needs; animate how it came
  about instead of spelling every term.
- **Tilt everything and nothing reads as tilted.** Tilt cards and small labels; keep what the player
  reads to decide upright.
- **No seeds, no consistency.** With image models that take no seed, consistency comes from the
  prompt core plus reference images chained in a fixed order (character → scene → busiest screen).
- **Keying.** Generate cast art on a flat backdrop in a colour absent from the cast, and key it out;
  pick that colour per game.

## Variations

- **Material swaps** for the interface: receipts and tickets; posters and tape; cardboard and
  marker; enamel signs and stencils.
- **Daylight stage:** stage values up to 0.60, chroma ceiling unchanged; the cast still leads.
- **Two-tone cast:** drop the signal colours to one accent and ink; suits a game with few kinds.
- **Title treatments:** stamped, stencil-cut, label-maker tape, or letters cut from different
  scraps. The last is a well-known signature of one game's interface, so use it as an accent for the
  loudest moment only, never as the whole interface's identity.

## Make it your own

The look must never become one game's look. A game in this style changes, from the example:

- the palette: every role re-chosen for its tone (the example palette is never shipped as is);
- the fonts and the title treatment;
- the interface material, or at least its documents (what the panels are in the fiction);
- the setting, the cast's designs and the stage's materials.

art-direction's critic checks these four before approving the style guide.

## Evidence

Built and playtested in a 2D game in development, at 1080p and on a handheld, in the fixed-stage
framing, in Godot. Contrast values above were measured in the engine.

## Inspired by

Comic and zine collage; screen-printed gig posters; Danganronpa (a tame stage under a loud cast);
Persona 5 (tilted cut-paper panels). Use them for principles only: no characters, logos, layouts or
trademarks from them.
