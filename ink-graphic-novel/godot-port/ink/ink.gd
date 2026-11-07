extends RefCounted
## Shared drawing for the ink graphic novel page: palette roles, seeded random, Catmull-Rom curves,
## brush strokes, polygon strokes with miter joins, antialiased fills, paper with a multiplied
## grain, and lettering (canvas-style "top" placement, the title face's own small caps).

const ROLE := {
	"ink": Color("#080A10"), "paper": Color("#ECE4CE"),
	"field-1": Color("#1C2A3C"), "field-2": Color("#3E5872"), "field-3": Color("#8EA9C2"),
	"accent": Color("#F4923A"), "signal-alert": Color("#F0607E"), "signal-ok": Color("#8FD3A0"),
}
const GRAIN: Texture2D = preload("res://art/paper-grain.png")
const GRAIN_TILE := 512.0
## Chrome places the serif title face's em box about 1 px higher than the normalised ascent below
## gives (measured against the web frame; the lettering face needs no nudge).
const TITLE_TOP_NUDGE := -1.0

static var LET := _sys(["Comic Neue", "Comic Sans MS", "Chalkboard SE", "Segoe Print"], 700)
static var LET_400 := _sys(["Comic Neue", "Comic Sans MS", "Chalkboard SE", "Segoe Print"], 400)
static var TIT := _small_caps(_sys(["IM Fell English SC", "Georgia", "Times New Roman"], 700))

static func _sys(names: Array, weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
	return f

## The face's own small capitals (OpenType smcp), as CSS font-variant: small-caps uses them.
static func _small_caps(base: Font) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("smcp"): 1}
	return v

static func c(role: String) -> Color:
	return ROLE[role]

# ------------------------------------------------------------------ seeded random (mulberry32)
class Rng:
	var a: int
	func _init(seed: int) -> void:
		a = seed & 0xFFFFFFFF
	static func _imul(x: int, y: int) -> int:
		return ((x & 0xFFFF) * y + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF
	func next() -> float:
		a = (a + 0x6D2B79F5) & 0xFFFFFFFF
		var t := _imul(a ^ (a >> 15), a | 1)
		t = ((t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF) ^ t
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

# ------------------------------------------------------------------ geometry
static func smooth(ctrl: PackedVector2Array, seg := 5, closed := true) -> PackedVector2Array:
	var n := ctrl.size()
	var out := PackedVector2Array()
	var lim := n if closed else n - 1
	for i in lim:
		var p0 := _at(ctrl, i - 1, closed); var p1 := _at(ctrl, i, closed)
		var p2 := _at(ctrl, i + 1, closed); var p3 := _at(ctrl, i + 2, closed)
		for k in seg:
			var t := float(k) / seg; var t2 := t * t; var t3 := t2 * t
			out.append(0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	if not closed:
		out.append(ctrl[n - 1])
	return out

static func _at(ctrl: PackedVector2Array, i: int, closed: bool) -> Vector2:
	var n := ctrl.size()
	return ctrl[posmod(i, n)] if closed else ctrl[clampi(i, 0, n - 1)]

## Rounded rectangle traced like canvas arcTo from the top edge, clockwise.
static func round_rect(x: float, y: float, w: float, h: float, r: float, steps := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [[Vector2(x + w - r, y + r), -PI / 2], [Vector2(x + w - r, y + h - r), 0.0],
		[Vector2(x + r, y + h - r), PI / 2], [Vector2(x + r, y + r), PI]]
	for cr in corners:
		for k in steps + 1:
			var a: float = cr[1] + PI / 2 * k / steps
			pts.append(cr[0] + Vector2(cos(a), sin(a)) * r)
	return pts

static func circle_pts(cx: Vector2, r: float) -> PackedVector2Array:
	var n := clampi(int(r * 3.0), 12, 96)
	var pts := PackedVector2Array()
	for i in n:
		pts.append(cx + Vector2(cos(TAU * i / n), sin(TAU * i / n)) * r)
	return pts

static func rect_pts(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])

# ------------------------------------------------------------------ antialiased fill
## Fills a simple polygon with canvas-like edge antialiasing. The Compatibility renderer ignores
## 2D MSAA, so plain draw_colored_polygon() leaves stair-stepped ink edges; instead the polygon is
## filled shrunk by half a pixel and ringed by a 1 px feather that fades from the colour to
## transparent (-0.5 .. +0.5 px around the true edge). With `tex`, the fill is textured; `pattern`
## maps local points to the texture's pixel space (repeat needs texture_repeat ENABLED on the node).
static func fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, tex: Texture2D = null, pattern := Transform2D.IDENTITY, tile := 512.0) -> void:
	var n := pts.size()
	if n < 3:
		return
	var area := 0.0
	for i in n:
		area += pts[i].cross(pts[(i + 1) % n])
	var sgn := 1.0 if area > 0.0 else -1.0
	var normals := PackedVector2Array()                 # outward edge normals
	for i in n:
		var d := pts[(i + 1) % n] - pts[i]
		normals.append(Vector2(d.y, -d.x).normalized() * sgn)
	var inner := PackedVector2Array(); var outer := PackedVector2Array()
	for i in n:
		var n1 := normals[posmod(i - 1, n)]; var n2 := normals[i]
		var k := 1.0 + n1.dot(n2)
		var m := (n1 + n2) / k if k > 0.25 else (n1 + n2).normalized() * 2.0   # miter offset
		if m.length() > 2.0:
			m = m.normalized() * 2.0
		inner.append(pts[i] - m * 0.5); outer.append(pts[i] + m * 0.5)
	var clear := Color(col, 0.0)
	if Geometry2D.triangulate_polygon(inner).is_empty():
		inner = pts                                     # too thin to shrink: fill the true shape
	if tex == null:
		ci.draw_colored_polygon(inner, col)
	else:
		ci.draw_polygon(inner, PackedColorArray([col]), _uvs(inner, pattern, tile), tex)
	for i in n:
		var j := (i + 1) % n
		var q := PackedVector2Array([inner[i], inner[j], outer[j], outer[i]])
		if not _convex_quad(q):
			continue
		var cs := PackedColorArray([col, col, clear, clear])
		if tex == null:
			ci.draw_polygon(q, cs)
		else:
			ci.draw_polygon(q, cs, _uvs(q, pattern, tile), tex)

static func _convex_quad(q: PackedVector2Array) -> bool:
	var s := 0
	for i in 4:
		var c := (q[(i + 1) % 4] - q[i]).cross(q[(i + 2) % 4] - q[(i + 1) % 4])
		if absf(c) < 1e-9:
			return false
		s += 1 if c > 0.0 else -1
	return absi(s) == 4

static func _uvs(pts: PackedVector2Array, pattern: Transform2D, tile: float) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append((pattern * p) / tile)
	return uvs

static func disc(ci: CanvasItem, cx: Vector2, r: float, col: Color) -> void:
	fill(ci, circle_pts(cx, r), col)

static func rect(ci: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	fill(ci, rect_pts(x, y, w, h), col)

## One stroke segment from a to b, half-width wa at a and wb at b along the unit normal nn. Only
## its long sides are feathered: the ends meet the next segment or a round dab, and feathering
## them would leave faint beads at every joint.
static func band(ci: CanvasItem, a: Vector2, b: Vector2, nn: Vector2, wa: float, wb: float, col: Color) -> void:
	var clear := Color(col, 0.0)
	var ia := maxf(wa - 0.5, 0.0); var ib := maxf(wb - 0.5, 0.0)
	if ia > 0.0 or ib > 0.0:
		ci.draw_colored_polygon(PackedVector2Array([a + nn * ia, b + nn * ib, b - nn * ib, a - nn * ia]), col)
	for s in [1.0, -1.0]:
		var q := PackedVector2Array([a + nn * s * ia, b + nn * s * ib, b + nn * s * (wb + 0.5), a + nn * s * (wa + 0.5)])
		ci.draw_polygon(q, PackedColorArray([col, col, clear, clear]))

# ------------------------------------------------------------------ ink marks
## Variable-width stroke: one quad per segment and a dab per point (the recipe's brush contour).
static func stroke_var(ci: CanvasItem, pts: PackedVector2Array, ws: PackedFloat32Array, closed: bool, col: Color) -> void:
	var n := pts.size()
	for i in (n if closed else n - 1):
		var a := pts[i]; var b := pts[(i + 1) % n]
		var d := b - a; var L := maxf(d.length(), 1e-6)
		var nn := Vector2(-d.y, d.x) / L
		var wa := ws[i] / 2.0; var wb := ws[(i + 1) % n] / 2.0
		band(ci, a, b, nn, wa, wb, col)
	for i in n:
		if ws[i] > 0.6:
			disc(ci, pts[i], ws[i] / 2.0, col)

## An open brush stroke through control points, tapered at both ends.
static func brush(ci: CanvasItem, ctrl: PackedVector2Array, w: float, col := Color("#080A10")) -> void:
	var fine := smooth(ctrl, 6, false)
	var n := fine.size()
	var ws := PackedFloat32Array()
	for i in n:
		ws.append(w * pow(sin(PI * (0.1 + 0.8 * i / float(n - 1))), 0.5))
	stroke_var(ci, fine, ws, false, col)

## Canvas-style stroke of a polyline (centred on the path, miter joins with limit 10).
static func stroke_poly(ci: CanvasItem, pts: PackedVector2Array, closed: bool, w: float, col: Color) -> void:
	var n := pts.size()
	var hw := w / 2.0
	var segs := n if closed else n - 1
	for i in segs:
		var a := pts[i]; var b := pts[(i + 1) % n]
		var d := b - a
		if d.length() < 1e-6:
			continue
		var nn := Vector2(-d.y, d.x).normalized() * hw
		band(ci, a, b, nn / hw, hw, hw, col)
	for i in n:
		if not closed and (i == 0 or i == n - 1):
			continue
		var p := pts[i]
		var d1 := (p - pts[posmod(i - 1, n)]).normalized()
		var d2 := (pts[(i + 1) % n] - p).normalized()
		if d1 == Vector2.ZERO or d2 == Vector2.ZERO:
			continue
		var turn := d1.cross(d2)
		if absf(turn) < 1e-3:
			continue
		var s := -1.0 if turn > 0.0 else 1.0           # outer side of the corner
		var n1 := Vector2(-d1.y, d1.x) * s * hw
		var n2 := Vector2(-d2.y, d2.x) * s * hw
		var bis := (n1 + n2).normalized()
		var cos_half := bis.dot(n1.normalized())
		if cos_half > 1e-3 and 1.0 / cos_half <= 10.0:
			fill(ci, PackedVector2Array([p, p + n1, p + bis * hw / cos_half, p + n2]), col)
		else:
			fill(ci, PackedVector2Array([p, p + n1, p + n2]), col)

# ------------------------------------------------------------------ paper
## Paper with the grain multiplied over it: the polygon textured with the grain and modulated by
## the paper colour is exactly paper x grain (the canvas 'multiply' over opaque paper). `pattern`
## maps local points into page space, because a canvas pattern repeats from the origin of the
## transform in force when it is filled. The node needs texture_repeat ENABLED.
static func paper_poly(ci: CanvasItem, pts: PackedVector2Array, pattern := Transform2D.IDENTITY, col := Color("#ECE4CE")) -> void:
	fill(ci, pts, col, GRAIN, pattern, GRAIN_TILE)

# ------------------------------------------------------------------ lettering
static func font_for(kind: String) -> Font:
	return TIT if kind == "tit" else LET_400 if kind == "let400" else LET

## Width of a string as canvas measureText gives it: the sum of the shaped glyph advances.
## (Font.get_string_size() rounds the width up to a whole pixel, which drifts layouts that chain
## measured widths, such as a value, its unit and the next icon.)
static func text_w(text: String, fs: int, kind := "let") -> float:
	var ts := TextServerManager.get_primary_interface()
	var f := font_for(kind)
	var rid := ts.create_shaped_text()
	ts.shaped_text_add_string(rid, text, f.get_rids(), fs, f.get_opentype_features())
	var w := 0.0
	for g in ts.shaped_text_get_glyphs(rid):
		w += g["advance"]
	ts.free_rid(rid)
	return w

## Canvas textBaseline offsets: 'top' is the em box top (ascent normalised to one em).
static func top_offset(fs: int, kind := "let") -> float:
	var f := font_for(kind)
	var a := f.get_ascent(fs); var d := f.get_descent(fs)
	return fs * a / (a + d) + (TITLE_TOP_NUDGE if kind == "tit" else 0.0)

## Draws text with its em box top at y (canvas textBaseline = 'top').
static func text_top(ci: CanvasItem, x: float, y: float, text: String, fs: int, col: Color, kind := "let") -> void:
	text_base(ci, x, y + top_offset(fs, kind), text, fs, col, kind)

## Draws text on its alphabetic baseline at y.
static func text_base(ci: CanvasItem, x: float, y: float, text: String, fs: int, col: Color, kind := "let") -> void:
	ci.draw_string(font_for(kind), Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## Canvas strokeText with lineWidth `line_w`. An outline_size of N grows each glyph edge by N/4 px
## (measured), while a canvas stroke grows it by lineWidth/2: so N = 2 x lineWidth.
static func text_stroke_base(ci: CanvasItem, x: float, y: float, text: String, fs: int, line_w: float, col: Color, kind := "let") -> void:
	ci.draw_string_outline(font_for(kind), Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(line_w * 2.0), col)

## Word wrap by measured width, splitting a word that is wider than the box (canvas demo's wrap()).
static func wrap(text: String, fs: int, max_w: float, kind := "let") -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var cur := ""
		for word in para.split(" ", false):
			while text_w(word, fs, kind) > max_w and word.length() > 1:
				var k := word.length() - 1
				while k > 1 and text_w(word.substr(0, k), fs, kind) > max_w:
					k -= 1
				if cur != "":
					out.append(cur); cur = ""
				out.append(word.substr(0, k)); word = word.substr(k)
			var try_s := cur + " " + word if cur != "" else word
			if cur == "" or text_w(try_s, fs, kind) <= max_w:
				cur = try_s
			else:
				out.append(cur); cur = word
		out.append(cur)
	return out
