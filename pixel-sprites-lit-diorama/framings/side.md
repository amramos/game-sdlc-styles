# Framing: side (not yet built)

A route walked from left to right through a row of small dioramas, the camera following.

- **Camera:** perspective, field of view 30–40°, yaw square to the route, pitch 8–15° down, at 10–14
  units; follows the player with a dead zone of 20% of the width and a lag of 0.2–0.3 s.
- **Depth:** three layers: the walkable strip, set pieces behind it at 2–6 units, the backdrop.
  Sprites walk only on the strip, so contact discs always land on the floor.
- **Sprites:** side views only; flip for direction. At the low pitch the billboards face the camera
  almost square, which suits them best.
- **Tilt-shift:** focus on the strip (0.30–0.35 of height), amount 2.0; it slides with nothing, as
  the strip stays at the same height on screen.
- **Light:** each diorama carries its own lighting scheme; blend fog colour, fill and key over 1–2 s
  across the boundary between two.

**Expected pitfalls:** with a low pitch, the floor shows little and the miniature read weakens (keep
at least 8°); pieces in front of the strip hide the player (keep them below the sprite's knees or
fade them).
