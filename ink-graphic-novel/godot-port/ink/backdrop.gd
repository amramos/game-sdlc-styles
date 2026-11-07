extends Control
## A backdrop filling its rect, cropped like CSS object-fit: cover; focus picks the kept part (0..1).
@export var texture: Texture2D
@export var focus := Vector2(0.5, 0.5)
@export var zoom := 1.0

func _draw() -> void:
	var t := texture.get_size()
	var s := maxf(size.x / t.x, size.y / t.y) * zoom
	var src := Vector2(size.x / s, size.y / s)
	var at := (t - src) * focus
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), Rect2(at, src))
