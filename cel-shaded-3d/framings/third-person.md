# Framing: third-person (not yet built)

A perspective camera behind and above one character the player steers through the world.

- **Camera:** vertical FOV 50° (about 80° horizontal at 16:9); 4.5 m behind the character, 1.8 m
  above the feet, looking at a point 1.3 m up and 0.4 m to the side, so the character stands
  slightly off centre and fills about a third of the screen height. Near plane 0.1 m, far 250 m.
- **Follow:** position eases with a 0.15–0.25 s lag; rotation leads, position follows. Pull in to
  2.5 m when a wall is behind, never through it.
- **Outlines:** the distance falloff matters most here: 3 px to 12 m, 1 px at 60 m, faded into
  fog by the fog end. The character stays at full width at every camera distance.
- **Key light:** relative to the world, not the camera; pick its yaw so the main route is walked
  with the light from the side for most of its length.
- **Fog:** start 75 m, end 250 m; distant landmarks keep their silhouette but lose their lines.
- **Staged moments:** narrow the FOV to 30–35° and hold the camera still; the bands and outlines
  read best on a still frame.

**Expected pitfalls:** orbiting the camera swings the band edge across the face (face normals fix
it); the camera inside a hull outline near walls draws a black screen edge (fade the outline's
alpha under 0.6 m from the near plane); speed lines and particles with outlines turn into noise.
