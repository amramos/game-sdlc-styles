extends Node2D
## A sound word: big small-caps serif letters, ink copy offset 6 px, an 8 px ink stroke under a paper
## fill. The node's position is the right end of the word's top line; it rotates by `angle`.
const Ink = preload("res://ink/ink.gd")
@export var text := "RUFF!"
@export var font_size := 44
@export var angle := -0.08
@export var outline := 8

func _draw() -> void:
	var w := Ink.text_w(text, font_size, "tit")
	draw_set_transform_matrix(Transform2D(0.0, Vector2(-w, 0)) * Transform2D(angle, Vector2.ZERO))
	var base := Ink.top_offset(font_size, "tit")
	Ink.text_base(self, 6, 6 + base, text, font_size, Ink.c("ink"), "tit")
	Ink.text_stroke_base(self, 0, base, text, font_size, outline, Ink.c("ink"), "tit")
	Ink.text_base(self, 0, base, text, font_size, Ink.c("paper"), "tit")
