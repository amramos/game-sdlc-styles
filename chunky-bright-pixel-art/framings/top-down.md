# Framing: top-down (not yet built)

A three-quarter top-down view (front faces of objects visible), as in exploration, farming or
action-adventure games.

- **Camera:** 320×180 base, follow the player with lerp 0.1–0.15 and round; clamp at the map edges;
  no zoom (zoom changes the pixel size). Show 20×11 tiles of 16×16.
- **Tiles:** 16×16; ground in the calmest ramp steps, walls and objects with a front face 4–8 px
  tall in a darker step than their top. Wall tops are not outlined where they meet another wall.
- **Draw order:** sort by the y of each sprite's feet; a sprite taller than 16 px overlaps the tile
  above it.
- **Character:** 16×24 box, 4 directions (down, up, side, side flipped); walk 4 frames per direction
  at 8 fps. A ground shadow 2 rows tall under every moving thing.
- **Light:** still upper left, so shadows fall down-right as flat shapes in the ground's darker step,
  1–4 px long.
- **Interface:** corners only (coins top-left, time top-right), panels for menus; the centre of the
  screen stays clear.

**Expected pitfalls:** large flat ground areas look empty, while filling them with single-pixel
noise flickers — use clusters (tufts, stones, ripples) on a 1 in 3 tiles spacing; up- and down-facing
sprites lose their silhouette, so give the back view a distinct shape (a hood, a pack); diagonal
movement at 1 px per frame per axis looks faster than straight movement unless normalised and rounded.
