class_name FocusBrackets
extends Control
## Focus mark: four L corners cut from the interface material (paper, 4 px ink outline), standing
## `gap` px clear of the focused rect. Corners only, never a full outline. When focus arrives they
## close in from `approach` px further out over 0.08 s.

@export var gap := 14.0
@export var approach := 12.0
var paper := Color.WHITE
var ink := Color.BLACK
var spread := 0.0:
	set(v):
		spread = v
		queue_redraw()

func show_around(r: Rect2, animate := true) -> void:
	var g := r.grow(gap)
	position = g.position.round()   # whole pixels keep the 4 px outline crisp
	size = g.end.ceil() - position
	spread = approach if animate else 0.0
	if animate:
		create_tween().tween_property(self, "spread", 0.0, 0.08).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	# one corner: a 30x30 box holding the L "M2 2 H28 V11 H11 V28 H2 Z", the box 16 px outside the rect
	var o := -16.0 - spread
	var far := Vector2(size.x - 30.0 - o, size.y - 30.0 - o)
	var corners := [[Vector2(o, o), 0.0], [Vector2(far.x, o), PI / 2],
		[Vector2(o, far.y), -PI / 2], [far, PI]]
	var l := PackedVector2Array([Vector2(2, 2), Vector2(28, 2), Vector2(28, 11), Vector2(11, 11), Vector2(11, 28), Vector2(2, 28)])
	for c in corners:
		var xf := Transform2D(c[1], c[0] + Vector2(15, 15)) * Transform2D(0.0, Vector2(-15, -15))
		var pts: PackedVector2Array = xf * l
		for p in Geometry2D.offset_polygon(pts, 2.0, Geometry2D.JOIN_MITER):
			draw_colored_polygon(p, ink)
		for p in Geometry2D.offset_polygon(pts, -2.0, Geometry2D.JOIN_MITER):
			draw_colored_polygon(p, paper)
