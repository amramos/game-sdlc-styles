class_name InkTheme
extends RefCounted
## Builds the one theme that owns every font, size and panel of the interface.
## Colours come from the game's palette roles; nothing else in the project names a colour or a font.

const NIGHT := {
	"ink": "#121624", "paper": "#F2EADB", "accent": "#FF4A1C", "shadow": "#12333A",
	"signal": ["#7FB2FF", "#FFC93C", "#3CCB98"], "counter": "#0B0D14",
}

## The demo's own font files (assets/fonts/ on the web), so the engine draws the same faces.
static var display_base := _file("res://fonts/BebasNeue-Regular.woff")
static var body_base := _file("res://fonts/SpecialElite-Regular.woff")
## The chip mark (↺) neither face has: the demo's small symbol subset, as on the web page, instead
## of the OS fallback, which picks a different font, size and baseline per platform.
static var mark_base := _file("res://fonts/NotoSansMath-Marks.woff")

static func _file(path: String) -> FontFile:
	var f: FontFile = load(path)
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
		"ChipWord":    [display_base, 20, 26.0, 1, ink, 0],     # line-height normal: 1.3 em in this face
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
	var act := panel(ink, ink, 4, Vector4(26, 10, 27, 6))   # +1 right: CSS letter-spacing also trails the last letter
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(st, "Button", act)
	t.set_font("font", "Button", line_font(display_base, 40, 52.0, 2))   # line-height normal: 1.3 em
	t.set_font_size("font_size", "Button", 40)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", paper)
	return t
