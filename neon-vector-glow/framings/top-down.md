# Framing: top-down arena (not yet built)

A twin-stick arena seen from straight above: the grid is the floor, and the whole fight fits on one
or two screens. `demo.html` draws this framing.

- **Camera:** orthographic, straight down, no tilt. Either fixed on an arena that fits the screen,
  or following the player with a dead zone of 20% of the screen height and a lag of 0.15–0.25 s,
  clamped to the arena edge. Never rotate the camera.
- **Arena size:** 1–2.5 screens wide. Larger arenas need an edge indicator: a 4–6 px tick in the
  enemy's colour and shape on the screen edge for each off-screen threat within one screen.
- **The grid is the floor:** square or hexagonal, pinned at the arena wall; the wall is a 4 px line
  in the grid colour at 100%, the only background line drawn that strong.
- **Lead room:** a following camera leads 10–15% of the screen toward the aim direction, so the
  player sees what they shoot at.
- **Spawns:** enemies appear with a 0.5–0.8 s spawn mark (their outline drawing in at 30% alpha)
  and never within 15% of the screen height of the player.

**Expected pitfalls:** threats from every direction at once make particle clouds the main hazard to
readability, so the spark cap matters most here; a following camera plus grid warp plus shake reads
as nausea, so with a following camera halve the shake.
