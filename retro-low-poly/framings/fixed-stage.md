# Framing: fixed-stage (not yet built)

Authored camera angles per room, cutting as the character crosses trigger lines: the classic
fixed-camera setup.

- **Camera:** perspective, vertical FOV 40–55°, placed high in a corner or low at a doorway; one
  angle per room or corridor section. Cuts are instant; no blend.
- **Control:** the character's movement is relative to the camera at the moment the stick was
  pressed, until the stick is released, so a cut doesn't reverse the player's direction.
- **What the core changes:** the camera doesn't move, so the vertex snap shows only on moving things;
  push `snap` to 2 for characters, or add a slight camera drift (0.5°, 0.1 Hz) to keep the jitter
  alive. The still frame allows larger textures on the set (64 px everywhere).
- **Fog:** short (end 8–15 m) so each angle frames one readable space; the background clears to fog.
- **Light:** one or two local lights per room, placed for the angle; the key may be off.
- **Interface:** prompts anchor to the object, clamped inside the frame.

**Expected pitfalls:** objects near the frame edge are hard to read at 240 lines (keep interactive
things in the middle 80% of the frame); a cut mid-action makes players lose their character (cut
only when the character is fully across the line, and keep it in the same third of the screen).
