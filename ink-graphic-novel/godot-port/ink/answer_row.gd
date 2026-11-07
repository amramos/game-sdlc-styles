extends Node2D
## Lays the answer slips out at one common height (the tallest slip's).
func _ready() -> void:
	var h := 0.0
	for s in get_children():
		h = maxf(h, s.measure())
	for s in get_children():
		s.set_min_height(h)
