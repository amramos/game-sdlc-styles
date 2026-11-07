# Godot 4 snippets

<!-- matched-web-frame: 95e103e57757 -->

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.*` rebuilds
`demo.html?frame=key-scene`: the entry's own stage and cast PNGs (`cast/`) in `TextureRect`s, and
every panel, word and number drawn by the engine from one theme, with the code on this page.
Measured match: mean difference 2.4 / 2.0 / 2.8 per 255 (R/G/B) for the PNG render, 1.7 / 1.6 / 1.8
for the delivered JPEG; same layout to the pixel for every panel, chip, card, tail and bracket. What
still differs is text rasterisation, not layout:

- **Glyph rendering.** The browser draws text with DirectWrite (slightly darker strokes, faint
  colour fringes); Godot draws greyscale coverage, so the body face reads a touch lighter. Godot's
  LCD subpixel mode was tried and fringes far more than the web frame: keep greyscale.
- **Tilted and lifted text.** A browser re-rasterises glyphs under `rotate()`/`scale()`; Godot
  transforms the glyph bitmaps, so the tilted tag and the focused card (×1.06) are a little softer.
  These two are the worst 64 px tiles (about 20/255 on glyph edges).
- **A light rim on the scaled card** in the web frame is a browser artefact (the paper background
  bleeds through the antialiased edge of the scaled border). Godot doesn't draw it.
- **±1 px** on a few baselines (the third card's text, the chip mark) where the browser's fractional
  layout rounds differently.

Forward+ renders the same frame (mean difference 0.0/255): nothing here is renderer-specific.

## Scene layout

1280×720 base, every coordinate is the web demo's. `main.tscn` is a single root `Control` (full-rect
anchors) with `main.gd`, which builds the tree:

```
Main (Control, full rect, theme = InkTheme.build(palette))
├─ Stage (Control)                       quiet: images only
│  ├─ Backdrop (TextureRect)             stage PNG, keep-aspect-covered into (-20,-70) 1320×880
│  ├─ Customer (TextureRect)             cast PNG, 500 px tall at (150,118), linear filter
│  └─ Counter (Panel)                    near-black, 4 px ink top border, covers the actor's legs
└─ UI (Control)                          loud: the engine draws all of it
   ├─ Offer (PanelContainer "TagPanel")  tilted −3°: caption + PriceLabel
   ├─ Line (Control at 600,110)
   │  ├─ HalftoneShadow (ColorRect + halftone.gdshader)   under the panel, over the stage
   │  ├─ SpeechBubble (PanelContainer)   paper panel; draws its own tail, centred on its side
   │  └─ Who (PanelContainer "WhoPanel") speaker's name on an ink strip, tilted −3°
   ├─ Chips (HBoxContainer)              20 px under the bubble, wherever its text ends
   ├─ Options (HBoxContainer)            per option a plain Control slot → card (PanelContainer)
   ├─ Act (Button)                       ink, with a hard accent shadow behind it
   └─ FocusBrackets (Control)            four paper corners around the focused card
```

**Images.** Use the entry's PNGs as they are (`cast/stage-stall-night.png`,
`cast/customer-haggling.png`). Import settings: lossless (compress mode 0), **mipmaps off**. The
cast is shown at 0.57× with a plain linear filter: with mipmaps on, the outlines came out softer
than the browser's downscale (customer region error 2.3 vs 1.7).

**Fonts.** The web demo loads no font files: its CSS stacks fall back to whatever the machine has.
The port uses `SystemFont` with the same stacks in the same order, so it resolves to the same faces
the web frame used (on a stock Windows machine: Impact for display, Courier New for body, Segoe UI
Symbol for the chip mark). A game should ship its chosen faces as `FontFile`s (the style's
licence-safe candidates: Bebas Neue, Oswald or League Gothic for display; Special Elite, Space Mono
or IBM Plex Mono for body); system fonts differ from machine to machine.

**Project settings:**

```ini
config_version=5

[application]
config/name="my-game"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=1
environment/defaults/default_clear_color=Color(0.0431373, 0.0509804, 0.0784314, 1)
```

## The theme: every font, size and panel in one place

`InkTheme.build(palette)` returns the `Theme`; nothing else names a colour or a font. Type roles are
`Label` type variations (`Caption`, `Line`, `CardText`, …); panels are `PanelContainer` variations.
Two helpers carry the web's box model over:

- `panel()` takes CSS padding and adds the border width, because a `StyleBoxFlat`'s content margins
  are measured from its outer edge, border included.
- `line_font()` gives a role a CSS-style line height (glyphs centred in the line box, negative
  half-leading allowed) through `FontVariation.spacing_top/bottom`.

```gdscript
class_name InkTheme
extends RefCounted
## Builds the one theme that owns every font, size and panel of the interface.
## Colours come from the game's palette roles; nothing else in the project names a colour or a font.

const NIGHT := {
	"ink": "#121624", "paper": "#F2EADB", "accent": "#FF4A1C", "shadow": "#12333A",
	"signal": ["#7FB2FF", "#FFC93C", "#3CCB98"], "counter": "#0B0D14",
}

## Same fallback order as the web demo's CSS stacks. Ship your chosen faces as FontFiles in a game.
static var display_base := _system(["Bebas Neue", "League Gothic", "Oswald", "Impact", "Arial Narrow"])
static var body_base := _system(["Special Elite", "Courier New", "IBM Plex Mono"])
## Chip marks (arrows, signs) the display face lacks: name the symbol face instead of trusting the
## OS fallback, which picks a different font, size and baseline per platform.
static var mark_base := _system(["Segoe UI Symbol", "Noto Sans Symbols 2", "DejaVu Sans"])

static func _system(names: Array) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.hinting = TextServer.HINTING_NONE                                # browser-like: fractional advances
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_ONE_QUARTER
	return f

## A font whose line box is `line_height` px tall with the glyphs centred in it, like CSS line-height
## (half-leading above and below; negative when line_height is smaller than the font's own height).
static func line_font(base: Font, size: int, line_height: float, tracking := 0, shift := 0) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	var lead := line_height - (base.get_ascent(size) + base.get_descent(size))
	v.spacing_top = roundi(lead / 2.0) + shift      # `shift` moves the glyphs down inside the box
	v.spacing_bottom = roundi(lead) - v.spacing_top
	v.spacing_glyph = tracking
	return v

## A panel of the interface material. `margins` is the CSS padding (left, top, right, bottom).
static func panel(bg: Color, border: Color, width := 4, margins := Vector4(12, 10, 12, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	# Godot's content margins are measured from the outer edge: CSS padding + border
	s.content_margin_left = margins.x + width
	s.content_margin_top = margins.y + width
	s.content_margin_right = margins.z + width
	s.content_margin_bottom = margins.w + width
	return s

static func build(pal: Dictionary) -> Theme:
	var ink := Color(pal.ink)
	var paper := Color(pal.paper)
	var t := Theme.new()
	t.default_font = body_base
	# Label variations: name -> [font, size, line height px, tracking px, colour, shift px]
	# (shift: Godot rounds this font's ascent up where a browser rounds it to nearest; +-1 px)
	var roles := {
		"Caption":     [display_base, 18, 18.0, 1, ink, 0],     # display face, upper case, small
		"CardCaption": [display_base, 17, 17.0, 1, ink, 0],
		"Who":         [display_base, 18, 18.0, 1, paper, 0],
		"ChipWord":    [display_base, 20, 24.0, 1, ink, 0],
		"Line":        [body_base, 22, 29.04, 0, ink, -1],      # dialogue: body face, 1.32 line height
		"CardText":    [body_base, 19, 22.8, 0, ink, 0],
		"Mark":        [mark_base, 16, 24.0, 0, paper, -2],
	}
	for name in roles:
		var r: Array = roles[name]
		var base: Font = r[0]
		t.add_type(name)
		t.set_type_variation(name, "Label")
		t.set_font("font", name, line_font(base, r[1], r[2], r[3], r[5]))
		t.set_font_size("font_size", name, r[1])
		t.set_color("font_color", name, r[4])
		t.set_constant("line_spacing", name, 0)
	# panels
	t.set_stylebox("panel", "PanelContainer", panel(paper, ink))
	for v in [["TagPanel", panel(paper, ink, 4, Vector4(10, 6, 10, 4))],
			["WhoPanel", panel(ink, ink, 0, Vector4(10, 4, 10, 3))],
			["CardPanel", panel(paper, ink)]]:
		t.add_type(v[0])
		t.set_type_variation(v[0], "PanelContainer")
		t.set_stylebox("panel", v[0], v[1])
	for i in pal.signal.size():
		var n := "Chip%d" % (i + 1)
		t.add_type(n)
		t.set_type_variation(n, "PanelContainer")
		t.set_stylebox("panel", n, panel(Color(pal.signal[i]), ink, 4, Vector4(4, 3, 10, 2)))
	# the primary action: ink fill; its hard accent shadow is a child drawn behind it (main.gd)
	var act := panel(ink, ink, 4, Vector4(26, 10, 28, 6))   # +2 right: CSS letter-spacing also trails the last letter
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(st, "Button", act)
	t.set_font("font", "Button", line_font(display_base, 40, 48.0, 2))
	t.set_font_size("font_size", "Button", 40)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", paper)
	return t
```

## The speech bubble: tail centred on the side

The tail is drawn by the panel itself, after its StyleBox, at `size.y / 2`: it stays centred on the
side and inside the panel's height for one line or five. The paper triangle covers the panel's
border between the two strokes, so the tail opens into the panel; the strokes meet in a mitred
point like SVG `stroke-linejoin: miter`.

```gdscript
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
```

## Halftone (engine-drawn shadows only, never the stage)

On a `ColorRect` the size of the shadow box: the panel's inner box moved 8 px down-right and grown
12 px. The grid starts at the rect's corner, like a CSS background tile.

```glsl
shader_type canvas_item;
// Halftone for engine-drawn shadows (never on the stage): round dots on a fixed grid, clear between.
// The grid starts at the rect's own top-left, like a CSS background tile.
uniform vec4 dot_color : source_color = vec4(0.071, 0.2, 0.227, 1.0);
uniform float cell = 6.0;     // grid size in px
uniform float radius = 2.0;   // dot radius in px (web: radial-gradient(c 1.9px, transparent 2.1px))
uniform vec2 rect_size = vec2(100.0, 100.0);

void fragment() {
	vec2 q = mod(UV * rect_size, cell) - cell * 0.5;
	float a = 1.0 - smoothstep(radius - 0.5, radius + 0.5, length(q));
	COLOR = vec4(dot_color.rgb, dot_color.a * a);
}
```

## Focus brackets

```gdscript
class_name FocusBrackets
extends Control
## Focus mark: four L corners cut from the interface material (paper, 4 px ink outline), standing
## `gap` px clear of the focused rect. Corners only, never a full outline. When focus arrives they
## close in from `approach` px further out over 0.08 s.

@export var gap := 14.0
@export var approach := 12.0
var paper := Color.WHITE
var ink := Color.BLACK
var spread := 0.0:
	set(v):
		spread = v
		queue_redraw()

func show_around(r: Rect2, animate := true) -> void:
	var g := r.grow(gap)
	position = g.position.round()   # whole pixels keep the 4 px outline crisp
	size = g.end.ceil() - position
	spread = approach if animate else 0.0
	if animate:
		create_tween().tween_property(self, "spread", 0.0, 0.08).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	# one corner: a 30x30 box holding the L "M2 2 H28 V11 H11 V28 H2 Z", the box 16 px outside the rect
	var o := -16.0 - spread
	var far := Vector2(size.x - 30.0 - o, size.y - 30.0 - o)
	var corners := [[Vector2(o, o), 0.0], [Vector2(far.x, o), PI / 2],
		[Vector2(o, far.y), -PI / 2], [far, PI]]
	var l := PackedVector2Array([Vector2(2, 2), Vector2(28, 2), Vector2(28, 11), Vector2(11, 11), Vector2(11, 28), Vector2(2, 28)])
	for c in corners:
		var xf := Transform2D(c[1], c[0] + Vector2(15, 15)) * Transform2D(0.0, Vector2(-15, -15))
		var pts: PackedVector2Array = xf * l
		for p in Geometry2D.offset_polygon(pts, 2.0, Geometry2D.JOIN_MITER):
			draw_colored_polygon(p, ink)
		for p in Geometry2D.offset_polygon(pts, -2.0, Geometry2D.JOIN_MITER):
			draw_colored_polygon(p, paper)
```

## A number with its unit

The numbers players decide by are display-face text with a small unit on the same baseline. A
`Label` can't mix sizes on one baseline, so this small `Control` draws both.

```gdscript
class_name PriceLabel
extends Control
## A number players decide by, in the display face, with its unit small after it on the same
## baseline ("12 coins"). The number sits centred in a `line_height` px line box, like CSS.

@export var number := "0"
@export var unit := " coins"
@export var number_size := 40
@export var unit_size := 20
@export var line_height := 36.0
@export var baseline_shift := 0.0   # extra px down, when the line box holds a taller strut
@export var centred := false
var color := Color.BLACK
var font: Font

func _ready() -> void:
	if font == null:
		font = InkTheme.display_base
	custom_minimum_size = Vector2(_width(), line_height)

func _width() -> float:
	return font.get_string_size(number, 0, -1, number_size).x + font.get_string_size(unit, 0, -1, unit_size).x

func _draw() -> void:
	var a := font.get_ascent(number_size)
	var d := font.get_descent(number_size)
	var x := (size.x - _width()) / 2.0 if centred else 0.0
	var y := (line_height - (a + d)) / 2.0 + a + baseline_shift
	draw_string(font, Vector2(x, y), number, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size, color)
	x += font.get_string_size(number, 0, -1, number_size).x
	draw_string(font, Vector2(x, y), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, unit_size, color)
```

## The key scene

The content strings are the demo's example setting; everything else is the look.

```gdscript
extends Control
## Port of loud-ink-cast-quiet-stage/demo.html?frame=key-scene (night palette).
## The stage and the cast are the entry's generated images; the engine draws only the interface.
## 1280x720 base, stretch canvas_items; every coordinate is the demo's.

const PAL := InkTheme.NIGHT
const LINE := "Eight coins. That bowl is half steam."
const CHIPS := [["↺", "Regular", 1]]
const OPTIONS := [["Hold firm", "Stay at the price", "12"], ["Meet them", "Split the difference", "10"],
	["Sweeten", "Add a skewer", "12"]]
const FOCUSED := 1

var ink := Color(PAL.ink)
var paper := Color(PAL.paper)
var cards: Array[Control] = []
var bubble: SpeechBubble
var chips: HBoxContainer
var focus_mark: FocusBrackets

func _ready() -> void:
	theme = InkTheme.build(PAL)
	_build_stage()
	var ui := Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(PRESET_FULL_RECT)
	ui.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(ui)
	_build_offer(ui)
	_build_line(ui)
	var options := _build_options(ui)
	_build_action(ui)
	focus_mark = FocusBrackets.new()
	focus_mark.paper = paper
	focus_mark.ink = ink
	focus_mark.mouse_filter = MOUSE_FILTER_IGNORE
	ui.add_child(focus_mark)
	await get_tree().process_frame           # containers have laid out
	await _layout_options(options)
	_place_chips()
	set_focus(FOCUSED, false)

# ---------------------------------------------------------------- stage: images only, quiet
func _build_stage() -> void:
	var stage := Control.new()
	stage.name = "Stage"
	stage.set_anchors_preset(PRESET_FULL_RECT)
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(stage)
	var back := TextureRect.new()
	back.name = "Backdrop"
	back.texture = load("res://cast/stage-stall-night.png")
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED   # CSS object-fit: cover
	back.position = Vector2(-20, -70)
	back.size = Vector2(1320, 880)
	stage.add_child(back)
	var actor := TextureRect.new()
	actor.name = "Customer"
	actor.texture = load("res://cast/customer-haggling.png")
	actor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor.stretch_mode = TextureRect.STRETCH_SCALE
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # shown at 0.57x; mipmaps measured softer than the browser
	var h := 500.0
	actor.size = Vector2(h * actor.texture.get_width() / actor.texture.get_height(), h)
	actor.position = Vector2(150, 118)
	actor.pivot_offset = Vector2(actor.size.x / 2.0, h)   # idle bob scales from the feet
	stage.add_child(actor)
	var counter := Panel.new()
	counter.name = "Counter"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAL.counter)
	sb.border_color = ink
	sb.border_width_top = 4
	counter.add_theme_stylebox_override("panel", sb)
	counter.position = Vector2(0, 536)
	counter.size = Vector2(1280, 184)
	stage.add_child(counter)

# ---------------------------------------------------------------- helpers
func label(text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	if variation.ends_with("Caption") or variation in ["Who", "ChipWord"]:
		l.uppercase = true
	return l

## Tilted labels live in a plain slot: containers reset rotation, the slot doesn't.
func tilt(node: Control, degrees: float) -> void:
	var centre := func(): node.pivot_offset = node.size / 2.0   # rotate about the centre, like CSS
	node.resized.connect(centre)
	centre.call_deferred()
	node.rotation_degrees = degrees

# ---------------------------------------------------------------- their offer: a tilted tag
func _build_offer(ui: Control) -> void:
	var tag := PanelContainer.new()
	tag.name = "Offer"
	tag.theme_type_variation = "TagPanel"
	tag.position = Vector2(36, 30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	tag.add_child(col)
	var cap := label("Their offer", "Caption")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	var num := PriceLabel.new()
	num.number = "8"
	num.number_size = 58
	num.unit_size = 26
	num.line_height = 52.2
	num.centred = true
	num.color = ink
	col.add_child(num)
	ui.add_child(tag)
	tilt(tag, -3.0)

# ---------------------------------------------------------------- the line, pointing at the speaker
func _build_line(ui: Control) -> void:
	var box := Control.new()
	box.name = "Line"
	box.position = Vector2(600, 110)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	ui.add_child(box)
	var shadow := ColorRect.new()                 # halftone shadow: under the panel, over the stage
	shadow.name = "HalftoneShadow"
	var mat := ShaderMaterial.new()
	mat.shader = load("res://halftone.gdshader")
	mat.set_shader_parameter("dot_color", Color(PAL.shadow))
	shadow.material = mat
	box.add_child(shadow)
	bubble = SpeechBubble.new()
	bubble.paper = paper
	bubble.ink = ink
	bubble.custom_minimum_size.x = 600
	bubble.add_theme_stylebox_override("panel", InkTheme.panel(paper, ink, 4, Vector4(12, 18, 12, 12)))
	var text := label(LINE, "Line")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_child(text)
	box.add_child(bubble)
	bubble.resized.connect(func():
		# the shadow box is the panel's padding box moved 8 px down-right and grown 12 px (CSS ::before)
		shadow.position = Vector2(12, 12)
		shadow.size = bubble.size - Vector2(4, 4)
		mat.set_shader_parameter("rect_size", shadow.size)
		_place_chips())
	var who := PanelContainer.new()
	who.name = "Who"
	who.theme_type_variation = "WhoPanel"
	who.position = Vector2(-6, -22)                # CSS left:-10px top:-26px from the padding edge
	who.add_child(label("Pell", "Who"))
	box.add_child(who)
	tilt(who, -3.0)
	chips = HBoxContainer.new()
	chips.name = "Chips"
	chips.add_theme_constant_override("separation", 10)
	for c in CHIPS:
		chips.add_child(_chip(c[0], c[1], c[2]))
	ui.add_child(chips)

## A signal chip: its own fill, ink text, and the kind in a word plus a mark (never colour alone).
func _chip(mark: String, word: String, kind: int) -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "Chip%d" % kind
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	chip.add_child(row)
	var m := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ink
	m.add_theme_stylebox_override("panel", sb)
	m.custom_minimum_size = Vector2(24, 24)
	m.size_flags_vertical = SIZE_SHRINK_CENTER
	var ml := label(mark, "Mark")
	ml.set_anchors_preset(PRESET_FULL_RECT)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m.add_child(ml)
	row.add_child(m)
	var wl := label(word, "ChipWord")
	wl.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(wl)
	return chip

func _place_chips() -> void:
	if chips and bubble:
		chips.position = Vector2(600, 110 + bubble.size.y + 20)   # under the line, wherever its text ends

# ---------------------------------------------------------------- the player's options on the counter
func _build_options(ui: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Options"
	row.add_theme_constant_override("separation", 22)
	ui.add_child(row)
	for o in OPTIONS:
		var slot := Control.new()                 # the container lays out the slot; the card lifts inside it
		slot.size_flags_vertical = SIZE_SHRINK_END
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.focus_mode = FOCUS_ALL
		card.custom_minimum_size = Vector2(190, 118)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		card.add_child(col)
		var cap := label(o[0], "CardCaption")
		cap.modulate.a = 0.9
		col.add_child(cap)
		col.add_child(_gap(4))
		var txt := label(o[1], "CardText")
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.custom_minimum_size.x = 158
		col.add_child(txt)
		col.add_child(_gap(6))
		var num := PriceLabel.new()
		num.number = o[2]
		num.line_height = 39.0                    # the number's line box, with the body face's strut
		                                          # (containers lay out in whole px: 2 x 23 + 39 = the web's 45.6 + 39.4)
		num.baseline_shift = -1.0
		num.color = ink
		col.add_child(num)
		slot.add_child(card)
		row.add_child(slot)
		cards.append(card)
		var i := cards.size() - 1
		card.mouse_entered.connect(func(): set_focus(i))
		card.focus_entered.connect(func(): set_focus(i))
	return row

## Each card keeps its own height (min 118); the row sits 26 px above the bottom, cards bottom-aligned.
func _layout_options(row: HBoxContainer) -> void:
	for c in cards:
		c.size = c.get_combined_minimum_size()
		c.get_parent().custom_minimum_size = c.size
		c.pivot_offset = c.size / 2.0
	await get_tree().process_frame
	row.size = row.get_combined_minimum_size()
	row.position = Vector2(28, 720 - 26 - row.size.y).round()

func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size.y = h
	return g

## The focused card lifts (12 px up, x1.06) and the brackets close in around it.
func set_focus(i: int, animate := true) -> void:
	for j in cards.size():
		var lifted := j == i
		var face := cards[j]
		if animate:
			var tw := face.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(face, "position:y", -12.0 if lifted else 0.0, 0.08)
			tw.tween_property(face, "scale", Vector2.ONE * (1.06 if lifted else 1.0), 0.08)
		else:
			face.position.y = -12.0 if lifted else 0.0
			face.scale = Vector2.ONE * (1.06 if lifted else 1.0)
	var c := cards[i]
	var slot := c.get_parent() as Control
	var sz := c.size * 1.06
	var centre := slot.global_position + c.size / 2.0 + Vector2(0, -12)
	focus_mark.show_around(Rect2(centre - sz / 2.0, sz), animate)

# ---------------------------------------------------------------- the primary action
func _build_action(ui: Control) -> void:
	var act := Button.new()
	act.name = "Act"
	act.text = "OFFER"
	act.focus_mode = FOCUS_NONE
	var shade := ColorRect.new()                  # hard offset shadow in the accent, no blur
	shade.color = Color(PAL.accent)
	shade.show_behind_parent = true
	shade.position = Vector2(6, 6)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	act.add_child(shade)
	ui.add_child(act)
	await get_tree().process_frame
	act.size = act.get_combined_minimum_size()
	shade.size = act.size
	act.position = Vector2(1280 - 40, 720 - 44) - act.size
```

**Idle motion** (not in the still frame): the web demo bobs the speaking actor at about 10 fps
(`scaleY(1 + 0.008 sin 2.4t)`, `rotate(0.6° sin 1.2t)`) from the feet; the `Customer` node's pivot is
already at its feet for this. Pause it when the window loses focus.

## Traps found in the port

None of these is Compatibility-specific: Forward+ draws the same frame.

- **Pivot before layout.** A `PanelContainer` gets its size a frame after it enters the tree. A
  pivot set from that first size, or never updated, rotates the tag about its top-left corner: a 3°
  tilt then moves it about 2 px right and 3 px up. Set `pivot_offset` on `resized` and once deferred.
- **StyleBox margins include the border.** Setting `content_margin_*` to the CSS padding alone puts
  text 4 px too close to every edge.
- **Containers lay out in whole pixels.** Fractional CSS line heights (22.8 px) round per child, so a
  card grows by a pixel and every bracket and lift after it moves. Budget line boxes in whole pixels
  (here 2 × 23 + 39 for the web's 45.6 + 39.4).
- **Hinting rounds advances.** With `SystemFont`'s default hinting, a 22 px monospace advance is 13
  px instead of 13.2: a 37-character line ends 7 px short. `HINTING_NONE` plus quarter-pixel subpixel
  positioning gives browser-like advances.
- **Godot rounds ascent and descent up,** a browser rounds to nearest, so a CSS line height centres
  the glyphs up to 1 px differently; each role in the theme has a `shift` for this.
- **Letter-spacing.** CSS letter-spacing also follows the last letter (it widens the box); Godot's
  `spacing_glyph` doesn't. Add it to the right margin where a box must match (the action button).
  `spacing_glyph` is whole pixels, so 0.06 em becomes 1 px.
- **Symbol fallback.** A mark the display face lacks (↺) falls back to an OS font of a different
  size and baseline than the browser's. Name a symbol face for marks.
- **2D MSAA** (`anti_aliasing/quality/msaa_2d`) changed nothing in this frame (no pixel differed);
  `draw_colored_polygon()` edges (tail, brackets) are aliased either way, which at 4 px ink on these
  shapes is within a pixel of the web.
