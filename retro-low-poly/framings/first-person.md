# Framing: first-person (built in a web prototype)

The player's eyes, usually seated or standing in one place and turning the head; free walking
works with the same values. Built and played in a prototype; demo.html's key scene uses it.

- **Camera:** perspective, vertical FOV 55°, near 0.02–0.05 m, far 300 m, rotation order yaw then
  pitch then roll. Eye height 1.5 m seated on a stool, 1.36 m on a chair, 1.62 m standing.
- **Look limits** for a fixed seat: yaw ±70–100° around the rest direction, pitch −45° to +20°
  (−62° if the player must look down at their hands or a surface in front of them).
- **Easing:** every value eases toward a target, `k = 1 − exp(−dt × 7)` when the player steers;
  FOV eases at 0.6 × k.
- **Input:** drag 0.15°/px yaw and 0.12°/px pitch; arrow keys or stick 70°/s; optional edge-turn
  when the pointer rests within 2.5% (sides) or 3% (top and bottom) of the screen edge for 0.4 s.
- **Idle life:** breathing bob 0.004 m at `sin(0.9t)`; roll sway `sin(0.55t) × 0.018 +
  sin(0.23t) × 0.01` rad × 0.3–0.6. Turn the sway off while the pointer is near a target.
- **Staged moments:** turn the head toward an event with the slower ease (`exp(−dt × 2.6)`),
  narrow the FOV from 55° to 40–46°, hold 2–3 s, then hand control back to the same framing.
  Lock input while it moves.
- **What the core changes:** near props are 0.5–1.5 m away, so their vertex jitter shows most here.
  Keep them chunky (≥ 4 cm details) and split the floor every 1–2 m so the warp near the feet stays
  a swim, not a fold. Fog starts behind the room's far wall, so the room itself stays clear.
- **Walking (if used):** 1.4 m/s, head bob 0.03 m at 1.8 Hz, fog end ≥ 3× the longest sight line
  the level allows.

**Seen in testing:** small objects on a dim surface were hard to find, a camera move that shifted a
target ate the player's click, and repeated staged visits grew tiresome when they came too often.
Space them out and keep them short.
