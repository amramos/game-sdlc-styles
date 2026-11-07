extends Control
## A comic panel: clips its art and lettering to its rect; the 5 px ink border is drawn on top of
## everything inside it (an internal child added last).
const Ink = preload("res://ink/ink.gd")

class Border extends Control:
	func _draw() -> void:
		var ink := Ink.c("ink")
		var s := size
		draw_rect(Rect2(0, 0, s.x, 5), ink); draw_rect(Rect2(0, s.y - 5, s.x, 5), ink)
		draw_rect(Rect2(0, 0, 5, s.y), ink); draw_rect(Rect2(s.x - 5, 0, 5, s.y), ink)

func _ready() -> void:
	clip_contents = true
	var b := Border.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b, false, Node.INTERNAL_MODE_BACK)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
