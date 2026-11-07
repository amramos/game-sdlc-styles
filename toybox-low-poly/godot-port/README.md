# Godot port

The Godot 4.7.1 project (Compatibility renderer) that rendered `../frames/godot-key-scene`, kept so
the match with the web frame can be re-rendered after a change. `../godot.md` is the part a game
needs; this is the whole scene, including the code that rebuilds the web demo exactly.

Open this folder in Godot. `capture.gd` is an autoload: run with `-- --out=<file.png>` and it saves
the viewport after a few frames and quits.
