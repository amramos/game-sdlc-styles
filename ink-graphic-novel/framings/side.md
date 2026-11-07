# Framing: side view (not yet built)

A side-on scene the player moves through: a platformer, a side-scrolling adventure, a brawler, or a
point-and-click room seen face on.

- **Camera:** orthographic or a flat 2D world; follow with a dead zone 160×120 px around the player,
  lerp 0.12 per frame at 60 fps, look-ahead 80–120 px in the facing direction. Vertical follow only
  on landing.
- **Layers:** 2–3 parallax backdrops at 0.25 / 0.5 of camera speed in `field-1` and `field-2`,
  thin lines (×0.6) and no black masses beyond the sky's silhouettes; the play layer carries the
  full contour weight and the masses. The play layer is the only one with cast shadows.
- **Light:** key light from the upper side opposite the travel direction (from the left for a
  left-to-right game), so the player's black mass faces where they are going and the leading edge
  is lit.
- **Walkable surfaces:** a 4–6 px `paper` or `field-3` lit top edge on every floor and ledge; the
  face under it is hatched or solid ink. Players read platforms from that edge.
- **Characters:** 120–200 px tall at 720p so the brush contour and black mass survive; under 80 px
  the shadow side collapses into a blob (use a thinner `wMax` of 4 px and a single mass shape).
- **Panels in play:** cut-ins for story beats as panels sliding over the scene (recipe, motion),
  with the game paused; never more than one at a time.
- **Interface:** a caption strip along the top; nothing in the bottom 120 px where the player is.

**Expected pitfalls:** animating the black mass frame by frame by hand makes it flicker; compute it
from the shape and the light (the recipe's offset copy) so it moves with the pose. Long scrolls with
a ramp swap per area need the swap to happen at a panel border or a cut, not mid-screen. Fast
motion needs the contour to stay on: never motion-blur.
