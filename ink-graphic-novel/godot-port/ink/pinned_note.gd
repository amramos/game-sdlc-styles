extends Node2D
## A handwritten note on ruled paper, pinned at an angle (the node rotates about the note's top-left).
const Ink = preload("res://ink/ink.gd")
@export_multiline var text := ""
@export var note_width := 364.0
@export var font_size := 20

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw() -> void:
	var w := note_width
	var lh := roundi(font_size * 1.3)
	var lines := Ink.wrap(text, font_size, w - 28, "let400")
	var h := lines.size() * lh + 38.0                   # 24 px top margin holds the pin
	var ink := Ink.c("ink")
	Ink.rect(self, 4, 4, w, h, ink)
	Ink.paper_poly(self, Ink.rect_pts(0, 0, w, h))
	for i in lines.size():
		Ink.rect(self, 10, 24 + (i + 1) * lh - 3, w - 20, 2, Ink.c("field-3"))
	for i in lines.size():
		Ink.text_top(self, 14, 24 + i * lh + (lh - font_size) / 2.0 - 2, lines[i], font_size, ink, "let400")
	Ink.disc(self, Vector2(w - 22, 10), 6, ink)
