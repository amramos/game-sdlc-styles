# Framing: top-down (not yet built)

A steep view from above, for games that need the whole map's layout at a glance (routes, networks,
zones). demo.html's "Top-down" button shows it.

- **Camera:** perspective, field of view 25–35°, pitch 60–65° below the horizon, yaw 0° (north up).
  Distance so the play area fills 85–90% of the screen height. A true 90° view hides every side face
  and the toys read as flat discs, so stop at 70°.
- **What the core changes:** tops carry the whole read. Caps, roofs and canopies take the strongest
  value contrast against the ground (keep `contrast(path, ground) >= 1.4` and give buildings'
  tops a value at least 0.15 away from the ground's). Side details (doors, windows) shrink in
  importance; put identifying marks on the top face instead.
- **Light:** sun elevation 55–65°, from the upper left of the screen, so shadows fall down-right
  and give every piece a short visible shadow that shows its height.
- **Fog:** the far edge is now the top of the screen; start fog at the back row's distance, reaching
  about 20% at the top edge.
- **Tilt-shift:** strongest in this framing: focus line at 0.45 of screen height, blur growing toward
  the top and bottom. Turn it down by half when routes must be read across the whole map.
- **Interface:** counters along the top, build menu along the bottom; the map's busiest band is the
  middle, so the long tooltip sits at the side.

**Expected pitfalls:** with perspective, pieces at the screen's edges lean outward; keep the field
of view at 35° or less. Paths and roads become the dominant shapes; their colour must stay inside
the pastel ceiling or they take over the frame. Markers over usable things can overlap tops; float
them higher (0.4 unit) and keep them unlit in `accent`.
