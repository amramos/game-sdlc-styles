# Framing: isometric (not yet built)

An orthographic camera looking down at a fixed angle over a small patch of world, like a diorama.

- **Camera:** orthographic, 30° below horizontal (true isometric is 35.26°), yaw 45°. View height
  14–24 m of world at the default zoom; 2–3 zoom steps, each ×1.5.
- **Outlines:** no distance falloff (everything is at one scale); scale width with zoom instead:
  2.5 px at the default zoom, 1.5 px at the farthest. Terrain tiles get no outline between tiles,
  only where height changes.
- **Key light:** yaw 30–60° off the camera's, elevation 50°, so the three faces a box shows get
  three different values: top lit, one side lit, one side shade. With the light straight behind
  the camera every face is lit and the bands vanish.
- **Fog:** by height, not distance: from `sky-horizon` at the lowest layer below the world to clear
  at ground level, so island edges float.
- **Characters** are small (60–120 px tall at 1080p): use the single band plus rim variation,
  1.5–2 px outline, and enlarge heads to 1/3.5 of height to keep faces readable.
- **Shadows:** a fixed orthographic shadow map over the visible area; blobs under characters
  as flat ellipses in the shade colour where the map is too coarse.

**Expected pitfalls:** small props at small zoom with outlines turn into ink speckle (cull lines
under 12 px); flat ground facing the camera is one band across the whole screen (break it with
height steps and paths, not texture noise); the shade side of tall objects hides doors and paths
(face entrances toward the lit side).
