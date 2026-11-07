extends Control
## The status marks in the bottom bar: each an ink icon (drawn in code, never generated) with its
## number lettered beside it, big value and small unit. Stats sit 26 px apart.
const Ink = preload("res://ink/ink.gd")
## Each entry: {"icon": "wind" | "battery", "value": "70", "unit": "km/h", "charge": 0.4}
@export var stats: Array[Dictionary] = []
@export var gap := 26.0

func _draw() -> void:
	var x := 0.0
	for s in stats:
		x += _stat(x, 0.0, s) + gap

func _stat(x: float, y: float, s: Dictionary) -> float:
	var iw := 44.0
	match s.get("icon", ""):
		"wind":
			wind_icon(x, y + 2); iw = 38.0
		"battery":
			battery_icon(x, y + 6, s.get("charge", 1.0)); iw = 60.0
	var ink := Ink.c("ink")
	var value: String = s.get("value", ""); var unit: String = s.get("unit", "")
	Ink.text_base(self, x + iw + 8, y + 31, value, 28, ink)
	var vw := Ink.text_w(value, 28)
	Ink.text_base(self, x + iw + 12 + vw, y + 31, unit, 16, ink)
	var uw := Ink.text_w(unit, 16)
	return iw + 12 + vw + (uw + 4 if unit != "" else 0.0)

func _q(x: float, y: float, s: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(x + p[0] * s, y + p[1] * s))
	return out

## Wind: three streamlines, the top and bottom ones curling back.
func wind_icon(x: float, y: float, s := 1.0) -> void:
	Ink.brush(self, _q(x, y, s, [[0, 8], [20, 8], [30, 6], [33, 0], [29, -4], [24, -2]]), 4.5 * s)
	Ink.brush(self, _q(x, y, s, [[4, 17], [36, 17]]), 4.5 * s)
	Ink.brush(self, _q(x, y, s, [[0, 26], [24, 26], [33, 28], [35, 34], [30, 37], [26, 34]]), 4.5 * s)

## The classic battery: ink outline and terminal, charge cells inside (signal-ok, or signal-alert
## at 20 % and below), each cell edged in ink.
func battery_icon(x: float, y: float, frac: float, s := 1.0, cells := 5) -> void:
	var ink := Ink.c("ink")
	var w := 52 * s; var h := 26 * s
	var n := roundi(frac * cells)
	var cw := (w - 8 * s - (cells - 1) * 3 * s) / cells
	Ink.rect(self, x + w, y + h * 0.3, 5 * s, h * 0.4, ink)
	_frame(Rect2(x, y, w, h), 3 * s, ink)
	var fill := Ink.c("signal-alert" if frac <= 0.2 else "signal-ok")
	for i in n:
		var cx := x + 4 * s + i * (cw + 3 * s)
		Ink.rect(self, cx, y + 4 * s, cw, h - 8 * s, fill)
		_frame(Rect2(cx, y + 4 * s, cw, h - 8 * s), 1.5, ink)

## A stroke of width lw lying inside rect r (canvas strokeRect inset by half the width).
func _frame(r: Rect2, lw: float, col: Color) -> void:
	Ink.rect(self, r.position.x, r.position.y, r.size.x, lw, col)
	Ink.rect(self, r.position.x, r.end.y - lw, r.size.x, lw, col)
	Ink.rect(self, r.position.x, r.position.y + lw, lw, r.size.y - 2 * lw, col)
	Ink.rect(self, r.end.x - lw, r.position.y + lw, lw, r.size.y - 2 * lw, col)
