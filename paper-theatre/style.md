---
id: paper-theatre
version: 1
name: Paper theatre
---

# Paper theatre

## The look

A toy theatre seen from the audience. A printed proscenium frames a box stage, and everything
inside is flat printed card: an engraved back cloth, ground rows and wings stepping back in layers,
and cut-out figures and props with a cream paper border and a dark card edge, each held on a slide,
a wire or a card foot. The prints are hand-tinted engravings: ink outlines and hatching over flat,
muted tints. Real 3D lights do the rest: the cut-outs' silhouettes cast shadows on the layers
behind, and the same printed set becomes a sunny matinee or a threatening night by changing only
the lighting plot. Text is printed on paper slips pinned to the frame, flown on wires or tagged to
figures.

## Signature elements

1. **A fixed proscenium.** One printed arch frames the stage and never moves; everything happens
   inside the box.
2. **Cut-outs with a paper edge.** Every piece has a cream border (4–5 px at 720p) and a dark card
   edge offset away from the key light, and shows how it is held.
3. **Engraved prints.** Ink outlines and parallel hatching over flat tints, lit from one side.
   Darkness comes from denser hatching and less light, never from a dark tint.
4. **Depth by stagecraft.** Back cloth, three ground rows, wings, the cast, the frame; each row
   stands further from the back cloth's colour as it comes forward.
5. **Real light as the mood channel.** The colour, angle and balance of the lights set the mood of
   an unchanged set; the cast's shadows fall on the rows behind.

## Readability and interface

- **Every word is live text on a paper slip:** ink on paper, 16 px minimum at 720p, an old-style
  serif with small caps for names. Never paint words into a print.
- **The interface is stage furniture:** slips pinned to the pillars, dialogue and choices flown in
  on wires, tags under figures, a detail card beside the figure under the pointer. No strip of
  cards clipped along a screen edge.
- **Readable in any light:** text printed into the scene gets an emissive floor of about 35%.
- **The accent has one job:** what the player can act on now (an unlit marker above a figure, the
  focused choice). Decor never carries it.
- **Signal inks** appear only as chips with a symbol and a word.
- **Hit areas** are the cut-out's rectangle plus 8 px, not its alpha shape.
- **Never truncate:** names wrap inside their slip; every slip has its own lane.

## Colour structure

```yaml
colour-roles:
  house:      the surround outside the frame
  proscenium: the frame's printed card
  boards:     the stage floor
  backdrop:   [backdrop-sky, backdrop-ground]    # the tint under the back cloth's engraving
  depth:      [depth-far, depth-mid, depth-near] # ground rows and wings, back to front
  paper:      cut-out borders and text slips
  ink:        outlines, hatching, printed text
  card:       the dark card edge behind each cut-out
  tint:       [by material]       # cloth, wood, skin, fur… as the setting needs
  accent:     ONE job: what the player can act on now
  signal:     [good, bad, info]   # chips on slips; each also says its kind
  light:      [light-key, light-fill, light-foot]   # the game's lighting plot
colour-rules:
  - contrast(ink, paper) >= 7
  - contrast(ink, tint-*, backdrop-*, depth-*) >= 3     # the engraving reads on every print
  - contrast(paper, card) >= 4.5                         # the edge shows behind the border
  - max(contrast(paper, X), contrast(card, X)) >= 3 for X in backdrop-*, depth-*, boards
  - contrast(depth-far, backdrop-sky) < contrast(depth-mid, backdrop-sky) < contrast(depth-near, backdrop-sky)
  - chroma(tint-*, backdrop-*, depth-*, proscenium) <= 0.55
  - chroma(accent) >= max(chroma(tint-*, backdrop-*, depth-*, proscenium)) + 0.15
  - huedist(accent, any tint-*, signal-*) >= 30          # skip roles with chroma < 0.1
  - contrast(signal-*, paper) >= 4.5 and chroma(signal-*) >= 0.25
  - contrast(proscenium, house) >= 2
  - value(light-key) >= 0.8
# value = HSV V; chroma = S × V; contrast = WCAG ratio; huedist = HSV hue difference in degrees
```

The rules keep only structure: legible engraving, edges that separate, receding rows, one accent
above muted tints. Brightness and mood belong to the lighting plot. `example-palette.gpl` is the
demo's matinee; its night scheme passes the same rules.

## Pitfalls

- **A row of cards along the bottom edge reads as a menu bar.** Hang choices on wires, pin them to
  the frame or stand them whole on the stage.
- **Flown cards in one lane overlap and show through.** One lane and an opaque fill per slip.
- **Lit-only text vanishes when the light drops.** Use the emissive floor or the screen-space layer.
- **Small figures on a busy set are hard to hit.** Spread them out; pad the hit areas.
- **Post effects over text** make slips noisy. Composite the interface after post.
- **Mixed art scales show the seam.** A pixel sprite, an airbrushed figure or a real 3D model among
  engraved prints breaks the sheet. One print technique, one line weight, one paper edge.
- **A cut-out without its edge** looks like a sticker floating in 3D.
- **Rectangular shadows** give the trick away: the shadow pass must use the texture's alpha.
- **Dark tints hide the engraving.** Darken with hatching and light instead.
- **Feedback off the stage reads as broken.** Every action gets a visible paper response.
- **Image generators** paint a box behind any opening and lay paper sheets behind pieces.
  Generate one piece at a time; cut openings and add edges in code.

## Variations

Lighting plots, chosen by each game:

- **Matinee:** warm-white key, soft fill, low footlights; bright, playful, storybook.
- **Night:** a cold key high on one side, strong warm footlights throwing shadows up the back
  cloth, a pin spot, a heavier vignette; ominous.
- **Lamplight:** a few warm points and a dark house; intimate.
- **Held moment:** house and side props down to about 10%, one pin spot.

Looks:

- **Mixed cast:** pixel or painted figures, under the same light, shadows and edge.
- **Shadow theatre:** a backlit scrim and black silhouettes.
- **Fairground:** full colour and gilt; lifts the chroma ceiling to 0.75 (note it in the guide).
- **Pop-up book:** the planes hinged on a page; scene changes are page turns.
- **Dither act:** a 4×4 ordered dither to five tones for one place or act, interface excluded.

## Make it your own

A game in this look changes, from the example:

- the palette and the lighting plot (the example palette is never shipped as is);
- the print technique (engraving, woodcut, linocut, lithograph), its line weight and hatch spacing;
- the proscenium's design and which slips its frame carries;
- the setting, the cast's silhouettes and how each piece is held;
- the accent's one job.

art-direction's critic checks these before approving the style guide.

## Evidence

A web prototype, every piece generated separately (`assets/`); not yet in a shipped game.

## Inspired by

Victorian toy theatres and their printed sheets (the frame, layered flats, figures on slides);
hand-tinted copperplate engraving; silhouette cut-out film (a figure read by its outline alone);
Paper Mario and Tearaway (papercraft staging). Principles only: no characters, layouts, logos or
trademarks from them.
