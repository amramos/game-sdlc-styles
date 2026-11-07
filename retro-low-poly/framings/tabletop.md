# Framing: tabletop (not yet built)

A board, map or model on a table, seen from a seat at its edge: the play surface is a physical
object the player leans over.

- **Camera:** perspective, vertical FOV 45–55°, eye 0.45–0.6 m above the table top and 0.4 m back
  from its edge, pitch −35° to −50°. Optional lean: ease forward 0.2 m and down 10° for close work.
- **What the core changes:** pieces are 3–8 cm tall and 0.5–1 m away, so they're a few low-res
  pixels wide. Make every piece at least 12 low-res pixels across at rest distance (scale pieces up,
  or raise the internal height to 288–360 lines for this framing only).
- **Snapping:** pieces snap to slots with a see-through preview; valid slots show the `accent`
  pulse while dragging.
- **Light:** one local light above the table (k 0.3–0.6) as the key; the room beyond falls off into
  fog at 3–6 m, so the table is the stage.
- **Fog:** start 2 m, end 6–9 m.

**Expected pitfalls:** pieces that only differ by tint merge under dither (vary their shape or
height); a long table recedes into fog (keep the playable area within 1.2 m of the eye).
