# Godot 4 snippets

<!-- matched-web-frame: 539def13e82c -->

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.jpg` rebuilds
`demo.html?frame=key-scene` from `Control` and `Node2D` scenes, the entry's own generated images and
the code on this page. Measured against the web frame: mean difference 3.1 / 2.4 / 3.8 per 255
(R/G/B) for the lossless render (1.7 / 1.6 / 1.7 for the saved JPEG); 15% of pixels differ by more
than 8 and 1.5% by more than 24. Composition, panels, art placement, snow, captions, balloon, sound
word, question, icons, slips, note, palette and paper grain are the same, and both draw the same
bundled font files. What is left is rasterisation: the browser's text is a little darker and
crisper than Godot's greyscale glyphs (up to about 13/255 on lettered tiles), the sound word's
outline is FreeType's stroke rather than the canvas `strokeText` (13/255 on that tile), edge
resampling on the art (about 3/255), and the web frame's JPEG noise. **Forward+** renders the same frame (0.3 / 0.2 / 0.2 per 255 from the
Compatibility render) with the same code.

The whole project that rendered the frame, including the scene that rebuilds the web demo exactly,
is in this entry's `godot-port/` on the catalog site.

## Putting it together

Every picture is a generated image drawn by a node; every word, number, icon, balloon, slip and
note is drawn live by a small component script; nothing is lettered into the art. One `Control`
holds the page at the design size; children of a panel are placed relative to that panel:

```text
Page (Control 1280×720)
├─ Paper (ColorRect, paper role)
├─ Grain (TextureRect: the grain tiled, CanvasItemMaterial blend Multiply)
├─ Panel … (ink_panel.gd: clips its children, 5 px ink border drawn last)
│  ├─ Backdrop (backdrop.gd: a background image cropped around a focus point)
│  ├─ figures (figure.gd: cutouts standing on their bottom centre)
│  ├─ weather (snowfall.gd: paper or ink dots)
│  └─ captions (caption.gd), a balloon (balloon.gd), a sound word (sound_word.gd)
├─ a question (title_label.gd), status marks (status_bar.gd)
├─ answers (answer_row.gd → answer_slip.gd per answer)
└─ a pinned note (pinned_note.gd)
```

Draw order is the tree order: paper, grain, then each panel's backdrop, figures, weather and
lettering, then the panel border on top. A figure keeps its proportions whatever the art's pixel
size (size it by a height or a width); backdrops crop like CSS `object-fit: cover`. Weather is
posed at a time `t`; set `animate = true` to let it move (it redraws only that node). Keys or the
arrows only flip `focus` on the slips; a slip re-places itself (lift, shadow, edge, underline).

**Project settings:**

```ini
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
anti_aliasing/quality/msaa_2d=2          ; used by Forward+/Mobile; Compatibility ignores it
environment/defaults/default_clear_color=Color(0.92549, 0.894118, 0.807843, 1)   ; paper
```

**Import settings.** The generated PNGs import as Godot's defaults for 2D: lossless, no mipmaps,
and the canvas default filter Linear. Mipmapped filtering was measured worse (blurrier than the
browser's `drawImage`, about twice the difference on every figure), so leave mipmaps off. The paper
grain must repeat: every node that draws paper sets `texture_repeat = ENABLED` (the scripts do it in
`_ready()`), and the page's `Grain` node sets it in the scene.

**Fonts.** The port loads the same font files the web demo bundles (`assets/fonts/`, all OFL) as
`FontFile`s from `res://fonts/`: Comic Neue Bold for captions and slips, Comic Neue Regular for the
note, Alegreya Bold for titles. Keep `hinting = None`, greyscale antialiasing and quarter-pixel
subpixel positioning (`_face()` below). The title face's small capitals are its own OpenType `smcp`
glyphs (`FontVariation` below); synthesised small caps are narrower and lighter.

## The paper grain and its multiply

A tileable greyscale grain (0.86–0.97) is multiplied over every paper surface: the page, captions,
slips and the note.

- **The page**: a `TextureRect` of the grain, `stretch_mode = Tile`, with a `CanvasItemMaterial`
  whose `blend_mode = Multiply`, over a `ColorRect` in the paper role. The same node multiplies
  the grain over anything below it.
- **Paper shapes** (`Ink.paper_poly()`): the shape is drawn as a polygon textured with the grain
  and modulated by the paper colour, which is exactly paper × grain without a second node. Captions
  pass their global transform as the pattern (the grain lines up with the page's), while rotated
  slips and the note use their own local space (the grain turns with the scrap of paper).

No other blend mode is used: inks, fills and art are drawn normally.

## Shared drawing: `ink/ink.gd`

Palette roles, a small seeded random (the port's copy of the demo's generator; any seeded generator
does for a game), Catmull-Rom curves, antialiased fills, brush strokes, polyline strokes with miter
joins, paper, and lettering placed by the em box top. Each component preloads it as `Ink`.

```gdscript
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
## Chrome places each face's em box a little lower than the normalised ascent below gives
## (measured against the web frame, in em): the lettering by 0.04, the title by 0.02.
const LET_TOP_NUDGE := 0.04
const TIT_TOP_NUDGE := 0.02

static var LET := _face("res://fonts/ComicNeue-Bold.woff")
static var LET_400 := _face("res://fonts/ComicNeue-Regular.woff")
static var TIT := _small_caps(_face("res://fonts/Alegreya-Bold.woff"))

## The same font files the web demo bundles, drawn like the browser draws them.
static func _face(path: String) -> FontFile:
	var f: FontFile = load(path)
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
	return fs * (a / (a + d) + (TIT_TOP_NUDGE if kind == "tit" else LET_TOP_NUDGE))

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
```

## Panels and art

```gdscript
# ink/ink_panel.gd
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
```

```gdscript
# ink/backdrop.gd
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
```

```gdscript
# ink/figure.gd
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
```

A line between two figures (a rope, a lead, a cable) is `Ink.brush()` through three points taken
from their `rect()`s.

```gdscript
# ink/snowfall.gd
extends Node2D
## Falling snow: paper dots wrapping inside `area`. `t` is the time in seconds (the key scene poses
## it at 0.4). Seeded so a frame is repeatable.
const Ink = preload("res://ink/ink.gd")
@export var area := Vector2(840, 520)
@export var count := 90
@export var seed := 9
@export var t := 0.4
@export var animate := false

func _process(delta: float) -> void:
	if animate:
		t += delta
		queue_redraw()

func _draw() -> void:
	var r := Ink.Rng.new(seed)
	var paper := Ink.c("paper")
	for i in count:
		var x := fmod(r.next() * area.x + t * (6.0 + r.next() * 6.0), area.x)
		var y := fmod(r.next() * area.y + t * (14.0 + r.next() * 10.0), area.y)
		var s := 1.5 + r.next() * 2.5
		Ink.disc(self, Vector2(x, y), s, paper)
```

## Lettering: captions, balloon, sound word, question

```gdscript
# ink/caption.gd
extends Control
## Narration caption: lettered paper box, 3 px ink border, hard 5 px ink offset shadow. The box
## grows by whole lines (measured wrapping; nothing is ever cut). dark = ink box, paper letters.
const Ink = preload("res://ink/ink.gd")
@export_multiline var text := "":
	set(v): text = v; _layout()
@export var box_width := 300.0:
	set(v): box_width = v; _layout()
@export var font_size := 20:
	set(v): font_size = v; _layout()
@export var pad := 10.0
@export var title := false      # small-caps title face instead of capitals lettering
@export var lower := false
@export var dark := false
var lines := PackedStringArray()

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout()

func _kind() -> String: return "tit" if title else "let"
func _lh() -> int: return roundi(font_size * 1.22)

func _layout() -> void:
	var t := text if (title or lower) else text.to_upper()
	lines = Ink.wrap(t, font_size, box_width - pad * 2, _kind())
	size = Vector2(box_width, lines.size() * _lh() + pad * 2)
	queue_redraw()

func _draw() -> void:
	var w := size.x; var h := size.y
	var ink := Ink.c("ink"); var paper := Ink.c("paper")
	draw_rect(Rect2(5, 5, w, h), ink)
	if dark:
		draw_rect(Rect2(0, 0, w, h), ink)
	else:
		Ink.paper_poly(self, Ink.rect_pts(0, 0, w, h), get_global_transform())
	var b := paper if dark else ink
	draw_rect(Rect2(0, 0, w, 3), b); draw_rect(Rect2(0, h - 3, w, 3), b)
	draw_rect(Rect2(0, 0, 3, h), b); draw_rect(Rect2(w - 3, 0, 3, h), b)
	var lh := _lh()
	for i in lines.size():
		Ink.text_top(self, pad, pad + i * lh + (lh - font_size) / 2.0, lines[i], font_size, paper if dark else ink, _kind())
```

```gdscript
# ink/balloon.gd
extends Control
## Speech balloon: paper round-rect with a 3 px ink stroke and a tail to the speaker (`tail`, in the
## parent's coordinates). Lines centred, capitals lettering.
const Ink = preload("res://ink/ink.gd")
@export_multiline var text := ""
@export var box_width := 228.0
@export var font_size := 18
@export var tail := Vector2.ZERO
var lines := PackedStringArray()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines = Ink.wrap(text.to_upper(), font_size, box_width - 24)
	size = Vector2(box_width, lines.size() * _lh() + 18)

func _lh() -> int: return roundi(font_size * 1.22)

func _draw() -> void:
	var w := size.x; var h := size.y
	var ink := Ink.c("ink"); var paper := Ink.c("paper")
	var tip := tail - position
	var tri := PackedVector2Array([Vector2(w * 0.62, h - 2), tip, Vector2(w * 0.78, h - 2)])
	Ink.fill(self, tri, paper)
	Ink.stroke_poly(self, tri, true, 3.0, ink)
	var rr := Ink.round_rect(0, 0, w, h, h / 2.4)
	Ink.fill(self, rr, paper)
	Ink.stroke_poly(self, rr, true, 3.0, ink)
	Ink.rect(self, w * 0.62 + 3, h - 6, w * 0.16 - 6, 6, paper)     # join the tail
	var lh := _lh()
	for i in lines.size():
		var lw := Ink.text_w(lines[i], font_size)
		Ink.text_top(self, (w - lw) / 2, 9 + i * lh + (lh - font_size) / 2.0, lines[i], font_size, ink)
```

```gdscript
# ink/sound_word.gd
extends Node2D
## A sound word: big small-caps serif letters, ink copy offset 6 px, an 8 px ink stroke under a paper
## fill. The node's position is the right end of the word's top line; it rotates by `angle`.
const Ink = preload("res://ink/ink.gd")
@export var text := ""          # your sound word
@export var font_size := 44
@export var angle := -0.08
@export var outline := 8

func _draw() -> void:
	var w := Ink.text_w(text, font_size, "tit")
	draw_set_transform_matrix(Transform2D(0.0, Vector2(-w, 0)) * Transform2D(angle, Vector2.ZERO))
	var base := Ink.top_offset(font_size, "tit")
	Ink.text_base(self, 6, 6 + base, text, font_size, Ink.c("ink"), "tit")
	Ink.text_stroke_base(self, 0, base, text, font_size, outline, Ink.c("ink"), "tit")
	Ink.text_base(self, 0, base, text, font_size, Ink.c("paper"), "tit")
```

```gdscript
# ink/title_label.gd
extends Control
## A bare question: small-caps title lettering straight on the page, no box.
const Ink = preload("res://ink/ink.gd")
@export var text := ""
@export var font_size := 30

func _draw() -> void:
	Ink.text_top(self, 0, 0, text, font_size, Ink.c("ink"), "tit")
```

## The bottom bar: icons, slips, note

```gdscript
# ink/status_bar.gd
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
```

```gdscript
# ink/answer_slip.gd
extends Node2D
## An answer as a torn scrap of paper: its key in an ink disc, the answer in capitals. The focused
## slip is lifted 7 px with a 10 px shadow, a 3 px edge and a brush underline; an unavailable one
## (off) has no shadow, a field-3 edge and its reason below. Place the node at the slip's top-left
## as laid out; at runtime it moves to the slip's centre and rotates about it.
const Ink = preload("res://ink/ink.gd")
const PAD_L := 46.0
@export_multiline var text := ""
@export var key := "1"
@export var slip_width := 262.0
@export var font_size := 20
@export var focus := false:
	set(v): focus = v; if is_inside_tree(): _place()
@export var off := false
@export var reason := ""
@export var angle := 0.0
@export var seed := 1
var min_height := 0.0
var _origin := Vector2.ZERO    # the layout position (top-left before lift and rotation)

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_origin = position
	_place()

func _lh() -> int: return roundi(font_size * 1.2)
func _small() -> int: return maxi(16, font_size - 4)
func _lines() -> PackedStringArray: return Ink.wrap(text.to_upper(), font_size, slip_width - PAD_L - 14)
func _reason() -> PackedStringArray:
	return Ink.wrap(reason, _small(), slip_width - PAD_L - 14, "let400") if reason != "" else PackedStringArray()

func measure() -> float:
	return maxf(min_height, _lines().size() * _lh() + _reason().size() * roundi(_small() * 1.2) + 26)

func set_min_height(h: float) -> void:
	min_height = h
	_place()

func _place() -> void:
	var h := measure()
	var lift := 7.0 if focus else 0.0
	position = _origin + Vector2(slip_width / 2, h / 2 - lift)
	rotation = angle
	queue_redraw()

## A torn scrap: straight-ish long edges, ragged short edges with fine fibres.
static func torn_rect(w: float, h: float, seed_: int) -> PackedVector2Array:
	var r := Ink.Rng.new(seed_)
	var pts := PackedVector2Array()
	var x := 0.0
	while x < w:
		pts.append(Vector2(x, (r.next() - 0.5) * 2)); x += 18
	var y := 0.0
	while y < h:
		pts.append(Vector2(w - 2 + (r.next() - 0.5) * 3 + sin(y * 0.45) * 1.2, y)); y += 3
	x = w
	while x > 0:
		pts.append(Vector2(x, h + (r.next() - 0.5) * 2)); x -= 18
	y = h
	while y > 0:
		pts.append(Vector2(2 + (r.next() - 0.5) * 3 + sin(y * 0.5) * 1.2, y)); y -= 3
	return pts

func _draw() -> void:
	var w := slip_width; var h := measure()
	var ink := Ink.c("ink"); var paper := Ink.c("paper")
	draw_set_transform(Vector2(-w / 2, -h / 2))
	var pts := torn_rect(w, h, seed)
	var sh := 0.0 if off else (10.0 if focus else 4.0)
	if sh > 0.0:
		var moved := PackedVector2Array()
		for p in pts:
			moved.append(p + Vector2(sh, sh))
		Ink.fill(self, moved, ink)
	Ink.paper_poly(self, pts)                    # the grain pattern in the slip's own (rotated) space
	Ink.stroke_poly(self, pts, true, 3.0 if focus else 2.0, Ink.c("field-3") if off else ink)
	var lh := _lh()
	Ink.disc(self, Vector2(24, 13 + lh / 2.0), 14, Ink.c("field-3") if off else ink)
	var kw := Ink.text_w(key, 18)
	Ink.text_base(self, 24 - kw / 2, 14 + lh / 2.0 + Ink.top_offset(18) - 9.0, key, 18, paper)
	var lines := _lines()
	for i in lines.size():
		Ink.text_top(self, PAD_L, 13 + i * lh + (lh - font_size) / 2.0, lines[i], font_size, Ink.c("field-2") if off else ink)
	var rs := _reason()
	for i in rs.size():
		Ink.text_top(self, PAD_L, 13 + lines.size() * lh + 2 + i * roundi(_small() * 1.2), rs[i], _small(), ink, "let400")
	if focus:
		Ink.brush(self, PackedVector2Array([Vector2(PAD_L, h - 9), Vector2(PAD_L + (w - PAD_L) * 0.45, h - 11), Vector2(w - 20, h - 9)]), 3.5, ink)
```

```gdscript
# ink/answer_row.gd
extends Node2D
## Lays the answer slips out at one common height (the tallest slip's).
func _ready() -> void:
	var h := 0.0
	for s in get_children():
		h = maxf(h, s.measure())
	for s in get_children():
		s.set_min_height(h)
```

```gdscript
# ink/pinned_note.gd
extends Node2D
## A handwritten note on ruled paper, pinned at an angle (the node rotates about the note's top-left).
const Ink = preload("res://ink/ink.gd")
@export_multiline var text := ""
@export var note_width := 364.0
@export var font_size := 20

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func _draw() -> void:
	var w := note_width
	var lh := roundi(font_size * 1.3)
	var lines := Ink.wrap(text, font_size, w - 28, "let400")
	var h := lines.size() * lh + 38.0                   # 24 px top margin holds the pin
	var ink := Ink.c("ink")
	Ink.rect(self, 4, 4, w, h, ink)
	Ink.paper_poly(self, Ink.rect_pts(0, 0, w, h))
	for i in lines.size():
		Ink.rect(self, 10, 24 + (i + 1) * lh - 3, w - 20, 2, Ink.c("field-3"))
	for i in lines.size():
		Ink.text_top(self, 14, 24 + i * lh + (lh - font_size) / 2.0 - 2, lines[i], font_size, ink, "let400")
	Ink.disc(self, Vector2(w - 22, 10), 6, ink)
```

## What Godot needed (measured in 4.7.1)

From `godot-compatibility.md` (copied beside this file):

- **18 (no 2D MSAA):** `Ink.fill()` and `Ink.band()` feather by hand. Stroke segments feather only
  their long sides, or the joints show faint beads; dabs use the same fill rather than
  `draw_circle(..., antialiased = true)`, so a dab and the segments beside it get the same edge.
- **24 (rounded widths):** `Ink.text_w()` sums the shaped glyph advances, so a value, its unit and
  the next icon don't drift.
- **22 (failed triangulation):** the tapered ends of a stroke and the fibres of a torn edge.
  `Ink.fill()` falls back to the true shape when the shrunk one won't triangulate and skips
  feather quads that fold over.

Particular to this look:

1. **Text placed by its em box top** (canvas `textBaseline = 'top'`) is the ascent normalised to one
   em: `fs × ascent / (ascent + descent)`, plus a small per-face nudge against the browser
   (lettering 0.04 em, titles 0.02 em).
2. **`draw_string_outline()`'s `size`** grows each glyph edge by size/4 px, while a canvas stroke of
   `lineWidth` grows it by lineWidth/2: an 8 px sound-word stroke is `outline_size = 16`.
3. **Clipping a panel** is `Control.clip_contents`; it clips every child, `Node2D` figures
   included. The panel border is an internal child added last, so it draws over the art.
