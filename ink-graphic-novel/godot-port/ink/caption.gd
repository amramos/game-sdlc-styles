extends Control
## Narration caption: lettered paper box, 3 px ink border, hard 5 px ink offset shadow. The box
## grows by whole lines (measured wrapping; nothing is ever cut). dark = ink box, paper letters.
const Ink = preload("res://ink/ink.gd")
@export_multiline var text := "":
	set(v): text = v; _layout()
@export var box_width := 300.0:
	set(v): box_width = v; _layout()
@export var font_size := 20:
	set(v): font_size = v; _layout()
@export var pad := 10.0
@export var title := false      # small-caps title face instead of capitals lettering
@export var lower := false
@export var dark := false
var lines := PackedStringArray()

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()

func _kind() -> String: return "tit" if title else "let"
func _lh() -> int: return roundi(font_size * 1.22)

func _layout() -> void:
	var t := text if (title or lower) else text.to_upper()
	lines = Ink.wrap(t, font_size, box_width - pad * 2, _kind())
	size = Vector2(box_width, lines.size() * _lh() + pad * 2)
	queue_redraw()

func _draw() -> void:
	var w := size.x; var h := size.y
	var ink := Ink.c("ink"); var paper := Ink.c("paper")
	draw_rect(Rect2(5, 5, w, h), ink)
	if dark:
		draw_rect(Rect2(0, 0, w, h), ink)
	else:
		Ink.paper_poly(self, Ink.rect_pts(0, 0, w, h), get_global_transform())
	var b := paper if dark else ink
	draw_rect(Rect2(0, 0, w, 3), b); draw_rect(Rect2(0, h - 3, w, 3), b)
	draw_rect(Rect2(0, 0, 3, h), b); draw_rect(Rect2(w - 3, 0, 3, h), b)
	var lh := _lh()
	for i in lines.size():
		Ink.text_top(self, pad, pad + i * lh + (lh - font_size) / 2.0, lines[i], font_size, paper if dark else ink, _kind())
