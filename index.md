# Style catalog index

One block per entry, matched by [../references/matching.md](../references/matching.md). Read this
file to choose; open an entry's `style.md` only once it's on the shortlist.

**`mood`** lists the moods the look can carry with a fitting palette and lighting, not the mood of
its example frames: colour and lighting belong to each game (an entry's colour rules keep only
what the look needs structurally, such as a dark background for glow). Lighting schemes (one warm
light, daylight, overcast, neon night) are variations in `style.md`, not part of a look's identity.

**Vocabulary.** `medium`: pixel art, vector, painted 2D, bold 2D illustration, paper cut-out, low-poly 3D,
cel-shaded 3D, realistic 3D, text. `framings`: top-down, side, isometric, third-person,
first-person, fixed-stage, fixed-panels, card-table, tabletop, tactics-grid, on-rails; a `*` marks
the framing a game was built and played in. `cost`: low, medium, high. `engines`: web, godot
(listed only once the recipe has been rendered in that engine).

```yaml
- id: loud-ink-cast-quiet-stage
  framings: [fixed-stage*, card-table, side]   # * = built and playtested
  medium: [bold 2D illustration]
  mood: [loud, comic, grim, punchy, theatrical, playful]
  suits: [dialogue-driven games, visual novels, small-cast drama, card games, management on one set]
  avoid-for: [3D, large maps, many units on screen, realistic tone]
  cost: medium
  requires: [an image model that accepts reference images]
  engines: [web, godot]
  version: 1

- id: chunky-bright-pixel-art
  framings: [side, top-down, isometric]
  medium: [pixel art]
  mood: [bright, cheerful, energetic, crisp]
  suits: [platformer, action-adventure, farming and life sim, tactics, trading and management, small-cast narrative]
  avoid-for: [photoreal or painterly tone, smooth camera zoom or rotation, horror that relies on darkness and gradients]
  cost: low
  requires: [a pixel editor, or an image model plus palette cleanup at true size]
  engines: [web, godot]
  version: 1

- id: cel-shaded-3d
  framings: [third-person, isometric]
  medium: [cel-shaded 3D]
  mood: [bright, airy, adventurous, playful]
  suits: [action-adventure, exploration, 3D platformer, rhythm action, creature collecting, cosy open world]
  avoid-for: [horror, grim realism, dense small-scale strategy interface, photoreal settings]
  cost: medium
  requires: [3D models (modelled, primitives or image-to-3D), custom shaders]
  engines: [web, godot]
  version: 1

- id: toybox-low-poly
  framings: [isometric, top-down]
  medium: [low-poly 3D]
  mood: [calm, cosy, miniature, tidy]
  suits: [city and village builders, grid puzzle, management on a grid, relaxing sandbox]
  avoid-for: [fast action and hit-reading, horror or tense tone, realistic settings, text-heavy narrative]
  cost: low
  requires: [none (procedural primitives); optional image-to-3D for one or two hero pieces]
  engines: [web, godot]
  version: 1

- id: neon-vector-glow
  framings: [top-down, side, on-rails]
  medium: [vector]
  mood: [electric, kinetic, intense, abstract, arcade]
  suits: [twin-stick shooters, arena survival, score attack, rhythm action, rail shooters, many targets on screen]
  avoid-for: [narrative and dialogue-heavy games, character drama, cosy tone, realistic settings]
  cost: low
  requires: [none (every shape is drawn in code)]
  engines: [web, godot]
  version: 1

- id: pixel-sprites-lit-diorama
  framings: [fixed-stage*, isometric, tactics-grid, side]
  medium: [pixel art, cel-shaded 3D]
  mood: [miniature, storybook, cosy, bright, festive, nostalgic, hushed, wistful, tense, melancholy]
  suits: [tactics and RPG scenes, management on one set, narrative strategy, small-cast character games, town and life sims seen as a diorama]
  avoid-for: [fast action needing precise hit-reading, big crowds of units, many readable targets at range, interface-dense management, a free-rotating close camera]
  cost: medium
  requires: [pixel sprites (drawn in code, a pixel editor, or an image model plus palette cleanup), 3D set pieces (procedural primitives), custom shaders and a post chain]
  engines: [web, godot]
  version: 1

- id: ink-graphic-novel
  framings: [fixed-panels*, side, top-down]
  medium: [bold 2D illustration]
  mood: [grim, tense, stoic, noir, melancholy, comic, pulpy, adventurous]
  suits: [narrative adventure, story-led strategy and management, investigation and mystery, visual-novel beats, card or board games with a story spine, side-scrolling adventure or brawler, tactics on a map]
  avoid-for: [many tiny targets at speed, soft cosy pastel tone, dense number tables, anything that needs many colours to tell things apart]
  cost: low
  requires: [none for figures, props and interface (drawn in code); an image model plus palette snap and re-inking for backdrops and portraits]
  engines: [web, godot]
  version: 1

- id: tabletop-diorama
  framings: [tabletop*, card-table, isometric]
  medium: [low-poly 3D]
  mood: [cosy, playful, storybook, warm, whimsical, hushed]
  suits: [cosy management, board-game-like tactics, narrative strategy, small-town life sim, puzzle on a board, card and dice games, folk tales and fables]
  avoid-for: [fast action and reflex play, large open worlds, many small simultaneous targets, first-person exploration]
  cost: medium
  requires: [3D pieces (procedural primitives, or image-to-3D for hero figures), a custom post shader]
  engines: [web, godot]
  version: 1

- id: paper-theatre
  framings: [fixed-stage*, side, tabletop]
  medium: [paper cut-out]
  mood: [whimsical, playful, theatrical, storybook, nostalgic, intimate, ominous]
  suits: [narrative and choice-driven games, story-led roguelites, puzzle-adventures, fables and folk tales, chamber dramas, small-cast management on one set]
  avoid-for: [fast action and hit-reading, free camera, large maps or many units, dense information screens]
  cost: medium
  requires: [none (every print is drawn in code); optional image model plus keying for detailed back cloths and hero figures]
  engines: [web, godot]
  version: 1

- id: retro-low-poly
  framings: [first-person*, third-person, fixed-stage, tabletop, tactics-grid]
  medium: [low-poly 3D]
  mood: [playful, nostalgic, bright, eerie, deadpan, cosy, tense]
  suits: [first-person exploration and adventure, survival horror, 3D platformer, kart and arcade racing, narrative and investigation in one place, management on one set or table, tactics]
  avoid-for: [photoreal or painterly tone, many small readable pieces at a distance, precise long-range aiming, text drawn inside the 3D view]
  cost: low
  requires: [none (procedural primitives and 32-64 px textures drawn in code); custom shaders and a low-res render target]
  engines: [web, godot]
  version: 1
```

Vocabulary: `medium` uses gdd-handsoff's list (pixel art, vector, painted 2D, low-poly 3D,
realistic 3D, text) plus `bold 2D illustration`, `cel-shaded 3D` and `paper cut-out`. `framings` uses its cameras
plus fixed-stage, fixed-panels, card-table, tabletop, tactics-grid and on-rails. Every frame is
`<entry>/frames/*.png|jpg`, 1280×720, made from the entry's `demo.html?frame=…`.
