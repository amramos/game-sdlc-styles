# Framing: fixed stage (built in a prototype)

One set seen from one high camera, like a stage from the balcony. Built in a web prototype; the
framing demo.html renders.

- **Camera:** perspective, vertical field of view 46°, pitch 18–22° down, the horizon in the top
  5–10% of the frame. The set fills 60–90% of the width; the near edge sits in the bottom quarter.
  The camera never yaws more than about ±30° from home, or the sprites show they are flat.
- **Staged moments:** close-ups ease in (speed 0.8) to a subject, hide captions, slide in 64 px
  letterbox bars and show a lower-third title card; they hold for at most 8 s and always return home
  (escape and a click on nothing also return).
- **Tilt-shift:** focus line at 0.40 of the height from the bottom, on the set's middle; amount 2.4.
  Close-ups 0.45 and 3.2. Off when more than half the screen is interface.
- **The set:** the near side open; the far side and the edges closed by a low wall, scenery or the
  drop to the surface below. The animated surface and the backdrop fill everything behind.
- **Interface:** captions over the set; panels on the edges: status top-left, signals under it,
  details on the right (about 30% of the width), a selection strip along the bottom. Captions are
  laid out only in the free area between them.

**Pitfalls:** more than four full captions crowd the view; captions alone make poor click targets, so add
hit volumes; a close-up needs a timeout, or the camera can stay zoomed in; props at the back of a
dark set need their own light; a detailed centre piece can hide the floor where play happens.
