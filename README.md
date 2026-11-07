# game-sdlc styles

The hosted art-style catalog of [game-ai-sdlc](https://github.com/amramos/game-ai-sdlc), published at
**https://amramos.github.io/game-sdlc-styles/**.

Each folder is one look: its rules (`style.md`), recipe, camera framings, web and Godot code, an
example palette, reference frames, a Godot render matched against the web frame, and a `demo.html`
that runs the look in the browser with its example art in `assets/`.

The SDLC plugin ships only what agents read (the index, each entry's text and a 640 px preview), so
installing it stays light. After changing an entry here:

1. `python <sdlc>/plugins/game-sdlc/skills/style-catalog/scripts/build_gallery.py .` (rebuilds `catalog.html`);
2. `python <sdlc>/plugins/game-sdlc/skills/style-catalog/scripts/check_entries.py .` (the same check CI runs);
3. in the SDLC repository, `python plugins/game-sdlc/skills/style-catalog/scripts/export_plugin.py <this folder>`
   and open a pull request there with the result.

Demos open straight from the file or from the site: images are embedded in `assets/*.js`, because
Chrome blocks WebGL textures loaded from neighbouring local files (`embed_images.py` packs them).

The example art, cast and settings exist to show each look. A game built from an entry makes its own.
