# Framing: tabletop (built in a prototype)

The player sits at the table and looks down across it at the miniature: the framing this look was
built in, and the one `demo.html` renders.

- **Camera:** perspective, field of view 36°, near 0.1, far 60. For a flat board with low pieces,
  (0, 5.3, 6.1) looking at (0, 0, 0.05): about 41° down, 8 units from the centre of a 7 × 4.25
  base. With buildings up to 2.5 units tall at the back, pull back to (0, 7.0, 8.2) looking at
  (0, 0.35, −0.3): 38° down, 10.8 units away, as `demo.html` does. The base fills 70–85% of the
  frame's width and the tallest roof stays below the top 10%. No player control of the camera;
  idle sway and shake from the recipe only.
- **Light:** a lamp key as a spot at about (0.4, 8.4, 0.6), aimed at (0, 0, −0.5); or a window key
  as a directional light from one side at 30–55° up. The far third of the base must stay inside the
  key's pool, or get a practical light behind it.
- **Fog:** starts just past the base's far edge (11 units from the near camera, 14 from the far
  one), full at about 1.7× that.
- **Tilt-shift:** focus line at 0.46 of the screen's height, full radius 5 px at 720p. The near
  edge blurs at 30% strength, so pieces at the front stay readable.
- **Interface:** cards slide in at the screen's sides, slightly rotated, never over the base's
  centre. One spoken line sits high, over the room, where the scene is darkest or emptiest. Rings
  and tokens sit on the base itself.
- **A hand from outside (optional):** a painted cut-out hand reaching in from the camera's side to
  place, swap and remove pieces. A camera-facing plane, alpha test 0.35, with a depth material so
  it casts a shadow on the table.
- **Pieces off the board:** a row of figures waiting their turn on a bench or tray at the front
  edge, so the cast stays visible without a panel.
- **The room can go dark.** With the key alone and the room factor at 0.3 or lower, the table is
  the whole world. Offer a setting that brings the room light up, for players who need it.

**Pitfalls seen in the prototype:** drop targets measured by screen distance to a model's base
landed off the visible piece; tall pieces at the back covered targets placed behind them; pieces
at the far edge fell into shadow; a place that existed only on a side card was never found.
