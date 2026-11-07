# Framing: side view (not yet built)

A side-scrolling shooter or platformer: the action moves across the screen and the grid becomes a
backdrop and a floor.

- **Camera:** orthographic, side on. Auto-scroll at 15–30% of the screen width per second for a
  shooter; for a platformer, follow with a dead zone of 25% of the width and 30% of the height.
- **The grid splits in two:** a far grid (spacing 1.5× the near one, value × 0.6) scrolling at
  0.3–0.5× parallax, and the near grid that warps. Only the near grid takes impulses.
- **A ground line:** platforms and floors are core lines with halos in a role of their own
  (`terrain`), at value 0.5–0.7 and chroma ≤ 0.3, so they glow less than any gameplay object.
  Add `terrain` to the colour-roles with that rule.
- **Gravity sparks:** sparks get 600–900 px/s² downward, so bursts fall and read as weight.
- **Screen space:** keep the leading 40% of the screen (in the scroll direction) clear of HUD.

**Expected pitfalls:** a scrolling grid moves under everything and can read as motion of the
gameplay objects; keep the far grid dim and slow. Terrain that glows like the cast blurs the
line between what can be stood on and what hurts.
