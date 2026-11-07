# Framing: isometric (not yet built)

A high, fixed-angle view over a grid: the default framing for this look, and the one demo.html
renders.

- **Camera:** orthographic. Yaw 45°, pitch 35.264° (true isometric, `atan(1/√2)`); 30° pitch for a
  flatter, more diorama read. View height 9–12 tiles for the whole settlement, 4–6 for close work.
  Zoom in steps of 1.25×, eased 0.3–0.5 s. Rotation, if allowed, in 90° steps only, so the grid
  always reads the same way.
- **Light:** the sun 60–90° off the camera's yaw, so every object shows one lit and one shaded side
  face as well as its top. With the sun behind the camera, the sides go flat and the facets vanish.
- **Fog:** orthographic depth is constant across the screen per row, so fog fades the back rows only;
  set it to start just behind the play area (about 20% at the farthest corner).
- **Tilt-shift:** focus line at 0.45–0.5 of screen height, with strength from the recipe. It sells the
  miniature here more than anywhere else.
- **Interface:** in screen space, never on the ground plane. Tooltips anchor beside the hovered tile
  on the side away from the screen's centre.
- **Building:** the cursor ring and ghost follow the tile under the pointer; on a gamepad, the cursor
  steps one tile per press, with a 0.15 s repeat.

**Expected pitfalls:** tall pieces at the front hide tiles behind them (fade anything between the
camera and the cursor to 35% opacity); a perfectly square island looks like a board game, so break
its outline with a few missing or added edge tiles; at isometric pitch, top faces and side faces of
the same material sit close in value, so check the 1.7× lit-to-shadow ratio in a capture.
