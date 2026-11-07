# Framing: top-down (not yet built)

A steep three-quarter view from above, for tactics, stealth, management on a map or a board, and
investigation scenes read as a whole.

- **Camera:** pitch 55–70° (a true 90° hides every side and the masses vanish), FOV 25–35° if
  perspective, or orthographic. North up; no free rotation, so the light direction stays fixed on
  screen.
- **Light:** from the top left of the screen; every object's black mass and cast shadow fall
  down-right, 0.3–0.6× the object's height long. Those shadows show height on a flat map.
- **Tops carry the read:** roofs, heads and lids are the lightest field step (`field-3` or `paper`),
  side faces `field-1` or solid ink. Keep a contrast of at least 1.4 between tops and the ground.
- **Ground:** one field step, with hatching along walls and under cover (a 40–60 px band) to show
  depth without gradients.
- **Units and pieces:** 48–80 px across at 720p; contour `wMax` 5–8 px. Selection is an inverted
  caption label or a heavy ink ring, never the accent, which stays for the one focal thing on the
  board.
- **Interface:** caption boxes in screen space along the edges; panels open beside the board, not
  over it, and a close-up panel shows the selected piece in the side framing's scale.

**Expected pitfalls:** many small black masses on a map read as noise; merge shadows of neighbouring
objects into one shape and keep the black share at the 25–45% target over the whole screen. Hatching
that scrolls with the map shimmers; draw it in world space and keep its spacing at 8 px or more.
