class_name SpeechBubble
extends PanelContainer
## A paper panel whose tail points out of its left side at the speaker. The tail is drawn here,
## after the panel's StyleBox, centred on the side whatever height the text gives the panel, so it
## always stays inside the panel's height.

@export var tail_length := 46.0       # from the panel's inner (padding) edge to the tip
@export var tail_half_width := 13.0   # half the tail's opening where it joins the panel
@export var outline := 4.0
var paper := Color.WHITE
var ink := Color.BLACK

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var b := outline
	var cy := size.y / 2.0
	var tip := Vector2(b - tail_length, cy)
	var top := Vector2(b + 4.0, cy - tail_half_width)
	var bot := Vector2(b + 4.0, cy + tail_half_width)
	draw_colored_polygon(PackedVector2Array([top, tip, bot]), paper)   # paints over the border between the strokes
	_stroke(top, tip, bot)

## Two straight strokes meeting in a mitred point (like SVG stroke-linejoin: miter), butt ends.
func _stroke(a: Vector2, m: Vector2, c: Vector2) -> void:
	var h := outline / 2.0
	var n1 := (m - a).normalized().orthogonal()
	var n2 := (c - m).normalized().orthogonal()
	var bis := (n1 + n2).normalized()
	var miter := bis * h / bis.dot(n1)
	draw_colored_polygon(PackedVector2Array([a + n1 * h, m + miter, c + n2 * h, c - n2 * h, m - miter, a - n1 * h]), ink)
