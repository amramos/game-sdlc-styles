class_name RetroTextures
extends RefCounted
## Textures drawn in code at true size from the palette roles, cut to 5 bits per channel,
## nearest-filtered. Same drawing and seeded randomness as the web demo, texel for texel.

var P: Dictionary            # the palette: role -> "#RRGGBB"
var img: Image
var _a := 0                  # mulberry32 state

func _init(palette: Dictionary) -> void:
	P = palette

# ------------------------------------------------------------------ seeded random (mulberry32 + FNV name hash)
static func imul(x: int, y: int) -> int:
	return ((x & 0xFFFF) * y + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF

static func name_hash(s: String) -> int:
	var h := 2166136261
	for ch in s:
		h = imul(h ^ ch.unicode_at(0), 16777619)
	return h

func r() -> float:
	_a = (_a + 0x6D2B79F5) & 0xFFFFFFFF
	var t := imul(_a ^ (_a >> 15), 1 | _a)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

# ------------------------------------------------------------------ colours (CSS rgb() rounding)
func rgb(role: String) -> Array:
	var c := Color.html(P[role])
	return [c.r8, c.g8, c.b8]

func _css(a: Array) -> Color:
	var o := []
	for v in a: o.append(clampi(int(floor(v + 0.5)), 0, 255))
	return Color8(o[0], o[1], o[2])

func shade(role: String, k: float) -> Color:
	var a := rgb(role)
	return _css([a[0] * k, a[1] * k, a[2] * k])

func mixc(ra: String, rb: String, t: float) -> Color:
	var a := rgb(ra); var b := rgb(rb)
	return _css([a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t])

# ------------------------------------------------------------------ canvas-like drawing
var fill_col := Color.BLACK

func rect(x: int, y: int, w: int, h: int, col = null) -> void:
	if col != null: fill_col = col
	var r2 := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r2.size.x > 0 and r2.size.y > 0: img.fill_rect(r2, fill_col)

func speck(n: int, col: Color, s := 1) -> void:
	fill_col = col
	var w := img.get_width(); var h := img.get_height()
	for i in n:
		var x := int(floor(r() * w)); var y := int(floor(r() * h))
		rect(x, y, s, s)

const GLYPHS := { "O": "01110100011000110001100011000101110", "P": "11110100011000111110100001000010000",
	"E": "11111100001000011110100001000011111", "N": "10001110011010110011100011000110001",
	"A": "01110100011000111111100011000110001", "T": "11111001000010000100001000010000100" }

## 5x7 bitmap letters drawn texel by texel; s = texels per glyph pixel.
func pixel_text(text: String, s: int) -> void:
	var w := img.get_width(); var h := img.get_height()
	var tw := text.length() * 6 * s - s
	var x0 := int(floor((w - tw) / 2.0 + 0.5)); var y0 := int(floor((h - 7 * s) / 2.0 + 0.5))
	for k in text.length():
		var g: String = GLYPHS[text[k]]
		for i in 35:
			if g[i] == "1": rect(x0 + (k * 6 + i % 5) * s, y0 + (i / 5) * s, s, s)

# ------------------------------------------------------------------ the textures
func make(tex_name: String, source: Image = null) -> ImageTexture:
	var size: Array = {"floor": [64, 64], "formica": [64, 64], "brick": [64, 64], "jukefront": [64, 64],
		"neon": [8, 8], "tube": [8, 8], "sign": [64, 32], "open": [128, 32], "menu": [64, 32],
		"sky": [4, 64]}.get(tex_name, [32, 32])
	img = Image.create(size[0], size[1], false, Image.FORMAT_RGBA8)
	_a = name_hash(tex_name)
	var w: int = size[0]; var h: int = size[1]
	match tex_name:
		"floor", "formica", "brick":                       # MaterialCraft PNGs
			img.blit_rect(source, Rect2i(0, 0, w, h), Vector2i.ZERO)
		"wall":
			rect(0, 0, w, h, shade("material-wall", 1))
			rect(0, 0, 1, h, shade("material-wall", 0.8)); rect(16, 0, 1, h)
			rect(1, 0, 1, h, shade("material-wall", 1.1)); rect(17, 0, 1, h)
			speck(30, shade("material-wall", 0.9))
		"tile":
			rect(0, 0, w, h, shade("material-cloth", 0.95))
			fill_col = shade("material-chrome", 0.7)
			for i in range(0, 32, 8): rect(i, 0, 1, h); rect(0, i, w, 1)
			speck(16, shade("material-cloth", 0.85))
		"ceiling":
			rect(0, 0, w, h, shade("material-cloth", 0.86))
			speck(90, shade("material-cloth", 0.7))
			rect(0, 0, w, 1, shade("material-chrome", 0.8)); rect(0, 0, 1, h)
		"wood":
			rect(0, 0, w, h, shade("material-wood", 1))
			for y in h:
				if r() < 0.45: rect(0, y, w, 1, shade("material-wood", 0.82 if r() < 0.5 else 1.15))
			fill_col = shade("material-wood", 0.6)
			for i in range(0, 32, 8): rect(i, 0, 1, h)
		"vinyl":
			rect(0, 0, w, h, shade("material-vinyl", 1))
			fill_col = shade("material-vinyl", 0.72)
			for i in range(-32, 32, 8):
				for k in 32: rect(i + k, k, 1, 1); rect(i + 32 - k, k, 1, 1)
			fill_col = shade("material-vinyl", 1.25)
			for j in 4:
				for i in 4: rect(i * 8 + 4, j * 8, 2, 2)
		"chrome":
			var k := [0.62, 0.8, 1.0, 1.12, 1.18, 1.05, 0.85, 0.7]
			for y in h: rect(0, y, w, 1, shade("material-chrome", k[(y / 2) % 8]))
		"asphalt":
			rect(0, 0, w, h, shade("material-asphalt", 1))
			speck(110, shade("material-asphalt", 0.75)); speck(70, shade("material-asphalt", 1.35))
		"road":
			rect(0, 0, w, h, shade("material-asphalt", 0.85))
			speck(90, shade("material-asphalt", 0.65))
			rect(0, 15, 18, 2, shade("material-formica", 1))
		"paint":
			rect(0, 0, w, h, shade("material-paint", 1))
			rect(0, 0, w, 5, shade("material-paint", 1.25))
			rect(0, 14, w, 2, shade("material-chrome", 1.05))
			speck(12, shade("material-paint", 0.85))
		"glass":
			rect(0, 0, w, h, mixc("material-floor-dark", "sky", 0.35))
			fill_col = mixc("material-floor-dark", "sky", 0.8)
			for k in 32: rect(k, 31 - k, 3, 1)
		"dark":
			rect(0, 0, w, h, shade("material-floor-dark", 1))
			speck(40, shade("material-floor-dark", 1.5))
		"cloth":
			rect(0, 0, w, h, shade("material-cloth", 1))
			fill_col = shade("material-cloth", 0.86)
			for i in range(3, 32, 7): rect(i, 0, 1, h)
			speck(20, shade("material-cloth", 0.9))
		"jukefront":
			rect(0, 0, w, h, shade("material-wood", 1))
			rect(8, 4, 48, 26, shade("glow-jukebox", 1))                    # lit window
			fill_col = shade("material-cloth", 1)
			for i in 4: rect(12, 8 + i * 5, 40, 3)                          # song cards
			fill_col = shade("material-floor-dark", 1)
			for i in 4:
				for k in 5: rect(14 + k * 8, 9 + i * 5, 5, 1)
			fill_col = shade("material-chrome", 1)
			for k in 8: rect(10 + k * 6, 32, 4, 3)                          # buttons
			rect(10, 38, 44, 20, shade("material-chrome", 0.75))
			fill_col = shade("material-floor-dark", 1)
			for y in range(40, 57, 3): rect(12, y, 40, 1)                   # grille
			rect(2, 4, 4, 58, shade("glow-sign", 1)); rect(58, 4, 4, 58)    # side tubes
		"jukearch":
			var c := ["glow-jukebox", "glow-sign", "material-cloth", "glow-sign"]
			for i in 8: rect(i * 4, 0, 4, h, shade(c[i % 4], 1))
		"neon":
			rect(0, 0, w, h, shade("glow-sign", 1))
		"tube":
			rect(0, 0, w, h, shade("glow-tube", 1))
		"sign":
			rect(0, 0, w, h, shade("material-floor-dark", 1))
			rect(2, 2, 60, 2, shade("glow-sign", 1)); rect(2, 28, 60, 2); rect(2, 2, 2, 28); rect(60, 2, 2, 28)
			pixel_text("EAT", 3)
		"open":
			rect(0, 0, w, h, shade("material-floor-dark", 1))
			fill_col = shade("glow-sign", 1)
			pixel_text("OPEN", 3)
		"menu":
			rect(0, 0, w, h, shade("material-floor-dark", 1))
			fill_col = shade("material-cloth", 0.95)
			for j in 6:
				var px := 4
				while px < 44:
					var l := 2 + int(floor(r() * 5))
					rect(px, 4 + j * 4, l, 2)
					px += l + 1
			fill_col = shade("material-formica", 1)
			for j in 6: rect(52, 4 + j * 4, 7, 2)
		"hill":
			rect(0, 0, w, h, mixc("material-brick", "material-formica", 0.35))
			speck(90, shade("material-brick", 0.8), 2); speck(40, shade("material-formica", 0.9))
		"sky":
			for y in h:
				rect(0, y, w, 1, mixc("sky", "fog", pow(y / 32.0, 1.5)) if y < 32 else shade("fog", 1))
	# 5 bits per channel, like the textures of the era
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color8(c.r8 >> 3 << 3, c.g8 >> 3 << 3, c.b8 >> 3 << 3))
	img.flip_y()   # canvas row 0 is the top; three's CanvasTexture flips it, so v = 0 is the bottom row
	return ImageTexture.create_from_image(img)
