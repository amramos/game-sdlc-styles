# Godot 4 snippets

<!-- matched-web-frame: 1ac034a6670a -->

> **The `assets/` paths below load this entry's example art**, which is how the port was tested against the web demo. A game never ships it: load the game's own models, sprites and textures, made the same way, in their place.

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.png` rebuilds
`demo.html?frame=key-scene` from `Sprite2D` and `draw_rect()` nodes, using this page's settings and
shader, and the entry's generated sprite PNGs (`assets/sprites/`) for the cast and the pack beast.
Measured match: mean difference 0.0/255, 0 pixels differ, both frames use the same 13 colours.
Forward+ (Vulkan) renders the same frame, also 0 pixels off: nothing here is renderer-specific.

**Scene layout.** One root `Node2D` with the palette `ShaderMaterial` and a script that builds the
scene in the demo's draw order: runs of `draw_rect()` calls batched into child `Node2D`s, one
`Sprite2D` per sprite placement (a new batch starts after each sprite, so later rectangles draw on
top). Every child sets `use_parent_material = true`. The pose is the demo's `t = 0`: trader one in
idle frame A, trader two in frame B, the beast in frame A, the traveller in walk frame 2 (passing).

**Project settings** (`project.godot`) for a 320×180 base scaled by whole numbers:

```ini
[display]
window/size/viewport_width=320
window/size/viewport_height=180
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="viewport"          ; render at 320×180, then scale the whole frame
window/stretch/aspect="keep"
window/stretch/scale_mode="integer"     ; whole-number scale, border for the rest

[rendering]
renderer/rendering_method="gl_compatibility"
textures/canvas_textures/default_texture_filter=0   ; Nearest
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=true
textures/vram_compression/import_etc2_astc=false
environment/defaults/default_clear_color=Color(...)  ; the palette's ink, as a colour (see below)
```

- With stretch mode `viewport`, `get_viewport().get_texture().get_image()` returns the 320×180
  frame. Scale it ×4 with `Image.INTERPOLATE_NEAREST` for a 1280×720 screenshot, which is exactly
  what the window shows at integer scale.
- Import every sprite sheet as **Lossless** (`compress/mode=0`) with mipmaps off
  (`mipmaps/generate=false`); these are Godot's 2D defaults, so the generated `.import` files need
  no change. A compressed import adds off-palette colours. Filtering is Nearest from the project
  setting above.
- A pixel font (`.ttf` made from a bitmap font, or a `FontFile` from an image) with antialiasing
  off, hinting none, subpixel positioning disabled, at its design size or an integer multiple.

**Palette by role.** Draw everything in role indices: the red channel holds index / 15. For 16
roles the stored byte is index × 17, so the index survives 8-bit storage exactly. Put one
`ShaderMaterial` on the scene's root `Node2D` and set `use_parent_material = true` on every child,
so sprites, `draw_rect()` calls and text all go through it:

```glsl
shader_type canvas_item;

uniform sampler2D palette : filter_nearest;   // a 16×1 texture, one role per pixel, in .gpl order

void fragment() {
	// COLOR already holds vertex colour × texture: this reads the index from a sprite's texture
	// and from a draw_rect()/polygon's colour alike. texture(TEXTURE, UV) would give white
	// (index 15) for everything drawn without a texture.
	vec4 src = COLOR;
	float index = floor(src.r * 15.0 + 0.5);
	COLOR = vec4(texture(palette, vec2((index + 0.5) / 16.0, 0.5)).rgb, src.a);
}
```

```gdscript
# a sprite from a grid of role indices (-1 = transparent)
func index_texture(w: int, h: int, cells: PackedInt32Array) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var i := cells[y * w + x]
			if i >= 0:
				img.set_pixel(x, y, Color(i / 15.0, 0, 0, 1))
	return ImageTexture.create_from_image(img)

# rectangles and text pixels in a role: draw_rect(Rect2(x, y, w, h), Color(role / 15.0, 0, 0))
# the palette texture: a 16×1 Image with set_pixel(i, 0, Color(hex_i)), as an ImageTexture
```

**Generated sprites (PNG) into role indices.** The cleaned PNGs hold palette colours, already
outlined in ink. Map each opaque pixel back to its role once at load, then build the index texture
as above (`grid()` makes `{w, h, d}` with `d` filled with -1). Drawing the PNG directly would bypass
the palette (the shader would read its red channel as an index), and a palette swap would miss it.

```gdscript
const PALETTE := ["#1E1430", "#FFF4D6", ...]   # the 16 roles, in .gpl order

func png_grid(path: String) -> Dictionary:
	var img: Image = (load(path) as Texture2D).get_image()
	img.convert(Image.FORMAT_RGBA8)
	var lut := {}
	for i in PALETTE.size(): lut[Color(PALETTE[i]).to_rgba32()] = i
	var g := grid(img.get_width(), img.get_height())
	for y in g.h:
		for x in g.w:
			var c := img.get_pixel(x, y)
			if c.a8 == 0: continue
			c.a8 = 255
			assert(lut.has(c.to_rgba32()), "off-palette pixel in " + path)
			g.d[y * g.w + x] = lut[c.to_rgba32()]
	return g

## Idle frame B for a standing figure: the row at 45% of the height is removed and the top drops 1 px.
func squash_grid(g: Dictionary) -> Dictionary:
	var cut := int(floor(g.h * 0.45))
	var o := grid(g.w, g.h)
	for y in g.h:
		if y == cut: continue
		var oy: int = y + 1 if y < cut else y
		for x in g.w:
			o.d[oy * g.w + x] = g.d[y * g.w + x]
	return o

# the cast: walk = 4 PNGs (contact, passing, contact, passing); traders = [png, squash_grid(png)];
# the beast = [standing PNG, chewing PNG]. The code-drawn props still go through outline().
```

The `assert` doubles as a lint: a sprite repainted off the palette fails at load, in the editor.

- Sprites: `Sprite2D` with `centered = false` at whole-pixel positions; flip with `flip_h`.
- The clear colour never goes through the shader. Set it to the palette's ink as a colour (and
  change it with the palette), or cover the screen with an ink-index rectangle.
- The 1 px ink outline can be added in code when a sprite is built: every empty cell with a filled
  4-neighbour becomes ink, as in `demo.html`. It then always matches the palette. The generated
  PNGs already carry it (the cleanup step writes it in), so they skip `outline()`.

**Traps hit** (none of them Compatibility-only; Forward+ gives the same frame):
- The palette shader must read `COLOR`, not `texture(TEXTURE, UV)`: the latter turns every
  `draw_rect()` and polygon into index 15 (white in the index space), most of the frame wrong.
- The clear colour bypasses the shader (see above).
- The viewport capture is the 320×180 base: scale it ×4 with nearest for a 1280×720 screenshot.
- GDScript can't infer a type from a ternary (`var oy := a if c else b` is a parse error); type it.

**Pixel-snapped camera** (the static key scene doesn't exercise it): keep the follow position as a
float, and round what the camera shows.

```gdscript
extends Camera2D

@export var target: Node2D
@export var follow := 0.15
var _pos := Vector2.ZERO

func _ready() -> void:
	_pos = target.global_position

func _physics_process(_delta: float) -> void:
	_pos = _pos.lerp(target.global_position, follow)
	global_position = _pos.round()
```

**Hit flash** in the same shader family: `COLOR.rgb = mix(COLOR.rgb, paper.rgb, flash)`, with
`flash` set to 1.0 for 2 frames, applied only where the index is not the outline's.

**Dim behind menus** with a 50% ink checker, not alpha: a full-screen `ColorRect` with this shader.
It is not part of the key-scene test. With stretch mode `viewport`, `FRAGCOORD` counts base pixels:

```glsl
shader_type canvas_item;
uniform vec4 ink : source_color;
void fragment() {
	COLOR = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0) < 1.0 ? ink : vec4(0.0);
}
```
