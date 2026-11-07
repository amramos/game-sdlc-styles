# Framing: isometric, tactics grid (not yet built)

A fixed-angle pixel isometric board, where the player reads the whole state at once and decides
turn by turn.

- **Projection:** pixel 2:1 isometric (lines step 2 across, 1 down). Tile top 32×16 px, block
  height 8–16 px. Screen position: `x = (col - row) * 16`, `y = (col + row) * 8 - height * 8`.
- **Base:** 480×270 or 640×360 (an 8×8 board at 32×16 needs about 256×144 plus the interface). The
  board is centred and does not scroll in a single battle; if it must, it moves in whole tiles over
  6–8 frames.
- **Tile tops** are the lightest step of their material, the left face one step darker, the right
  face two steps darker (light from the upper left).
- **Units:** 24×32 box standing on the tile's centre; idle 2 frames at 3 fps so the board is calm;
  every unit is readable as a solid ink silhouette at that size.
- **Readability first:** tile highlights (move range, attack range, danger) are 1 px inset outlines
  or a 50% checker in the role colour on the tile top, never filled tops. Danger uses `signal-bad`,
  move range the `accent`'s one job if movement is what the player acts on. A preview of each
  action's result (damage numbers on chips, push arrows) shows before the player commits.
- **Interface:** unit cards and the turn order in screen-space strips at the bottom and left edge;
  numbers in the 3×5 font, never smaller.

**Expected pitfalls:** 2:1 lines drawn by a line tool come out uneven (1-2-1-3) — draw them with a
strict 2-pixel step; tall units hide the tiles behind them, so draw a 1 px outline of a hidden unit
through the occluder or keep units under 2 tiles tall; too many highlight colours on the board at
once — show at most two overlays at a time.
