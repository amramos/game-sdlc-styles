class_name GlowPass
extends Node2D
## One bloom pass, built like the web demo's beginGlow()/endGlow():
##   lines  - crisp layer: colour core + near-white centre, normal blend (transparent SubViewport)
##   bloom  - bloom source: pure colour, a little wider, additive (transparent SubViewport)
## The source is blurred at each radius of `spec` (separable Gaussian, at a reduced working
## resolution for wide radii), each copy is added onto the frame with its gain, then the crisp
## layer goes on top. Add this node where the pass belongs in the draw order, then call setup().
## Each spec level: {r = blur radius in 720p px, g = gain, s = working resolution}.
## An empty spec gives a plain antialiased layer (no bloom): use it for the grid and fills.
##
## Antialiasing: the Compatibility renderer ignores Line2D.antialiased, draw_*(antialiased) and
## 2D MSAA, so both layers are drawn at SS x the screen resolution and filtered down (supersampling).

const BASE := Vector2(1280, 720)        # the game's logical resolution
const SS := 2                           # supersampling factor; 2 = 4 samples per pixel
const BLUR := preload("res://blur.gdshader")
const ADD_GAIN := preload("res://add_gain.gdshader")
const GROUP_ADD := preload("res://group_add.gdshader")

var lines: Node2D       # draw crisp lines and fills here (720p coordinates)
var bloom: Node2D       # draw bloom-source strokes here; null without bloom or when blurring lines
var _add := CanvasItemMaterial.new()
var _group_add := ShaderMaterial.new()

## blur_lines = true: blur the crisp layer itself (HUD text), as endGlow(spec, "line").
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
		# Downsample like the canvas's bilinear drawImage: 1 screen px at full size, the middle
		# 2 x 2 screen px when shrinking. Prefilter taps sit +-0.5 screen px from the centre.
		var pre := Vector2.ZERO if level.s >= 1.0 else Vector2(0.5 / px.x, 0.5 / px.y)
		var h := _blur_viewport(size, src, Vector2(1.0 / size.x, 0), sigma, pre)
		var v := _blur_viewport(size, h.get_texture(), Vector2(0, 1.0 / size.y), sigma, Vector2.ZERO)
		var copy := _layer(v.get_texture())
		var m := ShaderMaterial.new(); m.shader = ADD_GAIN; m.set_shader_parameter("gain", level.g)
		copy.material = m
	var top := _layer(line_vp.get_texture())       # SS x SS texels -> 1 px: bilinear = box filter at SS 2
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
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # bilinear up (blurs) and down (SS layers)
	add_child(r)
	return r

# ------------------------------------------------------------------ drawing into the pass
## glowStroke(): core (w) and near-white centre (75% to white, 0.45 w) on the line layer; pure colour,
## w + 2k wide, alpha min(1, k), additive on the bloom source. path: [{pts, closed}, ...].
func stroke(path: Array, c: Color, w: float, k := 1.0, xf := Transform2D.IDENTITY) -> void:
	var ln := _holder(lines, xf)
	for s in path: line(ln, s, c, w)
	for s in path: line(ln, s, whiter(c, 0.75), maxf(1.0, w * 0.45))
	if bloom:
		# One canvas stroke covers each pixel once even where subpaths overlap (the splitter's
		# rings, a cross inside a circle). A CanvasGroup does the same: opaque union inside,
		# then the group is added with alpha min(1, k).
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
