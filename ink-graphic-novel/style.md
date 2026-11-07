---
id: ink-graphic-novel
version: 1
name: Ink graphic novel
---

# Ink graphic novel

## The look

A game that reads as a printed comic: heavy solid black masses, thick brush outlines and flat
fills with no gradients, on a short ramp of three field tones. Shadows are black shapes cut into
the form on the side away from the light; middle tones, where needed, are ink hatching. The screen is laid out as panels with paper gutters
and lettered in caption boxes with a hard offset shadow, so the interface is part of the page. One
saturated accent marks the focal point of each picture. The palette, the lighting and the mood
belong to the game: the same ink carries a stark cold night, a bright pulpy afternoon or a grey
noir.

## Signature elements

1. **Spotted blacks.** 25–45% of each picture is solid ink: shadow sides, cast shadows, dark
   clothing, night windows. A form's shadow is one shape, never a soft ramp.
2. **Brush contour.** Outlines swell from thin on the lit side to two or three times as thick on
   the side away from the light, with tapered ends. Interior lines are thinner than contours.
3. **Flat fills from a short ramp.** Three field tones, paper and ink do the whole world; hatching
   in ink is the only middle tone. No gradient or airbrush; paper may carry a faint grain.
4. **One accent per picture,** on the thing that matters in it. Every other colour is the ramp,
   paper or ink.
5. **The page is the interface.** Panels with an ink border and paper gutters, caption boxes, sound
   words and pinned paper notes; no floating app widgets.

## Readability and interface

- **Every word and number is live text** in a hand-lettered face (capitals for captions) or a
  small-caps serif for titles. Never letter into generated art.
- **Narration in caption boxes** (3 px ink border, 5 px hard ink offset; inverted for a log).
  Choices are torn paper slips; a question is bare title lettering. No blur, glass or rounded
  panels.
- **Smallest text:** 16 px at 720p (24 px at 1080p), notes included.
- **Text on art** sits in a box or has a 4–8 px ink stroke under a paper fill.
- **Focus is a lift, not colour:** the focused slip rises on a longer shadow and is underlined; a
  pressed one drops into its shadow. The accent belongs to the picture.
- **State as ink icons with numbers** (a battery with charge cells, wind streamlines); signal
  colours fill only cells and stamps, never letters.
- **Unavailable is drained:** no shadow, a field-coloured edge, the reason in words.
- **Urgency through the page:** a sound word, a bigger panel, a shake; not a red interface.
- **Silhouette test:** every cast figure filled solid ink must still say what it is and which way
  it faces.

## Colour structure

```yaml
colour-roles:
  ink:     black masses, contours, hatching and letters; value near black
  paper:   gutters, caption boxes, highlights, sound words
  field:   [field-1, field-2, field-3]   # the world's flat fills, dark to light; swapped wholesale per chapter or scene
  accent:  ONE job, named by the game (the focal point of each picture)
  signal:  [alert, ok]                   # meter cells and stamps only
colour-rules:
  - count(colours) == 8                  # per palette; shadows and hatching are ink, never a new tone
  - value(ink) <= 0.12
  - contrast(ink, paper) >= 12
  - value climbs along field-1..3, and contrast(step n, step n+1) >= 1.4
  - contrast(field-1, ink) >= 1.3        # the darkest fill still parts from the black masses
  - contrast(field-3, ink) >= 5
  - chroma(field-*) <= 0.50 and chroma(paper) <= 0.20
  - chroma(accent) >= 0.60 and chroma(accent) >= max(chroma(field-*)) + 0.15
  - huedist(accent, field-*) >= 40       # skip fields with chroma < 0.1
  - contrast(accent, ink) >= 5           # the focal point reads against a black mass
  - contrast(ink, signal-*) >= 4.5
  - huedist(accent, signal-*) >= 30
# value = HSV V; chroma = S × V; contrast = WCAG ratio; huedist = HSV hue difference in degrees
```

Only the black masses and the single accent are structural; cold or warm, dark or bright is the
game's call. `example-palette.gpl` (stark night) is one instance; `demo.html`
also has a pulp daytime and a grey noir palette that pass the same rules.

## Pitfalls

- **Grey instead of black.** Shadows in a dark field tone, or softened, turn the frame muddy and
  ordinary. Shadows are ink.
- **Even, thin outlines** read as a vector diagram. Weight the contour by the light, at least 3 px
  at 720p.
- **Two focal colours.** A second accent object, a highlighted button or a coloured effect splits
  the eye. Hold interface highlights in ink and paper.
- **An accent light spilled on another hue mixes into a third colour** (orange light over a violet
  field reads as pink). Keep the accent on its own hard-edged shapes, or retune its spill for each
  ramp.
- **Labels piled on the art become a menu.** Past about three floating captions a picture reads
  as a list. Show a change in the picture and keep labels to a word.
- **Image models letter everything.** Put "no text" in every prompt and check every result.
- **Generated art drifts painterly,** and keyed cutouts keep coloured fringes on ink edges; the
  recipe gives the denoise window and the despill.
- **Silent interaction.** Answer every action in the page's language: a shake, a stamp, a sound
  word.

## Variations

- **Lighting schemes:** one hard focal light in a dark field (the accent is the light, with a hard
  rim on whoever holds it); flat daylight with no rim; overcast grey. The game's guide names one.
- **Monochrome plus one spot colour:** grey fields, for noir or horror.
- **A ramp per chapter:** swap the three field tones wholesale while ink, paper and the accent stay;
  one set of art then serves every chapter.
- **Halftone dots** instead of hatching for a printed finish.
- **Toon 3D in ink:** a 3D object through a stepped light and an edge pass, in the same panels.
- **Wilder pages:** irregular panels, panels breaking their border, speech balloons.

## Make it your own

A game in this look changes, from the example:

- the palette: every role re-chosen for its tone (the example palette is never shipped as is);
- the lighting scheme and the accent's one job;
- the lettering and title faces, the caption box shape and the panel grid;
- the setting, the cast's designs and silhouettes, and the share of black in each picture.

art-direction's critic checks these before approving the style guide.

## Evidence

Web prototype only. Its art is generated and snapped to the roles; one set serves every palette by a
luminance remap (`assets/README.md`).

## Inspired by

Comix Zone (play inside comic panels), XIII (lettered sound words and panel insets over 3D),
Sayonara Wild Hearts (a colour world per chapter), Mark of the Ninja (readable solid darks), and
the spotted blacks, panel layouts and lettering of mid-century horror and pulp comics. Principles
only: no characters, layouts, logos or trademarks from them.
