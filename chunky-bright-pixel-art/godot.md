# Godot 4 snippets

<!-- matched-web-frame: 1ac034a6670a -->

> **The `assets/` paths below load this entry's example art**, which is how the port was tested against the web demo. A game never ships it: load the game's own models, sprites and textures, made the same way, in their place.

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.png` rebuilds
`demo.html?frame=key-scene` from `Sprite2D` and `draw_rect()` nodes, using this page's settings and
shader, and the entry's generated sprite PNGs (`assets/sprites/`) for the cast and the pack beast.
Measured match: mean difference 0.0/255, 0 pixels differ, both frames use the same 13 colours.
Forward+ (Vulkan) renders the same frame, also 0 pixels off: nothing here is renderer-specific.

The whole project that rendered the frame, including the code that rebuilds the web demo exactly, is
in this entry's `godot-port/` on the catalog site. This file keeps what a game needs to draw the look.

## Putting it together

```
Node2D (root)      the palette ShaderMaterial; script builds the scene in draw order
├─ RectBatch       a run of draw_rect() calls in role indices      use_parent_material = true
├─ Sprite2D        one per sprite placement, centered = false      use_parent_material = true
├─ RectBatch       a new batch starts after each sprite, so later rectangles draw on top
└─ …               text pixels and interface the same way
```

Everything draws a role **index**, never a colour; the one palette shader on the root turns indices
into colours, and every child inherits it. Sprites sit at whole-pixel positions and flip with
`flip_h`. The whole frame renders at 320 × 180 and is scaled by a whole number.

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
  off, hinting none, subpixel positioning disabled, at its design size or an integer multiple; or
  draw text as pixels in a role (`text()` below).

## Palette by role

Draw everything in role indices: the red channel holds index / 15. For 16 roles the stored byte is
index × 17, so the index survives 8-bit storage exactly. `palette.gdshader`, on the root `Node2D`:

```glsl
shader_type canvas_item;

// 16x1 texture, one role per pixel, in .gpl order
uniform sampler2D palette : filter_nearest;

void fragment() {
	// COLOR is already vertex colour x texture, so this works for sprites (index in the texture)
	// and for draw_rect()/polygons (index in the vertex colour) alike.
	vec4 src = COLOR;
	float index = floor(src.r * 15.0 + 0.5);
	COLOR = vec4(texture(palette, vec2((index + 0.5) / 16.0, 0.5)).rgb, src.a);
}
```

The root builds the 16 × 1 palette texture from the palette's hexes in `.gpl` order:

```gdscript
const PALETTE := ["#1E1430", "#FFF4D6", ...]   # the 16 roles, in .gpl order

func _ready() -> void:
	var pal := Image.create_empty(16, 1, false, Image.FORMAT_RGBA8)
	for i in 16: pal.set_pixel(i, 0, Color(PALETTE[i]))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://palette.gdshader")
	mat.set_shader_parameter("palette", ImageTexture.create_from_image(pal))
	material = mat
	build_sprites()
	key_scene()
```

`build_sprites()` and `key_scene()` are the example's sprites and scene.

## Drawing in indices

Rectangles batched in draw order, and sprites from grids of role indices (-1 = transparent):

```gdscript
## Batches consecutive rectangles into one node, drawn in order.
class RectBatch extends Node2D:
	var rects: Array = []
	func _draw() -> void:
		for r in rects:
			draw_rect(Rect2(r[0], r[1], r[2], r[3]), Color(r[4] / 15.0, 0, 0, 1))

var _batch: RectBatch = null

func idx(c: int) -> Color:
	return Color(c / 15.0, 0, 0, 1)

func rect(x: float, y: float, w: float, h: float, c: int) -> void:
	if w <= 0 or h <= 0:
		return
	if _batch == null:
		_batch = RectBatch.new()
		_batch.use_parent_material = true
		add_child(_batch)
	_batch.rects.append([roundi(x), roundi(y), int(w), int(h), c])

func px(x: float, y: float, c: int) -> void:
	rect(x, y, 1, 1, c)

func grid(w: int, h: int) -> Dictionary:
	var d := PackedInt32Array(); d.resize(w * h); d.fill(-1)
	return {"w": w, "h": h, "d": d}

func outline(g: Dictionary) -> Dictionary:
	var o := grid(g.w + 2, g.h + 2)
	for y in g.h:
		for x in g.w:
			o.d[(y + 1) * o.w + x + 1] = g.d[y * g.w + x]
	var src: PackedInt32Array = o.d.duplicate()
	for y in o.h:
		for x in o.w:
			if src[y * o.w + x] >= 0: continue
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + v.x
				var ny: int = y + v.y
				if nx >= 0 and ny >= 0 and nx < o.w and ny < o.h and src[ny * o.w + nx] >= 0:
					o.d[y * o.w + x] = INK
					break
	return o

## Grid -> ImageTexture with the role index in the red channel.
func tex(g: Dictionary) -> ImageTexture:
	if g.has("tex"): return g.tex
	var img := Image.create_empty(g.w, g.h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in g.h:
		for x in g.w:
			var v: int = g.d[y * g.w + x]
			if v >= 0: img.set_pixel(x, y, idx(v))
	g.tex = ImageTexture.create_from_image(img)
	return g.tex

func spr(g: Dictionary, x: float, y: float, flip := false) -> void:
	_batch = null   # later rects go in a new batch above this sprite
	var s := Sprite2D.new()
	s.texture = tex(g)
	s.centered = false
	s.flip_h = flip
	s.position = Vector2(roundi(x), roundi(y))
	s.use_parent_material = true
	add_child(s)
```

`outline()` adds the 1 px ink outline in code when a sprite is built: every empty cell with a filled
4-neighbour becomes ink (`INK`, the outline role's index), so it always matches the palette. The generated PNGs already carry it (the
cleanup step writes it in), so they skip `outline()`.

## Generated sprites (PNG) into role indices

The cleaned PNGs hold palette colours, already outlined in ink. Map each opaque pixel back to its
role once at load, then build the index texture with `tex()`. Drawing the PNG directly would bypass
the palette (the shader would read its red channel as an index), and a palette swap would miss it.

```gdscript
## The cast and the beast are PixelForge-cleaned PNGs on the palette, already outlined in ink.
## Each opaque pixel is mapped back to its role index, so the palette shader (and a palette
## swap) reaches them like everything else. Import them Lossless, mipmaps off.
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

## Idle frame B: the row at 45% of the height is removed and the top drops 1 px.
func squash_grid(g: Dictionary) -> Dictionary:
	var cut := int(floor(g.h * 0.45))
	var o := grid(g.w, g.h)
	for y in g.h:
		if y == cut: continue
		var oy: int = y + 1 if y < cut else y
		for x in g.w:
			o.d[oy * g.w + x] = g.d[y * g.w + x]
	return o
```

The `assert` doubles as a lint: a sprite repainted off the palette fails at load, in the editor.
A walk cycle is four PNGs (contact, passing, contact, passing); a standing idle is
`[png, squash_grid(png)]`.

## Pixel text

A 3 × 5 font drawn as pixels in a role, so text goes through the palette like everything else:

```gdscript
const GLYPHS := {   # 3 x 5 letters, rows separated by spaces; add the characters your game uses
	"A": ".#. #.# ### #.# #.#", "0": "### #.# #.# #.# ###", " ": "... ... ... ... ...",
}

func text(s: String, x: int, y: int, c: int) -> void:
	for n in s.length():
		var rows: PackedStringArray = GLYPHS[s[n]].split(" ")
		for j in 5:
			for i in 3:
				if rows[j][i] == "#": px(x + n * 4 + i, y + j, c)

func tw(s: String) -> int: return s.length() * 4 - 1
```

## Traps

None of them is Compatibility-only; Forward+ gives the same frame.

- The palette shader must read `COLOR`, not `texture(TEXTURE, UV)`: the latter turns every
  `draw_rect()` and polygon into index 15 (white in the index space), most of the frame wrong.
- The clear colour never goes through the shader. Set it to the palette's ink as a colour (and
  change it with the palette), or cover the screen with an ink-index rectangle.
- The viewport capture is the 320×180 base: scale it ×4 with nearest for a 1280×720 screenshot.
- GDScript can't infer a type from a ternary (`var oy := a if c else b` is a parse error); type it.

## Not in the test

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
With stretch mode `viewport`, `FRAGCOORD` counts base pixels:

```glsl
shader_type canvas_item;
uniform vec4 ink : source_color;
void fragment() {
	COLOR = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0) < 1.0 ? ink : vec4(0.0);
}
```
