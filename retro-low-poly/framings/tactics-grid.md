# Framing: tactics-grid (not yet built)

A raised three-quarter view over a grid of tiles, with units moving turn by turn.

- **Camera:** perspective, vertical FOV 30–35° (flattens the board but keeps the swim), pitch −40° to
  −50°, distance so 10–14 tiles span the screen width. Rotate in 90° steps, eased over 0.4 s.
- **Tiles:** 1 m, each a box split once; texture tile 1 m, so one 32 px texture per tile.
- **What the core changes:** at this distance a unit is 25–40 low-res pixels tall; give units big
  heads or hats and a team colour on the largest part. The grid itself is drawn in the texture, not as
  lines (thin lines break into dots under dither).
- **Highlights:** move range as tiles tinted with an additive `accent` pulse; attack range in a
  `signal` colour, with its kind shown on the interface too.
- **Fog:** start beyond the board's far edge, end 2× the board depth; the board edge falls away.
- **Light:** a directional key from 45° to the camera's yaw so tile heights show; ambient ≥ 0.35.

**Expected pitfalls:** affine warp makes long tile rows bend as the camera rotates (split tiles,
and keep the FOV ≤ 35°); vertex snap shakes units at rest (snap only while the camera moves, or
accept it as the look).
