# Framing: isometric (not yet built)

A wider set or a small district seen from a high diagonal, scrolling or rotating in steps.

- **Camera:** keep perspective (field of view 30–35°) rather than orthographic: tilt-shift and fog
  need depth to sell the miniature. Yaw 45°, pitch 30–35° down, distance so the visible area is
  15–25 units wide. Rotation, if any, in 90° steps eased over 0.4 s.
- **Sprites:** with the camera rotating, yaw-only billboards turn with it; draw two facings (front
  and back three-quarter) and pick by the angle between the sprite's heading and the camera.
- **Light:** key 60–90° off the camera's yaw so every block shows a lit and a shaded side; rotate
  the key with the camera or the set's read changes per view.
- **Tilt-shift:** focus 0.45, amount 2.0; the higher pitch shows less sky, so the backdrop shrinks
  to a strip or is replaced by fog alone.
- **Interface:** captions as on the fixed stage; the panel layout moves to the corners to keep the
  diagonal of the set clear.

**Expected pitfalls:** tall pieces in front hide sprites (fade anything between the camera and a
selected sprite to 35%); at 45° yaw, billboards face the camera at an angle to the grid, so align
contact discs and rings to the floor, never to the sprite.
