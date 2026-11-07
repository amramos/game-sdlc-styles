# Framing: on rails, into the screen (not yet built)

The player rides a track or tube toward a vanishing point; enemies and obstacles come out of the
distance. Rhythm and rail shooters sit here.

- **Camera:** perspective, vertical FOV 60–75°, behind and 5–15° above the player, with the
  vanishing point 40–45% down the screen. The track's motion, not camera roll, gives speed.
- **The grid is the track:** a tube, lane or floor drawn as lines converging on the vanishing
  point. Warp it along its length: an impulse travels toward the player with the track, not out
  from a point.
- **Depth by brightness:** line alpha falls with distance, 100% near to 20% at the far end; core
  width shrinks with perspective but never below 2 px; past that, fade instead of thinning.
- **Fog to void:** objects beyond 70% of the draw distance blend toward the void colour, so new
  threats fade in rather than pop.
- **Threats read early:** enemies show their silhouette at 2 s before contact, at ≥ 30 px radius;
  telegraph lanes with a dashed line in the danger colour along the track.
- **Bloom:** 3D engines favour post bloom (see recipe); keep the threshold above the track lines.

**Expected pitfalls:** lines converging at the vanishing point pile up into a white blob, so stop
the track 5–10% short of it; speed lines and particles streaming past the camera are large bright
changes and count toward the flash limit.
