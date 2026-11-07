extends Node2D
## An answer as a torn scrap of paper: its key in an ink disc, the answer in capitals. The focused
## slip is lifted 7 px with a 10 px shadow, a 3 px edge and a brush underline; an unavailable one
## (off) has no shadow, a field-3 edge and its reason below. Place the node at the slip's top-left
## as laid out; at runtime it moves to the slip's centre and rotates about it.
const Ink = preload("res://ink/ink.gd")
const PAD_L := 46.0
@export_multiline var text := ""
@export var key := "1"
@export var slip_width := 262.0
@export var font_size := 20
@export var focus := false:
	set(v): focus = v; if is_inside_tree(): _place()
@export var off := false
@export var reason := ""
@export var angle := 0.0
@export var seed := 1
var min_height := 0.0
var _origin := Vector2.ZERO    # the layout position (top-left before lift and rotation)

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_origin = position
	_place()

func _lh() -> int: return roundi(font_size * 1.2)
func _small() -> int: return maxi(16, font_size - 4)
func _lines() -> PackedStringArray: return Ink.wrap(text.to_upper(), font_size, slip_width - PAD_L - 14)
func _reason() -> PackedStringArray:
	return Ink.wrap(reason, _small(), slip_width - PAD_L - 14, "let400") if reason != "" else PackedStringArray()

func measure() -> float:
	return maxf(min_height, _lines().size() * _lh() + _reason().size() * roundi(_small() * 1.2) + 26)

func set_min_height(h: float) -> void:
	min_height = h
	_place()

func _place() -> void:
	var h := measure()
	var lift := 7.0 if focus else 0.0
	position = _origin + Vector2(slip_width / 2, h / 2 - lift)
	rotation = angle
	queue_redraw()

## A torn scrap: straight-ish long edges, ragged short edges with fine fibres.
static func torn_rect(w: float, h: float, seed_: int) -> PackedVector2Array:
	var r := Ink.Rng.new(seed_)
	var pts := PackedVector2Array()
	var x := 0.0
	while x < w:
		pts.append(Vector2(x, (r.next() - 0.5) * 2)); x += 18
	var y := 0.0
	while y < h:
		pts.append(Vector2(w - 2 + (r.next() - 0.5) * 3 + sin(y * 0.45) * 1.2, y)); y += 3
	x = w
	while x > 0:
		pts.append(Vector2(x, h + (r.next() - 0.5) * 2)); x -= 18
	y = h
	while y > 0:
		pts.append(Vector2(2 + (r.next() - 0.5) * 3 + sin(y * 0.5) * 1.2, y)); y -= 3
	return pts

func _draw() -> void:
	var w := slip_width; var h := measure()
	var ink := Ink.c("ink"); var paper := Ink.c("paper")
	draw_set_transform(Vector2(-w / 2, -h / 2))
	var pts := torn_rect(w, h, seed)
	var sh := 0.0 if off else (10.0 if focus else 4.0)
	if sh > 0.0:
		var moved := PackedVector2Array()
		for p in pts:
			moved.append(p + Vector2(sh, sh))
		Ink.fill(self, moved, ink)
	Ink.paper_poly(self, pts)                    # the grain pattern in the slip's own (rotated) space
	Ink.stroke_poly(self, pts, true, 3.0 if focus else 2.0, Ink.c("field-3") if off else ink)
	var lh := _lh()
	Ink.disc(self, Vector2(24, 13 + lh / 2.0), 14, Ink.c("field-3") if off else ink)
	var kw := Ink.text_w(key, 18)
	Ink.text_base(self, 24 - kw / 2, 14 + lh / 2.0 + Ink.top_offset(18) - 9.0, key, 18, paper)
	var lines := _lines()
	for i in lines.size():
		Ink.text_top(self, PAD_L, 13 + i * lh + (lh - font_size) / 2.0, lines[i], font_size, Ink.c("field-2") if off else ink)
	var rs := _reason()
	for i in rs.size():
		Ink.text_top(self, PAD_L, 13 + lines.size() * lh + 2 + i * roundi(_small() * 1.2), rs[i], _small(), ink, "let400")
	if focus:
		Ink.brush(self, PackedVector2Array([Vector2(PAD_L, h - 9), Vector2(PAD_L + (w - PAD_L) * 0.45, h - 11), Vector2(w - 20, h - 9)]), 3.5, ink)
