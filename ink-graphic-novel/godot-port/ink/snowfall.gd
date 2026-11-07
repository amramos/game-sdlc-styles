extends Node2D
## Falling snow: paper dots wrapping inside `area`. `t` is the time in seconds (the key scene poses
## it at 0.4). Seeded so a frame is repeatable.
const Ink = preload("res://ink/ink.gd")
@export var area := Vector2(840, 520)
@export var count := 90
@export var seed := 9
@export var t := 0.4
@export var animate := false

func _process(delta: float) -> void:
	if animate:
		t += delta
		queue_redraw()

func _draw() -> void:
	var r := Ink.Rng.new(seed)
	var paper := Ink.c("paper")
	for i in count:
		var x := fmod(r.next() * area.x + t * (6.0 + r.next() * 6.0), area.x)
		var y := fmod(r.next() * area.y + t * (14.0 + r.next() * 10.0), area.y)
		var s := 1.5 + r.next() * 2.5
		Ink.disc(self, Vector2(x, y), s, paper)
