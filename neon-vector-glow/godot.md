# Godot 4 snippets

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.png` rebuilds
`demo.html?frame=key-scene`: same grid warp, sparks, shapes, three-radius bloom, danger pass and
boxless HUD. Measured against the web frame: mean difference **0.7 / 0.8 / 1.0** per 255 (R/G/B),
3.6% of pixels off by more than 8, 0.4% by more than 24, no structural difference. **Forward+**
draws the same frame (mean 0.1/255 against the Compatibility render). What still differs:

- **The spark burst** (worst tiles, about 9/255 on average): dozens of 1.5 px sparks, each a few
  pixels long. Godot's supersampled coverage and the canvas's analytic coverage disagree by a
  fraction of a pixel per spark, and that adds up where the sparks pile.
- **Antialiased edges** everywhere else (lines, grid, glyphs): within a few levels, from 2 × 2
  supersampling against the canvas's analytic antialiasing.
- **The wide bloom** is smoother in Godot: the canvas blurs in 8 bits at quarter resolution and
  multiplies by 3.2, so its bloom bands in steps of 3 levels. Godot's float blur doesn't.
- **HUD glyphs** sit within 1 px of the web's (hinting), drawn from the same font files.

<!-- matched-web-frame: 80d521908988 -->

The whole project that rendered the frame, including the script that rebuilds the web demo exactly
(its seeded random, shapes, positions and HUD values), is in this entry's `godot-port/` on the
catalog site.

## How the bloom is made

Godot's engine glow does not reproduce this look. An earlier test with one level and an overall gain
came out faint with clipped cores in Compatibility, and swelled every halo in Forward+. HDR 2D also
blends all 2D in linear light, which darkens the grid. So the port does exactly what the web demo
does, with SubViewports:

1. Every **glow pass** has two transparent SubViewports: a **line layer** (each path's core in its
   colour, then a near-white centre, normal blend) and a **bloom source** (the same path in pure
   colour, width + 2k, alpha min(1, k), additive).
2. The source is **blurred at each radius** with a separable Gaussian (an H and a V SubViewport per
   radius, at full, half or quarter resolution). Each blurred copy is **added** onto the frame with
   its gain (`TextureRect`, `blend_add`, colour × gain).
3. The **line layer goes on top** (`BLEND_MODE_PREMULT_ALPHA`: a transparent SubViewport holds
   premultiplied colour).

| Pass | Radii (720p px) | Gains | Working resolution |
|---|---|---|---|
| world | 2, 7, 24 | 1.2, 1.8, 3.2 | 1, ½, ¼ |
| danger | 2, 6 | 1.0, 1.2 | 1, ½ |
| HUD (blurs its own line layer) | 1.5, 5 | 0.55, 0.45 | 1, ½ |

The canvas's `blur(r)` is a Gaussian with sigma r. Its shrinking `drawImage` is bilinear, so a
half- or quarter-size copy averages the middle 2 × 2 screen pixels. The blur shader does the same
with four prefilter taps.

**Antialiasing.** Compatibility in 4.7.1 draws these 2D lines without antialiasing (see the traps below),
so every layer that holds lines (the grid, both glow layers, the void rims) renders at **2× the
screen resolution** and is filtered down when composited. A bilinear sample at the centre of a 2 × 2
block is the box filter, so `TEXTURE_FILTER_LINEAR` is enough. Text on those layers is drawn at
twice the font size under a ½ transform, so glyphs are rasterised sharp, not scaled up.

**Cost** of the test scene: 21 SubViewports (plain layers 1 each; world 2 + 6; danger 2 + 4; HUD
1 + 4), the two layers per pass at 2× the window. On weak GPUs or on the web, set `SS = 1`. Lines
then alias, but the bloom is unchanged. Or drop the danger pass's half-resolution copy.

## Project settings

- `renderer/rendering_method = "gl_compatibility"` (Forward+ gives the same frame).
- Viewport 1280×720 (the demo's logical size), stretch mode `canvas_items`, aspect `expand`. Clear
  colour = `void`. Leave `use_hdr_2d` off: all blending stays in sRGB, as on the canvas.
- `GlowPass.setup()` sizes its SubViewports from `get_window().size` (real pixels) and scales its
  content to match, as the demo scales its canvas by `devicePixelRatio`. Rebuild the passes when the
  window size changes.
- Fonts: the demo's own files from its `assets/fonts/`, copied to `res://fonts/` and loaded as
  `FontFile`s: Cascadia Mono Bold for numbers, Open Sans Bold for labels (both SIL OFL).
- No other imported assets: everything else is drawn in code.

## glow_pass.gd

```gdscript
class_name GlowPass
extends Node2D
## One bloom pass: add it where it belongs in the draw order, call setup(), draw into `lines`
## (and `bloom`) with stroke(), plain(), spark() and paint(). An empty spec gives a plain
## supersampled layer with no bloom (grid, fills).

const BASE := Vector2(1280, 720)        # the game's logical resolution
const SS := 2                           # supersampling factor; 2 = 4 samples per pixel
const BLUR := preload("res://blur.gdshader")
const ADD_GAIN := preload("res://add_gain.gdshader")
const GROUP_ADD := preload("res://group_add.gdshader")

var lines: Node2D       # crisp lines and fills (720p coordinates)
var bloom: Node2D       # bloom source; null without bloom or when blurring the lines
var _add := CanvasItemMaterial.new()
var _group_add := ShaderMaterial.new()

## spec: [{r = blur radius in 720p px, g = gain, s = working resolution}, ...]
## blur_lines = true: blur the line layer itself (HUD text), as the demo's endGlow(spec, "line").
func setup(spec: Array, blur_lines := false) -> void:
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_group_add.shader = GROUP_ADD
	var px := Vector2i(get_window().size)          # real pixels, so lines stay sharp at any size
	var k := px.x / BASE.x
	var line_vp := _viewport(px * SS)
	lines = Node2D.new(); lines.scale = Vector2(k, k) * SS; line_vp.add_child(lines)
	var src: Texture2D = line_vp.get_texture()
	if not blur_lines and not spec.is_empty():
		var bloom_vp := _viewport(px * SS)
		bloom = Node2D.new(); bloom.scale = Vector2(k, k) * SS; bloom_vp.add_child(bloom)
		src = bloom_vp.get_texture()
	for level in spec:
		var size := Vector2i(ceili(px.x * level.s), ceili(px.y * level.s))
		var sigma: float = level.r * k * level.s     # canvas blur(r) = Gaussian with sigma r
		# Shrink like the canvas's bilinear drawImage: the middle 2 x 2 screen px per texel.
		var pre := Vector2.ZERO if level.s >= 1.0 else Vector2(0.5 / px.x, 0.5 / px.y)
		var h := _blur_viewport(size, src, Vector2(1.0 / size.x, 0), sigma, pre)
		var v := _blur_viewport(size, h.get_texture(), Vector2(0, 1.0 / size.y), sigma, Vector2.ZERO)
		var copy := _layer(v.get_texture())
		var m := ShaderMaterial.new(); m.shader = ADD_GAIN; m.set_shader_parameter("gain", level.g)
		copy.material = m
	var top := _layer(line_vp.get_texture())       # 2 x 2 texels -> 1 px: bilinear = box filter
	var premul := CanvasItemMaterial.new(); premul.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	top.material = premul

# Created in dependency order (source, H blur, V blur); Godot draws sibling SubViewports in that order.
func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp

func _blur_viewport(size: Vector2i, src: Texture2D, step: Vector2, sigma: float, pre: Vector2) -> SubViewport:
	var vp := _viewport(size)
	var rect := ColorRect.new(); rect.size = size
	var m := ShaderMaterial.new(); m.shader = BLUR
	m.set_shader_parameter("src", src); m.set_shader_parameter("step_uv", step)
	m.set_shader_parameter("sigma", sigma); m.set_shader_parameter("pre_uv", pre)
	rect.material = m
	vp.add_child(rect)
	return vp

func _layer(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = BASE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # bilinear up (blurs) and down (2x layers)
	add_child(r)
	return r

## The demo's glowStroke(): core (w) and near-white centre (75% to white, 0.45 w) on the line layer;
## pure colour, w + 2k wide, alpha min(1, k), additive on the bloom source. path: [{pts, closed}, ...]
func stroke(path: Array, c: Color, w: float, k := 1.0, xf := Transform2D.IDENTITY) -> void:
	var ln := _holder(lines, xf)
	for s in path: line(ln, s, c, w)
	for s in path: line(ln, s, whiter(c, 0.75), maxf(1.0, w * 0.45))
	if bloom:
		# One canvas stroke covers each pixel once even where subpaths overlap (rings in a cluster,
		# a cross inside a circle). A CanvasGroup does the same: opaque union, then added at min(1, k).
		var group := CanvasGroup.new(); group.transform = xf
		group.self_modulate = Color(1, 1, 1, minf(1.0, k)); group.material = _group_add
		bloom.add_child(group)
		for s in path: line(group, s, c, w + 2.0 * k)

## A plain stroke on the line layer only (dim arcs, HUD icons).
func plain(path: Array, c: Color, w: float, xf := Transform2D.IDENTITY) -> void:
	var ln := _holder(lines, xf)
	for s in path: line(ln, s, c, w)

## Sparks: additive on the line layer, and into the bloom source at 60%.
func spark(a: Vector2, b: Vector2, c: Color, alpha: float) -> void:
	line(lines, {"pts": PackedVector2Array([a, b]), "closed": false}, Color(c, alpha), 1.5, _add)
	if bloom: line(bloom, {"pts": PackedVector2Array([a, b]), "closed": false}, Color(c, 0.6 * alpha), 1.5, _add)

## Fills and text on the line layer: fn(canvas_item) runs in _draw(), in 720p coordinates.
func paint(fn: Callable) -> void:
	var p := Painter.new(); p.fn = fn; lines.add_child(p)

class Painter extends Node2D:
	var fn: Callable
	func _draw() -> void: fn.call(self)

func _holder(parent: Node2D, xf: Transform2D) -> Node2D:
	var n := Node2D.new(); n.transform = xf; parent.add_child(n)
	return n

static func line(parent: Node, s: Dictionary, c: Color, w: float, mat: Material = null,
		cap := Line2D.LINE_CAP_ROUND, joint := Line2D.LINE_JOINT_ROUND) -> Line2D:
	var l := Line2D.new()
	l.points = s.pts; l.closed = s.closed
	l.width = w; l.default_color = c
	l.joint_mode = joint; l.begin_cap_mode = cap; l.end_cap_mode = cap
	l.material = mat
	parent.add_child(l)
	return l

static func whiter(c: Color, t: float) -> Color:   # the demo's mix(): per channel in 0-255, rounded
	return Color8(roundi(c.r8 + (255 - c.r8) * t), roundi(c.g8 + (255 - c.g8) * t), roundi(c.b8 + (255 - c.b8) * t))
```

## Shaders

`blur.gdshader`: one axis of the Gaussian, run H then V per radius.

```glsl
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;   // the target is transparent: write premultiplied colour as is

uniform sampler2D src : filter_linear, repeat_disable;
uniform vec2 step_uv;            // one target pixel along the blur axis, in UV
uniform float sigma = 2.0;
uniform vec2 pre_uv = vec2(0.0); // H pass when shrinking: average 4 taps this far from each sample

vec4 tap(vec2 uv) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return vec4(0.0);        // outside the frame is empty, as on a canvas
	}
	if (pre_uv == vec2(0.0)) {
		return texture(src, uv);
	}
	return 0.25 * (texture(src, uv + pre_uv) + texture(src, uv - pre_uv)
		+ texture(src, uv + vec2(pre_uv.x, -pre_uv.y)) + texture(src, uv + vec2(-pre_uv.x, pre_uv.y)));
}

void fragment() {
	int n = int(ceil(sigma * 3.0));
	vec4 acc = vec4(0.0);
	float wsum = 0.0;
	for (int i = -n; i <= n; i++) {
		float w = exp(-0.5 * float(i * i) / (sigma * sigma));
		acc += tap(UV + step_uv * float(i)) * w;
		wsum += w;
	}
	COLOR = acc / wsum;
}
```

`add_gain.gdshader`: adds a blurred copy with its gain (the web adds the copy `g` times with `'lighter'`).

```glsl
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float gain = 1.0;

void fragment() {
	COLOR = vec4(texture(TEXTURE, UV).rgb * gain, 1.0);
}
```

`group_add.gdshader`: the material of each bloom-source `CanvasGroup`.

```glsl
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);   // the group's union, premultiplied
	COLOR = vec4(c.rgb * COLOR.a, 1.0);                     // COLOR.a = self_modulate.a = min(1, k)
}
```

## Putting it together

The scene root is a `Node2D` whose children are the passes, added in draw order. Each pass is a
`GlowPass` node holding its own SubViewports and the `TextureRect`s that composite them:

```text
Main (Node2D; clear colour = void)
├─ ground  GlowPass([])                 void fill and the grid, never in the bloom
├─ world   GlowPass(BLOOM.world)        sparks, then every glowing shape, the player last
├─ rims    GlowPass([])                 void discs cut around each threat, over the world bloom
├─ danger  GlowPass(BLOOM.danger)       threats in their own tighter pass
├─ fade    Painter                      edge fade behind the HUD (not a box)
└─ hud     GlowPass(BLOOM.hud, true)    numbers, labels and icons; blurs its own line layer
```

`BLOOM` holds the table above:

```gdscript
const BLOOM := {   # r: blur radius in 720p px; g: gain; s: working resolution
	"world":  [{"r": 2.0, "g": 1.2, "s": 1.0}, {"r": 7.0, "g": 1.8, "s": 0.5}, {"r": 24.0, "g": 3.2, "s": 0.25}],
	"danger": [{"r": 2.0, "g": 1.0, "s": 1.0}, {"r": 6.0, "g": 1.2, "s": 0.5}],
	"hud":    [{"r": 1.5, "g": 0.55, "s": 1.0}, {"r": 5.0, "g": 0.45, "s": 0.5}],
}
```

Each step below is a node added in this order (the shapes and HUD values are an example's):

```gdscript
func glow_pass(spec: Array, blur_lines := false) -> GlowPass:
	var g := GlowPass.new(); add_child(g); g.setup(spec, blur_lines)
	return g

# 1. Void and grid on a plain 2x layer (the grid never glows).
var ground := glow_pass([])
ground.paint(func(ci: CanvasItem): ci.draw_rect(Rect2(0, 0, W, H), col("void")))
draw_grid(ground.lines)

# 2. World pass: sparks first, then pickups, core, player shots, enemies, player, hazards.
var world := glow_pass(BLOOM.world)
for p in parts:
	world.spark(Vector2(p.x, p.y), Vector2(p.x - p.vx * 0.035, p.y - p.vy * 0.035), p.col, 0.8 * p.life / p.max)
world.stroke(shape("shard", 8), col("pickup"), 2, 0.55, Transform2D(angle, pos))   # small: k 0.55
world.stroke(shape("player", 16), col("player"), 3, 1.3, Transform2D(angle, pos))  # the widest halo
world.stroke(dashed_ring(center, 70, 12, 9, -t * 40), col("danger"), 2, 0.7)       # hazard telegraph
world.paint(func(ci: CanvasItem): ci.draw_circle(center, 70 * minf(1, t / warn), Color(col("danger"), 0.06)))

# 3. A void rim around each enemy shot, cut into the finished bloom, then the shots' own pass.
var rims := glow_pass([])
rims.paint(func(ci: CanvasItem):
	for b in enemy_shots: ci.draw_circle(b, 5 + 4, col("void")))
var danger := glow_pass(BLOOM.danger)
for b in enemy_shots:
	danger.stroke([arc(b.x, b.y, 5, 0, TAU)], col("danger"), 2.5)
	danger.paint(func(ci: CanvasItem): ci.draw_circle(b, 5 * 0.45, whiter(col("danger"), 0.6)))

# 4. Edge fade on the frame (void 0.85 -> 0 over the top 112 px), then the HUD pass.
paint(func(ci: CanvasItem):
	var v := col("void")
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 112), Vector2(0, 112)]),
		PackedColorArray([Color(v, 0.85), Color(v, 0.85), Color(v, 0), Color(v, 0)])))
var hud := glow_pass(BLOOM.hud, true)
hud.paint(func(ci: CanvasItem):
	var sw := text(ci, f_num, score_text, 28, 56, 36)
	text(ci, f_num, "×%d" % mult, 28 + sw + 16, 56, 24, 0.8)
	var ww := text(ci, f_num, "%02d" % wave, W - 28, 56, 36, 1.0, true)
	text(ci, f_label, "WAVE", W - 28 - ww - 12, 56, 16, 0.65, true))
for i in lives:   # the player's shape pointing up, a plain 2 px line
	hud.plain(shape("player", 9), col("player"), 2, Transform2D(-PI / 2, Vector2(38 + i * 26, 84)))
```

Paths are arrays of `{pts: PackedVector2Array, closed: bool}`, one per subpath. Arcs and rings
become polylines with chords of about 3 px, and a full ring is a closed `Line2D` (no repeated end
point). Dashes become one open arc per dash:

```gdscript
func arc(cx: float, cy: float, r: float, a0: float, a1: float) -> Dictionary:
	var full := absf(a1 - a0) >= TAU - 1e-6
	var n := maxi(8, int(ceil(absf(a1 - a0) * maxf(r, 4.0) / 3.0)))
	var pts := PackedVector2Array()
	for i in (n if full else n + 1):
		var a := a0 + (a1 - a0) * i / n
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return {"pts": pts, "closed": full}

func dashed_ring(c: Vector2, r: float, on: float, off: float, offset: float) -> Array:
	var out := []
	var circ := TAU * r; var s := 0.0; var period := on + off
	while s < circ:
		var phase := fposmod(s + offset, period)
		var next := s + (on - phase if phase < on else period - phase)
		if phase < on: out.append(arc(c.x, c.y, r, s / r, minf(next, circ) / r))
		s = next
	return out
```

**HUD text.** Glyphs on a 2× layer are drawn at twice the size under a ½ transform. Tracked labels
(`ctx.letterSpacing = "2px"`) use a `FontVariation` with `spacing_glyph = 2 × SS`. The canvas counts
the spacing after the last letter when it aligns text, and Godot doesn't, so add it to the width:

```gdscript
## The demo's own font files (assets/fonts/ on the web), in the one weight the key scene uses.
var f_body: Font = load("res://fonts/OpenSans-Bold.woff")
var f_num: Font = load("res://fonts/CascadiaMono-Bold.woff")
var f_label := FontVariation.new()   # base_font = f_body, spacing_glyph = 2 * GlowPass.SS

func text(ci: CanvasItem, f: Font, s: String, x: float, y: float, size: int, alpha := 1.0, right := false) -> float:
	var ss := GlowPass.SS
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size * ss).x / ss
	if f == f_label: w += 2
	if right: x -= w
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE / ss)
	ci.draw_string(f, Vector2(x, y) * ss, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size * ss, Color(col("hud-ink"), alpha))
	ci.draw_set_transform(Vector2.ZERO)
	return w
```

**Grid:** the recipe's spring mesh in `PackedFloat32Array`s (positions and velocities), stepped at
a fixed 1/60 s. Draw it on the ground layer:

```gdscript
func draw_grid(root: Node2D) -> void:
	var gc := col("grid")
	for major in [false, true]:   # one CanvasGroup per weight: crossings don't stack alpha
		var g := CanvasGroup.new(); g.self_modulate.a = 1.0 if major else 0.55; root.add_child(g)
		var w := 1.5 if major else 1.0
		for y in GR:
			if (y % 4 == 0) == major:
				var pts := PackedVector2Array()
				for x in GC: pts.append(Vector2(gpx[y * GC + x], gpy[y * GC + x]))
				GlowPass.line(g, {"pts": pts, "closed": false}, gc, w, null, Line2D.LINE_CAP_NONE, Line2D.LINE_JOINT_SHARP)
		# ... the same for columns (x % 4 == 0)
	# Warp: each segment whose average offset is over 2 px adds the grid colour again,
	# additive, alpha min(1, offset / 14), width 1.5, no caps.
```

Rebuild the grid nodes (or `queue_redraw()` a `_draw()` version) only while some point is more than
0.5 px from rest. In live play, rebuild each pass's strokes per frame or move pooled `Line2D`s. For a
large swarm, draw each pass from one `_draw()` per layer instead of a node per stroke. That isn't
tested here.

**Shake:** move a `Camera2D`'s `offset`, never its rotation, and keep the HUD pass out of it.

## Compatibility traps found here

From `godot-compatibility.md` (copied beside this file), as they showed here:

- **18:** `msaa_2d` at 8× on the project, the root viewport and every SubViewport left the frame
  unchanged byte for byte; a 1.1 px centre line looked 2 px wide. `GlowPass` supersamples at 2×.
- **21:** separate additive `Line2D`s made a cluster of overlapping rings bloom up to +13/255 too
  bright. Each path's bloom-source strokes are opaque inside a `CanvasGroup`, added once.
- **20:** a `CanvasItemMaterial` set to ADD turned every group into a white rectangle;
  `group_add.gdshader` above works.
- **19:** SubViewports are composited with `BLEND_MODE_PREMULT_ALPHA`, blur results written with
  `blend_premul_alpha`.
- **23:** text is drawn at the layer's resolution (size × SS under a 1/SS transform).
