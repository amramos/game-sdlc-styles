extends Control
## Speech balloon: paper round-rect with a 3 px ink stroke and a tail to the speaker (`tail`, in the
## parent's coordinates). Lines centred, capitals lettering.
const Ink = preload("res://ink/ink.gd")
@export_multiline var text := ""
@export var box_width := 228.0
@export var font_size := 18
@export var tail := Vector2.ZERO
var lines := PackedStringArray()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines = Ink.wrap(text.to_upper(), font_size, box_width - 24)
	size = Vector2(box_width, lines.size() * _lh() + 18)

func _lh() -> int: return roundi(font_size * 1.22)

func _draw() -> void:
	var w := size.x; var h := size.y
	var ink := Ink.c("ink"); var paper := Ink.c("paper")
	var tip := tail - position
	var tri := PackedVector2Array([Vector2(w * 0.62, h - 2), tip, Vector2(w * 0.78, h - 2)])
	Ink.fill(self, tri, paper)
	Ink.stroke_poly(self, tri, true, 3.0, ink)
	var rr := Ink.round_rect(0, 0, w, h, h / 2.4)
	Ink.fill(self, rr, paper)
	Ink.stroke_poly(self, rr, true, 3.0, ink)
	Ink.rect(self, w * 0.62 + 3, h - 6, w * 0.16 - 6, 6, paper)     # join the tail
	var lh := _lh()
	for i in lines.size():
		var lw := Ink.text_w(lines[i], font_size)
		Ink.text_top(self, (w - lw) / 2, 9 + i * lh + (lh - font_size) / 2.0, lines[i], font_size, ink)
