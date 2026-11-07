extends Control
## A paper slip pinned to the frame: torn edge, dark card edge as a hard drop, a soft shadow,
## a tack, then its lines. This one is the basket (an inventory and two meters of printed pips).
## Layout follows the demo's CSS box model at 720p: 172 wide, padding 9/12/11, 16 px text at
## line-height 1.3, 22 px glyphs, rows 26 tall.

const Rng := preload("res://mulberry32.gd")
const W := 172.0
const H := 241.0
var ink := Color("#2B2118")
var paper := Color("#F3EAD2")
var card := Color("#5A3E2B")
var tear_seed := 5

var regular: Font
var bold_onum: Font      # counts: bold, old-style figures
var bold_smcp: Font      # heading: bold small caps
var icons := {}          # name -> Texture2D, rasterised from the same SVG symbols as the page

const ITEMS := [["loaf", "Rye loaf", "2"], ["honey", "Honey", "1"], ["specs", "Spectacles", "1"],
	["oil", "Lamp oil", "½"], ["wool", "Grey wool", "1"]]
const HEART := 7    # of 10
const SUN := 3      # of 5

const SVG := {
	"loaf": '<path d="M3 15c0-6 4-9 9-9s9 3 9 9v3H3z" fill="#DDBE68" stroke="currentColor" stroke-width="1.6"/><path d="M8 9l-1 5M12 8v6M16 9l1 5" stroke="currentColor" stroke-width="1.4" fill="none"/>',
	"honey": '<path d="M6 9h12l-1 11H7z" fill="#DDBE68" stroke="currentColor" stroke-width="1.6"/><path d="M5 5h14v4H5z" fill="#C8574A" stroke="currentColor" stroke-width="1.6"/>',
	"specs": '<circle cx="7" cy="14" r="4" fill="none" stroke="currentColor" stroke-width="1.8"/><circle cx="17" cy="14" r="4" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M11 14h2M3 13l-1-4M21 13l1-4" stroke="currentColor" stroke-width="1.6" fill="none"/>',
	"oil": '<path d="M9 3h6v4l3 3v11H6V10l3-3z" fill="#A9B2B8" stroke="currentColor" stroke-width="1.6"/><path d="M6 15h12v6H6z" fill="#B08355" stroke="currentColor" stroke-width="1.6"/>',
	"wool": '<circle cx="12" cy="12" r="8" fill="#9A968F" stroke="currentColor" stroke-width="1.6"/><path d="M6 8c4 2 8 6 9 11M9 5c3 3 8 5 10 10M5 14c3 0 6 3 7 6" stroke="currentColor" stroke-width="1.2" fill="none"/>',
	"heart": '<path d="M12 21C5 15 2 12 2 8a5 5 0 0 1 10-1 5 5 0 0 1 10 1c0 4-3 7-10 13z" fill="#C8574A" stroke="currentColor" stroke-width="1.6"/>',
	"sun": '<circle cx="12" cy="12" r="5" fill="#DDBE68" stroke="currentColor" stroke-width="1.6"/><path d="M12 1v4M12 19v4M1 12h4M19 12h4M4 4l3 3M17 17l3 3M20 4l-3 3M7 17l-3 3" stroke="currentColor" stroke-width="1.6"/>',
}

var outline := PackedVector2Array()

func _ready() -> void:
	size = Vector2(W, H)
	for k in SVG:
		var src: String = '<svg width="24" height="24" viewBox="0 0 24 24">%s</svg>' % SVG[k].replace("currentColor", "#" + ink.to_html(false))
		var img := Image.new()
		img.load_svg_from_string(src, 22.0 / 24.0)
		icons[k] = ImageTexture.create_from_image(img)
	# the torn edge: the CSS clip-path polygon, jitter 0..2.4 px rounded to 0.1, every 12 px
	var r := Rng.new(tear_seed)
	var j := func() -> float: return snappedf(r.next() * 2.4, 0.1)
	var x := 0.0
	while x < W: outline.append(Vector2(x, j.call())); x += 12.0
	var y := 0.0
	while y < H: outline.append(Vector2(W - j.call(), y)); y += 12.0
	x = W
	while x > 0.0: outline.append(Vector2(x, H - j.call())); x -= 12.0
	y = H
	while y > 0.0: outline.append(Vector2(j.call(), y)); y -= 12.0
	# the soft shadow (drop-shadow 5px 8px 6px, 35% black) of the slip plus its 2,3 card drop
	var sh := ColorRect.new()
	sh.position = Vector2(-20, -20); sh.size = Vector2(W + 50, H + 55)
	sh.show_behind_parent = true
	var m := ShaderMaterial.new(); m.shader = preload("res://boxshadow.gdshader")
	m.set_shader_parameter("box", Vector4(5 + 20, 8 + 20, W + 2 + 5 + 20, H + 3 + 8 + 20))
	m.set_shader_parameter("sigma", 3.0)
	sh.material = m
	add_child(sh)
	queue_redraw()

## CSS line box: half-leading above the ascent. Chrome on Windows takes ascent and descent from
## the font's OS/2 win metrics (Palatino Linotype: 2150 and 613 per 2048 em); Godot's own
## get_ascent() uses the smaller hhea values and would set every line about 3 px high.
const WIN_ASCENT := 2150.0 / 2048.0
const WIN_DESCENT := 613.0 / 2048.0
func _baseline(_f: Font, px: int, top: float, line_h: float) -> float:
	var a := WIN_ASCENT * px; var d := WIN_DESCENT * px
	return top + (line_h - (a + d)) * 0.5 + a

func _draw() -> void:
	var tack := Vector2(86, 4)
	# hard card-coloured drop of the whole pinned slip, tack included
	for poly in _solid(_moved(outline, Vector2(2, 3))): draw_colored_polygon(poly, card)
	draw_circle(tack + Vector2(2, 3), 8.0, card, true, -1.0, true)
	# the paper
	for poly in _solid(outline):
		draw_colored_polygon(poly, paper)
		poly.append(poly[0])
		draw_polyline(poly, paper, 1.0, true)
	# heading
	draw_string(bold_smcp, Vector2(12, _baseline(bold_smcp, 20, 9, 22)), "Basket", HORIZONTAL_ALIGNMENT_CENTER, 148, 20, ink)
	# inventory rows
	for i in ITEMS.size():
		var top := 37.0 + 26.0 * i + 2.0
		draw_texture(icons[ITEMS[i][0]], Vector2(12, top))
		draw_string(regular, Vector2(42, _baseline(regular, 16, top + 0.6, 20.8)), ITEMS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
		draw_string(bold_onum, Vector2(12, _baseline(bold_onum, 16, top + 0.6, 20.8)), ITEMS[i][2], HORIZONTAL_ALIGNMENT_RIGHT, 148, 16, ink)
	# rule
	draw_rect(Rect2(12, 174, 148, 1), ink)
	# meters: courage as bars, daylight as suns
	draw_texture(icons["heart"], Vector2(12, 182))
	for i in 10:
		var rc := Rect2(41 + 12 * i, 185, 9, 16)
		draw_rect(rc, ink)
		if i >= HEART: draw_rect(rc.grow(-1), paper)
	draw_texture(icons["sun"], Vector2(12, 208))
	for i in 5:
		var c := Vector2(41 + 18 * i + 7.5, 208 + 11)
		draw_circle(c, 7.5, ink, true, -1.0, true)
		draw_circle(c, 6.5, Color("#DDBE68") if i < SUN else paper, true, -1.0, true)
	# tack
	draw_circle(tack, 8.0, ink, true, -1.0, true)
	draw_circle(tack, 6.0, card, true, -1.0, true)

func _moved(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var o := PackedVector2Array()
	for v in p: o.append(v + d)
	return o

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
