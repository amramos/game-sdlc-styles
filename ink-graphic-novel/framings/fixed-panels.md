# Framing: fixed panels (built in a prototype)

The screen is a comic page: two to four fixed panels, each a still or gently animated picture, with
the interface as captions in the gutters and over the art. The player reads the page and acts on
it (choices, assignments, a board of items) rather than steering a figure. This is the framing the
look was built and played in, and the one `demo.html` renders.

- **Page grid at 1280×720:** one main panel 55–70% of the screen (840×520 in the demo), one or two
  side panels for a close-up or a second place (392×252 each), an interface band 150–170 px tall
  along the bottom. Gutters 16 px.
- **Panel kinds:** an establishing panel (wide, the place and who is in it), a close-up panel (a
  face, hands, an object, for decisions), and an extreme close-up for big choices (only the eyes
  and brow, full-bleed, in two strips, with the choices as captions).
- **Design every panel at a fixed size** and scale it to cover its frame; crop, never squash.
  Captions are laid out in panel space so they scale with it.
- **A focus panel** (a window, a monitor, a keyhole, binoculars): sharp and in colour inside a
  round or framed area; outside it, the same picture darkened by one ramp step and covered in ink
  hatching every 9 px.
- **Distance by size:** a thing nearing the player grows in steps (recipe, motion) and its line
  weight grows with it, which reads as distance without perspective.
- **Flashback panels:** the same art with the ramp swapped one step darker and the accent removed.
- **Mixed panels:** a toon-3D panel (recipe, "Toon 3D in ink") beside drawn panels works if its
  ink edge width matches the drawn contours within about 1.5×. A steep three-quarter view
  (pitch 60–70°, FOV 30°) keeps 3D objects graphic.
- **Interface:** choices as caption buttons in the bottom band, status chips beside the band's
  title, a pinned note for hints. Nothing floats over the main panel but captions and sound words.

**Pitfalls seen in the prototype:** small diagrams over a dark panel were hard to read until they
sat on a plate (`ink` at about 60% opacity, the one allowed overlay) and were drawn bigger; more
than about three floating labels on one panel turned it into a list, so the picture itself must
change (a light, a figure moving, weather) and labels stay one word; an accent light spilled across
a ramp of another hue mixed into a third colour after posterising.
