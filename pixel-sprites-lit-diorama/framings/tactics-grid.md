# Framing: tactics grid (not yet built)

The same sprites and set on a tiled board for turn-based fights or puzzles.

- **Camera:** perspective, field of view 35–40°, pitch 30–40°, yaw 45° by default, rotating in 90°
  steps over 0.4 s; zoom in two or three steps of 1.4×. The whole board fits at the widest zoom.
- **Board:** tiles 1 unit, heights in steps of 0.5 unit; every tile edge shows 2 px of darker
  material so heights read without shadows. Sprites stand on tile centres.
- **Sprites:** two facings (front and back three-quarter), flipped for the other two; facing is game
  state here, so it must read at the widest zoom.
- **Highlights:** move and attack ranges as flat tile overlays 0.02 above the top, additive at 35%,
  range in `accent`, threat in `signal-danger`; never the same hue for both.
- **Tilt-shift:** focus on the selected unit's screen row, amount 1.6; off while choosing a target.
- **Interface:** captions only for the selected unit and its target; everything else in panels.

**Expected pitfalls:** units behind tall tiles disappear (show an outline through occluders in
`outline` at 60%); fog hides the far side of a big board (lower its density for this framing).
