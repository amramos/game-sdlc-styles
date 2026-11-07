extends Node2D
## The tow rope from the sled to the walker's hand: a brush stroke drawn by the page, not the art.
const Ink = preload("res://ink/ink.gd")
@export var sled: Node2D
@export var walker: Node2D
@export var ground_y := 0.0
@export var width := 3.5

func _draw() -> void:
	var s: Rect2 = sled.rect(); var p: Rect2 = walker.rect()
	Ink.brush(self, PackedVector2Array([
		Vector2(s.end.x - 8, s.position.y + s.size.y * 0.45),
		Vector2((s.end.x + p.position.x) / 2 + 10, ground_y - 40),
		Vector2(p.position.x + p.size.x * 0.12, p.position.y + p.size.y * 0.48)]), width, Ink.c("ink"))
