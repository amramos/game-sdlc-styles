# Assets: every printed piece of the theatre, one generation each

Generated locally with ComfyUI 0.37.0, model profile **`zimage-int8`** (Z-Image Turbo int8,
`z_image_turbo_int8_convrot.safetensors` + `qwen_3_4b_fp8_mixed.safetensors` + `ae.safetensors`),
the profile's default sampler (cfg 1, no negative prompt), RTX 4070 Ti. Each piece was generated
alone; nothing here is a picture of the whole scene. No text is in any image: every word on screen
is live text drawn by `demo.html`. Total about 1.55 MB.

## Prompts

Cut-outs share one prompt core (the recipe's), with the tints and subject filled in:

> Hand-tinted copperplate engraving printed on cream card: bold black ink outlines, fine parallel
> hatching and cross-hatching, flat muted watercolour tints of `<tints>`, light from the upper left,
> naive nineteenth-century toy theatre sheet print, no text, no lettering. `<subject>` A single flat
> paper cut-out piece, cut out along its outline, isolated on a plain flat solid pure magenta
> (#FF00FF) background, completely empty, no ground, no stage, no frame, no shadow, nothing else in
> the image.

| File | Size | Generated at | Seed | Tints | Subject (abridged) |
|---|---|---|---|---|---|
| `girl.png` | 589×1024, 178 KB | 832×1280 | 12 (of 11–12) | faded brick red, sage green, pale peach skin, straw yellow, cream | a young girl in a long hooded cloak over a dress and apron, a covered straw basket on her arm, walking right, side view, about five heads tall |
| `wolf.png` | 1024×745, 195 KB | 1280×832 | 22 (of 21–22) | warm grey, pale cream, dull brown | a tall lean grey wolf on all fours, side view facing left, sly closed-mouth smile, bushy tail held low, fur in dense hatching |
| `cart.png` | 1022×579, 134 KB | 1280×960 | 33 (of 31–34) | warm tan wood, pale birch white, dull steel grey | a two-wheeled hand cart in strict side view, one spoked wheel, two long handles, loaded with birch logs and an axe; "drawn alone: no ground, no grass, no shadow, no paper sheet behind it" |
| `wing-birch.png` | 427×1022, 91 KB | 640×1536 | 62 (of 61–62) | pale birch white, dull sage green, soft olive | one tall slender birch, front view, trunk base touching the bottom edge |
| `wing-oak.png` | 463×1022, 119 KB | 640×1536 | 71 (of 71–72) | warm brown, sage green, soft olive | one tall oak, thick gnarled trunk, big round crown |
| `row-far.png` | 1022×250, 69 KB | 1792×576 | 81 (of 81–82) | pale misty blue-green, pale grey-green | a long strip of distant firs of varying heights, joined along one flat bottom edge |
| `row-mid.png` | 1022×197, 73 KB | 1792×512 | 92 (of 91–92) | soft sage green, olive green | a long strip of rounded bushes and hedges |
| `row-near.png` | 1022×171, 58 KB | 1792×448 | 101 (of 101–102) | deep moss green, olive | a long strip of grass tufts, ferns and a few mushrooms |
| `valance.png` | 1022×193, 84 KB | 1792×384 | 111 (of 111–112) | faded brick red, cream | a border valance: draped fabric, a row of scallops, a cream tassel fringe |
| `drape.png` | 470×1022, 104 KB | 640×1536 | 122 (of 121–122) | faded brick red, cream | one tall side curtain hanging in folds, tied back by a cord with a tassel |
| `proscenium.png` | 1024×585, 163 KB | 1792×1024 | 44 (of 41–44) | faded brick red, cream, soft olive | a symmetrical toy-theatre proscenium card: pillars with capitals, a header with a blank oval cartouche between laurel garlands, a base band; the opening "a hole cut through the card, filled with flat magenta" |

Opaque sheets (no key):

| File | Size | Generated at | Seed | Prompt (abridged) |
|---|---|---|---|---|
| `backcloth.jpg` | 1024×327, 68 KB | 1792×640 | 51 (of 51–52) | the same engraving words with sparse hatching; "one full-bleed landscape painting that fills the whole frame with plain unmarked corners": pale sky, three clouds, a small sun upper right, rolling hills in the lower third, a tiny red-roofed cottage with smoke on a far hill |
| `floor.jpg` | 768×768, 151 KB | 1024×1024 | 132 (of 131–132) | floorboards seen from above, eight straight planks running top to bottom, grain lines and a few knots, evenly lit, full-bleed |

Derived for the "don't" frame only: `girl-dont.png` (the girl's art without its paper, cut to
1/14 size with nearest-neighbour and 12 colours, then scaled ×4: a coarse pixel sprite) and
`wolf-dont.png` (the wolf without its paper, blurred 9 px and brightened: an airbrushed look).

## Post-processing (Python: numpy, scipy, Pillow)

1. **Key:** flood-fill from the image border over magenta-ish pixels (min(R, B) − G > 45). Where
   the generator laid a blank cream sheet behind the piece (birch, drape, near row, far row, oak),
   cream pixels touching the border were flooded too. Enclosed pockets of key, even when shaded
   down to a dull mauve, are removed as well (the art has no pinks); pinholes under 300 px are
   filled. One pixel of erosion drops the fringe, then a despill pulls R and B back by the
   magenta excess.
2. **Crop** to the alpha's box and scale so the long side is 1024 px at most.
3. **Paper border:** the silhouette dilated by a disc of 0.02–0.06 world units (the generator
   usually drew its own cream border already, so most pieces got the thin end), filled with the
   paper colour under the art, hard alpha (the demo alpha-tests at 0.5). Quantized to 160 colours.
4. **Far row** blended 38% toward the back cloth's sky colour, so the rows step away from it as
   they come forward.
5. **Proscenium:** both rounds painted the opening as a pink box interior instead of flat key, so
   the opening was cut out by a measured rectangle between the inner pillars (source pixels
   381–1427 × 278–826); its outside was keyed by the flood fill. `demo.html`'s `OPENING` holds the
   box in the output's pixels and sizes the stage from it.
6. **Back cloth and floor:** the generator's cream margin cropped off; resized; JPEG 84–86.

The dark card edge is not in the images: the demo draws it as a second plane behind each cut-out,
using only the image's alpha, in the scheme's `card` colour.

## Rounds

About 30 images in all, two seeds a piece. Rejected: cart 31 (a big blank card behind it), cart 32
(a half-rectangle of paper under it); cart 34 (a framed paper sheet); proscenium 41–43 (box
interiors, cream outside); birch 61 (a cream patch fused into the crown); drape 121 (a ruled
frame); rows and backcloth second seeds (similar, slightly busier).

## Embedded for file://

The images the page draws with WebGL are packed into `images.js` (the catalog script `embed_images.py pack`), because Chrome blocks textures loaded from neighbouring files when the page is opened from the file. To edit one, run `embed_images.py unpack` on this folder, change the file, then `pack` again.
