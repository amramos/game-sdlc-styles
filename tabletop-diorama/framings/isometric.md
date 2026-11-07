# Framing: isometric (not yet built)

A fixed orthographic view over the base, for games that need every piece and tile visible at
once. `demo.html`'s "Isometric" button shows it.

- **Camera:** orthographic, yaw 45°, pitch 30–35° below the horizon. View height 1.4–1.7× the base's
  depth, so a strip of table shows all round. No perspective, so the table's far edge no longer
  falls away: keep the full-size objects at the corners to hold the scale.
- **What the core changes:** without perspective, the narrow-lens read comes from the tilt-shift
  and the scale objects alone. Raise the tilt-shift radius by about 20% and keep the focus line at
  0.45–0.5.
- **Light:** the key 60–90° off the camera's yaw and 50–60° up, so every piece shows a lit side
  and a shaded side. A spot key needs its cone wide enough (half-angle 55–60°) to reach all four
  corners of the base.
- **Fog:** constant per screen row; start it at the table's far edge only, so the base stays clear.
- **Grid:** if the game has one, carve it into the base as shallow grooves (0.01 deep, 0.02 wide)
  instead of drawing lines over it.

**Expected pitfalls:** the room vanishes behind the table, so dark schemes lose their pool-of-light
look (narrow the spot cone and let the corners fall to 30–40% brightness); tall pieces at the front
hide pieces behind them (fade them to 35% when the cursor is behind); identical pieces at one scale
look like a board game's counters, so vary heights and silhouettes.
