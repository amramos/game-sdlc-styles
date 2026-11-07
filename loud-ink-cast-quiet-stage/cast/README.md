# Cast and stage art

Generated locally with ComfyUI 0.37.0, model profile **`zimage-int8`** (Z-Image Turbo int8,
`z_image_turbo_int8_convrot.safetensors` + `qwen_3_4b_fp8_mixed.safetensors` + `ae.safetensors`),
the profile's default sampler settings (cfg 1, so there is no negative prompt), on an RTX 4070 Ti.
Every word, number, panel and chip in `demo.html` is live HTML, never part of these images.

Key colour: flat magenta `#FF00FF`, absent from the example palette's cast. Backdrops were keyed by a
flood fill from the image border (the same idea as comfyui-art's `pixel_post.py key`), with the
generator's cast drop shadow on the backdrop keyed with it; then cropped, downscaled and quantized.

| File | Kind | Source | Seed kept | Post |
|---|---|---|---|---|
| `keeper-neutral.png` | stall keeper, neutral pose | txt2img 1024×1536 | 22 | keyed; cropped at the waist (top 1200 px); 715×1024 |
| `keeper-outraged.png` | stall keeper, reaction pose | img2img from the neutral (on flat magenta), denoise 0.88, 1024×1536 | 33 | keyed; cropped at the waist; 761×1024 |
| `customer-haggling.png` | customer (a moth monster), haggling | txt2img 1024×1536 | 49 | keyed; largest shape kept (a painted word next to it removed); 759×872 |
| `wok.png` | prop: cooking tool | txt2img 1024×1024 | 55 | keyed with its drop shadow; 768×567 |
| `stage-stall-night.png` | stage layer: the stall's quiet backdrop | txt2img 1536×1024 | 64 | values above 0.30 compressed (×0.3), chroma capped at 0.11, median 5 px, 1024×683, 64 colours |
| `stage-stall-day.png` | the same stage, day palette | derived from the night stage | — | each pixel moved from the night `stage-*` colour it is nearest to toward the day palette's matching role (wood→wood, tile→tile, night air→day air), chroma capped at 0.11 |
| `stage-stall-untamed.png` | the "don't" stage | seed 64 untouched (glowing lanterns) | 64 | 1024×683 only; the demo brightens and saturates it further |

The cast is not recoloured for the day palette: its baked-in shadow stays the night teal. Only the
interface and the stage change with the palette.

## Rounds (seeds tried, about 5 minutes of generation in all)

- **Keeper:** 1 seed of a first design (a round toad; rejected: drew a stage behind it, full body,
  no hard shadow), then 4 seeds (21–24) of the final prompt; 22 kept for the most expressive face.
  All four drew a drop shadow on the backdrop and full body; cropped and keyed instead.
- **Keeper reaction:** img2img from the neutral, 2 seeds at denoise 0.72 (31, 32: same arms-folded
  silhouette, only the face changed) and 2 at 0.88 (33, 34); 33 kept: hands on hips, mouth open,
  a new silhouette while still the same character.
- **Customer:** 4 seeds (41–44) of a shaggy one-eyed design, rejected because it read as a famous
  film monster; 2 + 2 seeds (45–48) of the moth design, rejected because each drew a whole market
  stall behind it; 2 seeds (49, 50) with the setting line dropped; 49 kept.
- **Prop:** 4 seeds (51–54) drew a crowd of monsters behind the wok; 2 seeds (55, 56) with
  "one object only, nothing else" and no setting; 55 kept.
- **Stage:** 4 seeds (61–64); 61 and 62 drew a figure behind the counter; 64 kept (emptiest),
  then tamed because its lanterns glowed bright orange despite the prompt.

## Final prompts

### keeper-neutral (seed 22, txt2img 1024×1536)

> 2D bold graphic illustration: uniform very thick black ink outlines, flat colour fills with one hard-edged shadow tone in deep dark teal (#12333A), halftone dot texture inside shadows only, jagged angular shapes, high contrast. Palette: vermilion orange-red (#FF4A1C), sky blue (#7FB2FF), sun yellow (#FFC93C), jade green (#3CCB98), warm cream paper (#F2EADB), against near-black navy ink (#121624). No gradients, no soft airbrush, no glow, no photorealism, no text. FOCUS RULE (most important): characters and interactive objects are the only things drawn at full strength: full saturation, very thick ink outlines, halftone shadows. The background is a quiet, tame backdrop: simplified flat shapes, low contrast, values compressed into the dark mid-range, thin or no outlines, no halftone, no bright highlights, no glowing lights, no small detail, very slightly soft like a stage set in shadow. Nothing in the background competes for attention.
> Setting: a food stall in a night market run by monsters, where the cooks haggle with their customers; original characters only, no existing characters, logos or trademarks.
> The stall keeper: a stout, broad-shouldered monster cook with jade green scaly skin, a long blunt crocodile-like snout with a grin of square teeth, three small round eyes in a row above the snout, two short curled cream horns, thick muscular forearms, wearing a sun-yellow cloth headband, a warm cream apron over a sky-blue short-sleeved shirt, and a vermilion neckerchief. Drawn with sharp angular jagged contours like a screen-printed gig poster, not cute, not round. A large hard-edged deep dark teal shadow shape covers the right side of the face, body and arms, filled with halftone dots. Character at game scale, waist-up, three-quarter view, in their 'neutral' reaction pose: standing calm and confident, arms folded across the chest, a sure half-smile, isolated on a plain flat solid pure magenta (#FF00FF) backdrop, completely empty, no ground, no shadow, no text, no frame. Framed from the waist up: the bottom edge of the image cuts across the belly, no legs visible, the head near the top. There is no background scene at all in this image, only the flat magenta.

### keeper-outraged (seed 33, img2img from keeper-neutral on flat magenta, denoise 0.88)

> 2D bold graphic illustration: uniform very thick black ink outlines, flat colour fills with one hard-edged shadow tone in deep dark teal (#12333A), halftone dot texture inside shadows only, jagged angular shapes, high contrast. Palette: vermilion orange-red (#FF4A1C), sky blue (#7FB2FF), sun yellow (#FFC93C), jade green (#3CCB98), warm cream paper (#F2EADB), against near-black navy ink (#121624). No gradients, no soft airbrush, no glow, no photorealism, no text. FOCUS RULE (most important): characters and interactive objects are the only things drawn at full strength: full saturation, very thick ink outlines, halftone shadows. The background is a quiet, tame backdrop: simplified flat shapes, low contrast, values compressed into the dark mid-range, thin or no outlines, no halftone, no bright highlights, no glowing lights, no small detail, very slightly soft like a stage set in shadow. Nothing in the background competes for attention.
> Setting: a food stall in a night market run by monsters, where the cooks haggle with their customers; original characters only, no existing characters, logos or trademarks.
> The same stall keeper as the reference: a stout jade green crocodile-snouted monster cook with three small eyes, two short curled cream horns, sun-yellow headband, cream apron over a sky-blue shirt, vermilion neckerchief. Character at game scale, waist-up, three-quarter view, in their 'outraged' reaction pose: both arms flung up high above the head with claws spread wide, snout gaping wide open in a shout, all three eyes bulging wide, leaning back in shock at a lowball offer. A large hard-edged deep dark teal shadow shape on the right side of the body filled with halftone dots. Isolated on a plain flat solid pure magenta (#FF00FF) backdrop, completely empty, no ground, no shadow, no text, no frame.

### customer-haggling (seed 49, txt2img 1024×1536)

The prompt core with its background half removed (it ends at "...halftone shadows.") and no setting line:

> 2D bold graphic illustration: uniform very thick black ink outlines, flat colour fills with one hard-edged shadow tone in deep dark teal (#12333A), halftone dot texture inside shadows only, jagged angular shapes, high contrast. Palette: vermilion orange-red (#FF4A1C), sky blue (#7FB2FF), sun yellow (#FFC93C), jade green (#3CCB98), warm cream paper (#F2EADB), against near-black navy ink (#121624). No gradients, no soft airbrush, no glow, no photorealism, no text. FOCUS RULE (most important): characters and interactive objects are the only things drawn at full strength: full saturation, very thick ink outlines, halftone shadows.
> Original character only, no existing characters, logos or trademarks.
> A customer: a small, round-bodied moth monster with a plump sun-yellow fuzzy body, two long feathery sky-blue antennae, four thin black-ink arms, big folded jade green wings worn like a cloak, two large round black eyes with tiny white glints, and a short vermilion beak-like mouth. Cel-shaded: the side turned away from the viewer is in hard-edged deep teal shade filled with halftone dots. Drawn with sharp angular jagged contours like a screen-printed gig poster. Character at game scale, waist-up, three-quarter view, in their 'haggling' reaction pose: leaning forward suspiciously, one thin hand held out flat, palm down, as if pushing the price lower, another hand clutching a tiny cream coin purse to its chest, eyes narrowed, isolated on a plain flat solid pure magenta (#FF00FF) backdrop, completely empty, no ground, no shadow, no text, no frame. Framed from the waist up, the head near the top. There is no background scene at all in this image: no stall, no awning, no counter, only the flat magenta, and no cast shadow on it. A character sticker cut-out, alone.

### wok (seed 55, txt2img 1024×1024)

> 2D bold graphic illustration: uniform very thick black ink outlines, flat colour fills with one hard-edged shadow tone in deep dark teal (#12333A), halftone dot texture inside shadows only, jagged angular shapes, high contrast. Palette: vermilion orange-red (#FF4A1C), sky blue (#7FB2FF), sun yellow (#FFC93C), jade green (#3CCB98), warm cream paper (#F2EADB), against near-black navy ink (#121624). No gradients, no soft airbrush, no glow, no photorealism, no text. FOCUS RULE (most important): characters and interactive objects are the only things drawn at full strength: full saturation, very thick ink outlines, halftone shadows. The background is a quiet, tame backdrop: simplified flat shapes, low contrast, values compressed into the dark mid-range, thin or no outlines, no halftone, no bright highlights, no glowing lights, no small detail, very slightly soft like a stage set in shadow. Nothing in the background competes for attention.
> Setting: cookware from a monster-run night-market food stall; original design only.
> One object only, nothing else in the image: a single round cast-iron wok with one long straight handle wrapped in vermilion cloth tape, the iron drawn in near-black navy with hard-edged deep teal shade filled with halftone dots on its far side, a heap of sun-yellow noodles and jade green spring onions inside, seen from a three-quarter angle above. Centred, occupying the middle two thirds of the frame, on a plain flat solid pure magenta (#FF00FF) backdrop that fills the whole image edge to edge: no table, no counter, no characters, no people, no scene, no shadow, no text.

### stage-stall-night (seed 64, txt2img 1536×1024)

> STAGE ONLY: a quiet, tame backdrop that characters will be placed in front of later. Simplified flat shapes, low contrast, values compressed into the dark mid-range, thin or no outlines, no halftone, no bright highlights, no glowing lights, no small detail, very slightly soft like a stage set in shadow. Nothing in the background competes for attention.
> Setting: the inside of a monster-run food stall in a night market, seen straight on from the customer's side, like a theatre set.
> Colour by material: the stall's posts and back shelves are dark weathered wood in dim brown (#3A2A20); the awning across the top is old canvas in dim muted khaki brown (#3E3528); hanging pots, a stock pot and shelf brackets are dull dark steel grey (#2C3236); the back wall behind the cook is small square tiles in dim dark grey-green (#30382E); the floor and the night beyond the edges are dark concrete grey (#3B3D3E). Wide empty space in the centre and left of centre where a cook will stand. Unlit paper lanterns as plain dark shapes, not glowing. Not orange-dominant, not brown-dominant. Every colour stays dim and low-saturation. Completely empty: no people, no text, no signs, no lettering.
