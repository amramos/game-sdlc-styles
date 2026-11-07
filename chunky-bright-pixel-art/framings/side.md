# Framing: side view, platformer (not yet built)

A side-on scene with gravity: the player runs and jumps across a level that scrolls horizontally.

- **Camera:** 320×180 base, follow with a dead zone 24 px wide and 16 px tall around the player,
  lerp 0.15 per frame, look-ahead 32 px in the facing direction; round the camera every frame.
  Vertical follow only when the player lands on a new height (platform snapping), so jumps don't
  bob the screen.
- **Tiles:** 16×16; solid ground has a 2 px lit top edge in the lightest step of its ramp so
  walkable surfaces read at a glance. Background tiles one ramp step darker and without outline.
- **Parallax:** 2–3 backdrop layers at 0.25 / 0.5 of camera speed, in `bg-*` only; the play layer
  is the only one with outlines.
- **Character:** 16×24 box; run 6 frames at 12 fps, jump 3 poses, land squash 2 frames. The hitbox
  is 2 px narrower than the sprite on each side and set in whole pixels.
- **Hazards** use `signal-bad` on a flat part of the sprite (spikes' tips, a glowing core), never on
  the backdrop.
- **Interface:** a top strip 12–16 px tall; nothing in the bottom 24 px where the player usually is.

**Expected pitfalls:** a camera that follows with float positions makes the tiles shimmer; single
pixels of detail on fast-scrolling ground flicker; a backdrop as bright as the play layer hides
platforms. Long falls need the camera to lead downward 32–48 px.
