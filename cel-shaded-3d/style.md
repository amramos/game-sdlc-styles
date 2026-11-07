---
id: cel-shaded-3d
version: 1
name: Cel-shaded 3D
---

# Cel-shaded 3D

## The look

Real-time 3D lit like a cartoon cel. Every surface has two light bands (lit and shade), with an
optional small third (highlight), cut by a hard edge instead of a smooth falloff. Shadows are a
cooler, bluer version of the lit colour, never a darker grey. Silhouettes and big shape breaks carry
dark ink outlines of a fixed width in screen pixels. Colours are flat, bright and saturated, with no
texture detail beyond a few painted shapes; the sky is a painted gradient that also tints the fog.
Shapes are simple and chunky; characters lean anime: heads 1/4 to 1/5 of body height, large eyes,
small noses and mouths. The recognizable thing: a 3D world that reads like a moving drawing.

## Signature elements

1. **Two hard light bands,** an optional small highlight band, and a band edge 1–2 % of the light
   range wide. Never more than three bands on one surface.
2. **Hue-shifted shade:** the shade band is the lit colour multiplied by one cool `shadow-tint`
   shared by the whole scene, so every shadow turns the same way (toward blue or violet).
3. **Screen-space ink outlines:** about 3 px at 1080p on characters and near props, thinning to
   1 px with distance and fading into the fog; dark tinted ink, never pure black.
4. **Flat, bright materials:** one colour per material, painted from a small swatch atlas or
   vertex colours; no normal maps, no roughness variation, no ambient occlusion smudges.
5. **A painted sky and soft distance:** a banded two-colour sky, hard-edged sun disc and puffy
   banded clouds; linear fog in the sky's horizon colour turns far shapes pale, not grey.

## Readability and interface

- **Every word and number is live text** in the game's fonts, never painted into a texture.
- **The interface uses the world's rules:** flat fills from the palette, a 3 px `ink` border at
  1080p, rounded corners (8–12 px), a hard offset shadow (4 px down, no blur). No glass, blur,
  gradients or thin hairline frames; they read as a different game laid on top.
- **Type roles:** a rounded heavy *display* face for titles, names and decisive numbers; a clean
  humanist *body* face; at most three treatments. Licence-safe candidates: Baloo 2, Fredoka, Nunito
  Black (display); Nunito, Mulish, Atkinson Hyperlegible (body).
- **Smallest readable size:** 24 px at 1080p (16 px at 720p). Dialogue at 30–34 px.
- **Panels sit on solid `panel`, never straight on the 3D.** A bright saturated scene behind text
  fails contrast somewhere on screen; the panel's fill and ink border do the separating.
- **Signal colours** live only on chips and each chip also says its kind in a word or icon.
- **World markers** (route rings, targets, pickups) use the `accent`, carry the ink outline and
  never fog out.

## Colour structure

```yaml
colour-roles:
  ink:          outlines and interface text; dark, slightly tinted, never #000
  key:          the sun; a warm near-white
  shadow-tint:  ambient fill; every shade band = base × shadow-tint
  sky-top:      zenith of the gradient sky
  sky-horizon:  horizon of the sky, and the fog colour
  cloud:        clouds, spray, sails and other white cloth
  base:         [by material]   # grass, rock, wood, roof, cloth, skin, hair… lit fills
  accent:       ONE job, named by the game (what the player steers to or acts on now)
  signal:       [2–5 kinds]     # only on chips; each chip names its kind
  panel:        the interface fill
colour-rules:
  - value(ink) <= 0.25 and chroma(ink) >= 0.08
  - contrast(ink, panel) >= 7
  - contrast(ink, signal-*) >= 4.5           # ink text on every chip
  - contrast(ink, base-*) >= 3               # the outline reads on every lit fill
  - contrast(ink, sky-horizon) >= 7          # silhouettes against the sky
  - value(base-*) >= 0.50 and chroma(base-*) >= 0.25
  - chroma(accent) > chroma(base-*)
  - hue(accent) at least 30° from every base-* and sky-*; at least 20° from every signal-*
  - hue(shadow-tint) in 200–260°; value 0.75–0.95; chroma 0.15–0.40
  - hue(key) in 25–60° and chroma(key) <= 0.20
  - value(sky-horizon) >= 0.85, chroma(sky-horizon) <= 0.30, value(sky-top) < value(sky-horizon)
  - chroma(sky-*) < chroma(accent)
# value = HSV V; chroma = S × V; hue = HSV H in degrees; contrast = WCAG ratio
```

Colour **by material**; the shadow tint, not a darker base, makes the shade. `example-palette.gpl` is one instance, not the default;
the demo switches between three palettes that pass the same rules.

## Pitfalls

- **Outline width that follows the world.** A hull grown by a fixed world distance is 10 px on a
  close face and invisible on a far island. Offset in clip space so width is in screen pixels,
  then fade it with distance.
- **Gaps in the outline at hard edges.** Split normals (cubes, cylinder caps) tear the inverted
  hull. Push along a smoothed normal stored in its own attribute.
- **Outlines on every small prop.** Pebbles, grass tufts and rope coils with outlines turn into
  black noise. Outline only shapes taller than about 12 px on screen; leave small dressing unlined.
- **Shadow acne on the band edge.** Self-shadowing flickers in stripes where the band turns. Raise
  normal bias, and take the shade band as the minimum of the N·L band and the shadow map, so a
  surface already in shade can't stripe.
- **Faces broken into patches.** Sculpted face normals throw shade blobs under eyes and beside
  the nose. Transfer normals from a sphere or ellipsoid, or use a face shadow map.
- **Too many bands.** Four or more steps reads as a posterised smooth shade, not a cel.
- **Tone mapping eats the palette.** Filmic curves desaturate flat colours. Use none.
- **Ambient occlusion and soft shadows** add grey smudges the bands can't absorb. Leave them off.
- **An interface from another game.** Thin text on dark glass clashes with an inked world; build
  panels from the same ink and flat fills.

## Variations

- **Single band plus rim:** one hard shade band and a strong rim; reads well at small sizes.
- **Inked interior lines:** add screen-space edge detection on normals and depth for creases,
  over the hull outline.
- **Painted texture:** a few brush shapes per material in the shade colour, never noise.
- **Stepped animation:** characters at 12 poses a second, camera and effects at full rate.
- **Night:** dark `sky-*`, a pale cool `key`; keep `value(base-*)` up so the bands still read.

## Make it your own

A game in this style changes, from the example:

- the palette: every role re-chosen, the shadow tint included;
- the outline: colour, width and where it is drawn;
- the character proportions and the shape language (round, angular or blocky);
- the fonts and the interface's shape;
- the setting and the cast.

art-direction's critic checks these five before approving the style guide.

## Evidence

Not yet built in a game. demo.html renders the core; its courier and windmill are image-to-3D.

## Inspired by

The Legend of Zelda: The Wind Waker (painted sky, flat bands), Hi-Fi Rush (thick ink, stepped
animation), Ni no Kuni (hand-drawn feel in 3D), Genshin Impact (face normals, hue-shifted shade).
Use them for principles only: no characters, logos, levels, layouts or trademarks from them.
