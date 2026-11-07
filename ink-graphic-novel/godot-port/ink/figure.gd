extends Node2D
## A cutout standing with its bottom centre on this node's position, `height` tall (or `width` wide).
@export var texture: Texture2D
@export var height := 0.0
@export var width := 0.0
@export var flip := false

func draw_size() -> Vector2:
	var t := texture.get_size()
	var s := height / t.y if height > 0.0 else width / t.x
	return t * s

## The drawn rect in the parent's coordinates (for things attached to the figure, like a rope).
func rect() -> Rect2:
	var d := draw_size()
	return Rect2(position.x - d.x / 2, position.y - d.y, d.x, d.y)

func _draw() -> void:
	var d := draw_size()
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect(texture, Rect2(-d.x / 2, -d.y, d.x, d.y), false)
