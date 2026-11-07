# Framing: third-person (not yet built)

A perspective camera behind and above one character the player steers.

- **Camera:** vertical FOV 50°; 4 m behind the character, 1.7 m above the feet, looking at a point
  1.2 m up, so the character fills about a third of the screen height (80 low-res lines). Near
  0.1 m, far 300 m.
- **Follow:** position eases with `1 − exp(−dt × 5)`; yaw leads by up to 15° when turning. Pull in to
  2 m against walls, never through them.
- **What the core changes:** the character is the one object always in view; give it 300–500
  triangles and a 64 px texture so it keeps its read at 80 lines tall. Vertex jitter on the moving
  character is part of the look; keep the camera smooth so the world doesn't jitter twice.
- **Fog:** start 15–25 m, end 40–70 m for open levels; the fog end sets the draw distance.
- **Light:** a directional key relative to the world; pick its yaw so the main route has it from the
  side. Local lights mark paths and pickups.
- **Staged moments:** narrow the FOV to 35–40° and hold the camera still.

**Expected pitfalls:** the character's feet float without a contact shadow (a dark 8-sided disc,
0.6 × the footprint, 1 cm above the ground); the camera inside the fog start on narrow paths turns
everything near grey; affine warp on the ground is strongest right below the camera, so split the
ground every 1–2 m.
