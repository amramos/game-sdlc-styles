extends Control
## A bare question: small-caps title lettering straight on the page, no box.
const Ink = preload("res://ink/ink.gd")
@export var text := ""
@export var font_size := 30

func _draw() -> void:
	Ink.text_top(self, 0, 0, text, font_size, Ink.c("ink"), "tit")
