extends Node2D
## The flown title placard, painted once into a 640x180 SubViewport: card back, torn paper,
## double ruled frame and the scene's name in italic bold. The image becomes the placard's texture.

const Rng := preload("res://mulberry32.gd")
var title := "The Birch Wood"
var paper := Color("#F3EAD2")
var card := Color("#5A3E2B")
var ink := Color("#2B2118")
var font: Font

func _draw() -> void:
	draw_rect(Rect2(6, 10, 628, 164), card)
	var r := Rng.new(9)
	var pts := PackedVector2Array()
	for x in range(0, 621, 20): pts.append(Vector2(x, r.next() * 5.0))
	for y in range(0, 161, 20): pts.append(Vector2(620.0 - r.next() * 5.0, y))
	for x in range(620, -1, -20): pts.append(Vector2(x, 160.0 - r.next() * 5.0))
	for y in range(160, -1, -20): pts.append(Vector2(r.next() * 5.0, y))
	# the jittered outline crosses itself at the corners: let Clipper resolve it, as a canvas fill does
	for poly in _solid(pts):
		draw_colored_polygon(poly, paper)
		poly.append(poly[0])
		draw_polyline(poly, paper, 1.0, true)             # antialiased cut edge
	_stroke_rect(Rect2(22, 20, 576, 120), 3.0)
	_stroke_rect(Rect2(30, 28, 560, 104), 1.2)
	# canvas textAlign center, textBaseline middle at (310, 84): Chrome's "middle" is the centre of
	# the em box, the font's ascent and descent scaled so together they make one em
	var size := 72
	var a := font.get_ascent(size); var d := font.get_descent(size)
	var base := 84.0 + size * (a - d) / (a + d) * 0.5
	draw_string(font, Vector2(310 - 400, base), title, HORIZONTAL_ALIGNMENT_CENTER, 800, size, ink)

func _stroke_rect(r: Rect2, w: float) -> void:
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	draw_polyline(p, ink, w, true)

## The jittered outline can cross itself at a corner; a canvas fill shrugs that off, Godot's
## triangulator does not. Union it with a rectangle well inside to get a clean outline.
func _solid(p: PackedVector2Array) -> Array:
	var r := Rect2(p[0], Vector2.ZERO)
	for v in p: r = r.expand(v)
	r = r.grow(-8.0)
	var inner := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var out := []
	for poly in Geometry2D.merge_polygons(p, inner):
		if not Geometry2D.is_polygon_clockwise(poly): out.append(poly)
	return out
