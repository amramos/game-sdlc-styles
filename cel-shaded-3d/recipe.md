# Recipe: the core, in any framing and engine

## Generator

- **Needs:** a real-time engine with custom shaders (or a toon material with a gradient ramp) and
  3D models: hand-modelled, kitbashed from primitives, or generated with image-to-3D.
- **Concept art** from an image model, chained in a fixed order: the first character → the key
  scene (with that character as reference) → props (with the key scene). Record each frame's
  references, in order, in the style guide.
- **Never generated:** interface panels, chips, icons under ~48 px, and any word or number. Those
  are built in the engine.

## Light bands

| Band | Where (N·L of the key light) | Colour |
|---|---|---|
| Shade | N·L < 0.0, or in the shadow map | `base × shadow-tint × 0.45` (linear) |
| Lit | 0.0 ≤ N·L < 0.75 | `base × (0.45 × shadow-tint + 0.60 × key)` (linear) |
| Highlight (optional) | N·L ≥ 0.75 | lit + `0.15 × key` |

- **Band edge:** `smoothstep(t − 0.01, t + 0.01, N·L)`; 0.02 wide at most, or a nearest-filtered
  ramp.
- **Shade ratio:** the shade band's HSV value is 0.62–0.75 of the lit band's, its hue 10–30°
  toward `shadow-tint`.
- **Shadow maps** feed the same step: `lit = min(step_band(N·L), step(0.5, shadow))`. Shadow
  colour = shade band colour, never a separate grey.
- **Highlight band:** at most 15 % of a surface's area; skip on terrain.

## Ramp texture

- 16×1 px, single channel, nearest filter, no mipmaps; texel `i` covers N·L from `−1 + i × 0.125`.
- Texels 0–7 = 0 (shade), 8–13 = 0.8 (lit), 14–15 = 1.0 (highlight); key intensity × 1/0.8.
- Move a band threshold by moving the texel where the value changes; 0.125 steps in N·L.
- One ramp for the whole scene; a material that needs softer shading gets a second ramp, not
  more texels.

## Rim light

- `rim = step(0.70, 1 − N·V) × step(0.0, N·L_key)`: a hard rim only on the lit side.
- Colour: mix 35 % toward `sky-horizon`. Characters and the accent's markers only.

## Outlines

- **Method:** inverted hull. Draw a second copy with front faces culled, unlit `ink`, vertices
  pushed along a smoothed normal in clip space:
  `clip.xy += normalize(nClip.xy) × width_px × 2 / viewport_px × clip.w`.
- **Smoothed normals:** average the normals of all vertices at the same position into a separate
  attribute (or a vertex colour, or UV2), so hard edges don't tear the hull.
- **Width:** 3 px at 1080p for characters, 2.5 px for props and buildings, 2 px for terrain.
  Scale by `viewport_height / 1080`.
- **Falloff:** full width to 12 m, linear to 1 px at 60 m, colour mixed to fog with the same fog
  curve as the surface.
- **Skip:** objects under ~12 px on screen; clouds; grass; particles.
- **Inner lines (optional):** a post pass of Sobel on view normals (threshold 0.4) and linear depth
  (threshold 0.05 × depth), 1 px, `ink` at 70 % opacity.

## Characters

- **Proportions:** head 1/4.5 of height; eyes 1/5–1/4 of head width; hands at 1.2× realistic size.
- **Face normals:** transfer normals from an ellipsoid fitted to the head (Blender: Data Transfer
  modifier, face corner normals, nearest face interpolated), so the face takes one band edge, not
  patches.
- **Or a face ramp:** the face skin alone gets a ramp whose lit threshold is N·L = −0.5, and the
  head receives no shadows, so hair and fringe never blot the face.
- **Or a face shadow map:** a grayscale threshold texture in UV space; shade where
  `map < dot(head_right, light_dir) × 0.5 + 0.5`; flip U for light from the other side.
- **Eyes and mouth:** unlit decals or texture swaps, outside the band shading.
- **Hair:** split into 5–9 large clumps, each with its own outline; one specular strip optional.

## Lights as ratios

- **Key:** one directional, `key` colour, intensity 1.0 (reference), elevation 40–55°, from
  45–90° beside the camera, so most fronts get both bands.
- **Ambient:** flat, colour `shadow-tint`, 0.45 of key. No hemisphere gradient, no image-based
  light.
- **Rim:** 0.35 mix, see above. **Point lights:** add to the lit band only, radius ≤ 8 m.
- **Shadows:** key only, 2048 px map over 24 m (≈1.2 cm texels), normal bias ≈8 texels (0.1 m),
  depth bias −0.001.
- **Receivers:** terrain and props that others shadow. Convex shapes that would only shadow
  themselves (towers, posts, heads) don't receive; their own N·L band does the work.
- **Tone mapping:** none; `sRGB` output. Base colours on screen within 5 % of their hex.

## Sky and fog

- **Sky:** sphere or full-screen pass; four flat steps from `sky-horizon` to `sky-top`:
  `mix(sky-horizon, sky-top, floor(clamp(dir.y / 0.34, 0, 1) * 4) / 4)`. Put the steps low (horizon
  to ~20° up): a game camera near level sees little sky, and a gradient that only finishes at the
  zenith looks flat on screen.
- **Sun disc:** hard circle 3° wide in `key`, one ring at 5°, 30 % opacity; no lens flare.
- **Clouds:** clusters of 4–8 flattened spheres, `cloud`, two bands, no outline. Spread them over
  three depths (near, mid, beyond the fog's midpoint) and leave the silhouettes of landmarks and
  moving parts against clear sky.
- **Fog:** linear, colour `sky-horizon`, start at 30 % of view distance, end at 100 %; ink
  outlines fade with the same curve. It is the main depth cue: far islands and clouds pale toward
  the horizon in steps of distance, never into grey murk; anything past ~70 % fog is a shape only.
- **Below the world:** two or three steps back toward `sky-top` (at most 35 %), so the drop under
  the world reads as depth and air.

## Post

- None required. Optional: FXAA or 4× MSAA (outlines alias without it); bloom with threshold 1.0
  so only the sun disc and `accent` emissives bloom.
- **Never:** SSAO, depth of field in play, chromatic aberration, film grain, filmic tone mapping.

## Shapes and polygon budgets

- **Shape:** large-medium-small at about 60/30/10 % of a silhouette; bevel edges 2–5 % of the
  object size to give the hull a clean line.
- **Budgets:** hero character 4–8k triangles; secondary character 2–4k; props 100–800; an island
  chunk 1–4k.
- **Scene:** ≤300k triangles on desktop, ≤100k on web and mobile.
- **Smooth normals** on organic shapes; hard edges only where a band break is wanted.

## Textures

- One 256×256 swatch atlas per scene: 16×16 px flat swatches, UVs collapsed into each swatch.
- Or vertex colours with no texture at all.
- Painted detail: 2–4 brush shapes per material in the shade colour; no noise, no photo source.
- No normal, roughness, metal or AO maps.
- **Generated models:** image-to-3D welds moving parts (sails, wheels, doors) to the body and may
  stretch thin membranes between them. Split them into their own node with its origin on the
  pivot, drop off-axis membrane triangles, and point cloth triangles at one deep texel of their slot
  so no neighbouring colour smears across them.

## Prompt core

Fill `<…>` from the game's palette and setting; keep the rest verbatim.

**Concept art:**

> Cel-shaded 3D game screenshot, toon shading with two hard light bands and a small highlight,
> shadows tinted <shadow-tint colour> not grey, clean dark <ink colour> outlines of even width,
> flat bright saturated colours, simple chunky shapes, painted gradient sky from <sky-top> to
> <sky-horizon>, soft pale fog in the distance. Palette: <base colours by material>, accent
> <accent> on <what the accent marks>. No photorealism, no textures with noise, no ambient
> occlusion, no soft shadows, no film grain, no text.

Then one line of setting (original characters only; no existing characters, logos or
trademarks), then the subject.

- *Character:* "full body, A-pose, front three-quarter view, anime proportions with a head 1/4.5 of
  the height, <outfit by material>, on a plain flat <key colour> backdrop, no text."
- *Prop:* "one object, three-quarter view from 30° above, chunky simple shape, centred on a plain
  flat <key colour> backdrop, no text."

**Image-to-3D input** (one image per model):

> Single <subject>, full body, A-pose, front view, orthographic, evenly lit with no cast shadows,
> flat unshaded colours with no outlines, simple chunky shapes, centred on a plain white
> background, no text.

- Generate with outlines and bands **off** in the input; the engine draws both. Baked shading in the
  texture doubles the bands.
- Request a clean low-poly mesh at the budgets above; replace the generated texture with swatch
  colours or vertex colours.
- **Found building the demo:**
  - Flatten a generated texture to **palette slots**, not colours: map each texel to the nearest
    of a few reference colours, mode-filter, grow the charts into the empty background, store the
    slot index, sample it nearest-filtered and look the colour up from the palette in the shader.
    The bands stay clean and the model follows a palette change.
  - Replace the generated normals with one averaged normal per position; split normals at UV
    seams cut patches into the bands.
  - Give the skin slot the face ramp (N·L shifted by +0.5) and let the character receive no
    shadows, or the jaw and fringe throw shade blobs across the face.
  - Ask for solid sails, panels and fins, not lattices, in the input image; and check thin parts
    from the front: image-to-3D may stretch a membrane between them (sail tips joined into one
    board). Delete those triangles before use.
  - Render generated meshes double-sided; thin parts come out as single sheets.

## Sizes

| Kind | Generate at | Use |
|---|---|---|
| Concept, key scene | 1536×1024 | style guide only |
| Character sheet | 1024×1536 | modelling and image-to-3D input |
| Prop | 1024×1024 | modelling and image-to-3D input |
| Interface, chips, text | built in the engine | — |

## Motion

| What | Value |
|---|---|
| Idle bob | 2–3 % of height, 0.5 Hz, sine |
| Scarf, cloth tails | 2–3 segments, phase offset 0.6 rad per segment, 1.2 Hz |
| Squash and stretch | ±10 % on jump and land, 0.08 s in, 0.15 s out |
| Key poses | hold 2–4 frames on contact poses; optional 12 fps stepping |
| Windmills, wheels | 0.2–0.3 turns per second |
| Interface pop | scale 0.9 → 1.05 → 1.0 in 0.18 s; leave 0.10 s |
| Reduced motion | no squash, no screen shake, no pop; same final state |
