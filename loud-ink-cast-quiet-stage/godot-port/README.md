# Godot port

The Godot 4.7.1 project (Compatibility renderer) that rendered `../frames/godot-key-scene`, kept so
the match with the web frame can be re-rendered after a change. `../godot.md` is the part a game
needs; this is the whole scene, including the code that rebuilds the web demo exactly.

Open this folder in Godot. `capture.gd` is an autoload: run with `-- --out=<file.png>` and it saves
the viewport after a few frames and quits.

The example art isn't duplicated here. Before opening, fill these folders from the entry's `assets/`
(or `cast/`): images with `embed_images.py unpack` on a copy of `assets/`, models by decoding each
`<name>.glb.js` (the base64 string after `MODELS['<name>'] =`) to `<name>.glb`.

| Folder | Files |
|---|---|
| `cast/` | customer-haggling.png, stage-stall-night.png |
