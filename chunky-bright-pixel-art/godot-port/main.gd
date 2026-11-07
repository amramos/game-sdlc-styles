extends Node2D
## Port of chunky-bright-pixel-art/demo.html?frame=key-scene to Godot nodes.
## Every node draws a role INDEX (red = index / 15); one palette shader on this root turns
## indices into colours, children inherit it with use_parent_material.

const PALETTE := ["#1E1430", "#FFF4D6", "#FF38B0", "#6BD94A", "#FF4B3E", "#B67CFF",
	"#6B2E3A", "#B8543A", "#E89A4C", "#FFD77A", "#2B2459", "#33589E", "#3FA0C8", "#9BE8E4",
	"#BFE0E6", "#E6C4A4"]
enum { INK, PAPER, ACCENT, GOOD, BAD, RARE, W1, W2, W3, W4, C1, C2, C3, C4, SKY, FAR }
const CH := {"k": INK, "p": PAPER, "A": ACCENT, "G": GOOD, "X": BAD, "V": RARE,
	"1": W1, "2": W2, "3": W3, "4": W4, "a": C1, "b": C2, "c": C3, "d": C4, "s": SKY, "f": FAR}
const W := 320
const H := 180
const GROUND := 108

## Batches consecutive rectangles into one node, drawn in order.
class RectBatch extends Node2D:
	var rects: Array = []
	func _draw() -> void:
		for r in rects:
			draw_rect(Rect2(r[0], r[1], r[2], r[3]), Color(r[4] / 15.0, 0, 0, 1))

var _batch: RectBatch = null
var S := {}

# ------------------------------------------------------------------ drawing primitives
func idx(c: int) -> Color:
	return Color(c / 15.0, 0, 0, 1)

func rect(x: float, y: float, w: float, h: float, c: int) -> void:
	if w <= 0 or h <= 0:
		return
	if _batch == null:
		_batch = RectBatch.new()
		_batch.use_parent_material = true
		add_child(_batch)
	_batch.rects.append([roundi(x), roundi(y), int(w), int(h), c])

func px(x: float, y: float, c: int) -> void:
	rect(x, y, 1, 1, c)

func box(x, y, w, h, c) -> void:
	rect(x, y, w, 1, c); rect(x, y + h - 1, w, 1, c); rect(x, y, 1, h, c); rect(x + w - 1, y, 1, h, c)

# ------------------------------------------------------------------ sprite grids
func grid(w: int, h: int) -> Dictionary:
	var d := PackedInt32Array(); d.resize(w * h); d.fill(-1)
	return {"w": w, "h": h, "d": d}

func gset(g: Dictionary, x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < g.w and y < g.h:
		g.d[y * g.w + x] = c

func grect(g, x, y, w, h, c) -> void:
	for j in h:
		for i in w:
			gset(g, x + i, y + j, c)

func parse(rows: Array) -> Dictionary:
	var w := 0
	for r in rows: w = maxi(w, r.length())
	var g := grid(w, rows.size())
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			if r[x] != ".":
				g.d[y * w + x] = CH[r[x]]
	return g

func outline(g: Dictionary) -> Dictionary:
	var o := grid(g.w + 2, g.h + 2)
	for y in g.h:
		for x in g.w:
			o.d[(y + 1) * o.w + x + 1] = g.d[y * g.w + x]
	var src: PackedInt32Array = o.d.duplicate()
	for y in o.h:
		for x in o.w:
			if src[y * o.w + x] >= 0: continue
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + v.x
				var ny: int = y + v.y
				if nx >= 0 and ny >= 0 and nx < o.w and ny < o.h and src[ny * o.w + nx] >= 0:
					o.d[y * o.w + x] = INK
					break
	return o

## Grid -> ImageTexture with the role index in the red channel.
func tex(g: Dictionary) -> ImageTexture:
	if g.has("tex"): return g.tex
	var img := Image.create_empty(g.w, g.h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in g.h:
		for x in g.w:
			var v: int = g.d[y * g.w + x]
			if v >= 0: img.set_pixel(x, y, idx(v))
	g.tex = ImageTexture.create_from_image(img)
	return g.tex

func spr(g: Dictionary, x: float, y: float, flip := false) -> void:
	_batch = null   # later rects go in a new batch above this sprite
	var s := Sprite2D.new()
	s.texture = tex(g)
	s.centered = false
	s.flip_h = flip
	s.position = Vector2(roundi(x), roundi(y))
	s.use_parent_material = true
	add_child(s)

# ------------------------------------------------------------------ cast: generated PNGs
## The cast and the beast are PixelForge-cleaned PNGs on the palette, already outlined in ink.
## Each opaque pixel is mapped back to its role index, so the palette shader (and a palette
## swap) reaches them like everything else. Import them Lossless, mipmaps off.
func png_grid(path: String) -> Dictionary:
	var img: Image = (load(path) as Texture2D).get_image()
	img.convert(Image.FORMAT_RGBA8)
	var lut := {}
	for i in PALETTE.size(): lut[Color(PALETTE[i]).to_rgba32()] = i
	var g := grid(img.get_width(), img.get_height())
	for y in g.h:
		for x in g.w:
			var c := img.get_pixel(x, y)
			if c.a8 == 0: continue
			c.a8 = 255
			assert(lut.has(c.to_rgba32()), "off-palette pixel in " + path)
			g.d[y * g.w + x] = lut[c.to_rgba32()]
	return g

## Idle frame B: the row at 45% of the height is removed and the top drops 1 px.
func squash_grid(g: Dictionary) -> Dictionary:
	var cut := int(floor(g.h * 0.45))
	var o := grid(g.w, g.h)
	for y in g.h:
		if y == cut: continue
		var oy: int = y + 1 if y < cut else y
		for x in g.w:
			o.d[oy * g.w + x] = g.d[y * g.w + x]
	return o

func crate(w: int, h: int) -> Dictionary:
	var g := grid(w, h)
	grect(g, 0, 0, w, h, W2); grect(g, 0, 0, w, 1, W4); grect(g, 0, 1, w, 2, W3)
	var x := 4
	while x < w - 1:
		grect(g, x, 3, 1, h - 3, W1); x += 5
	grect(g, 0, 3, 1, h - 3, W3); grect(g, 0, h - 1, w, 1, W1)
	return g

func awning(w: int, a: String, b: String) -> Dictionary:
	var g := grid(w, 15)
	var shade := {"c": "b", "p": "d", "2": "1", "4": "3"}
	for x in w:
		var ch: String = b if (x / 6) % 2 == 1 else a
		var tab := x % 6
		var length := 11 + (2 if tab >= 1 and tab <= 4 else 0) + (1 if tab >= 2 and tab <= 3 else 0)
		for y in length:
			gset(g, x, y, CH[shade[ch] if y >= length - 2 else ch])
	grect(g, 0, 0, w, 1, CH["d" if a == "c" else "4"])
	return g

func counter(w: int, h: int) -> Dictionary:
	var g := grid(w, h)
	grect(g, 0, 0, w, h, W2); grect(g, 0, 0, w, 1, W4); grect(g, 0, 1, w, 2, W3)
	var y := 7
	while y < h:
		grect(g, 1, y, w - 2, 1, W1); y += 4
	grect(g, 0, h - 1, w, 1, W1)
	return g

func build_sprites() -> void:
	S.player = []   # walk: contact, passing, contact, passing
	for f in ["cast_traveller", "cast_traveller_walk2", "cast_traveller_walk3", "cast_traveller_walk4"]:
		S.player.append(png_grid("res://sprites/%s.png" % f))
	var t1 := png_grid("res://sprites/cast_trader1.png")
	var t2 := png_grid("res://sprites/cast_trader2.png")
	S.trader = [t1, squash_grid(t1)]
	S.trader2 = [t2, squash_grid(t2)]
	S.camel = [png_grid("res://sprites/beast_camel.png"), png_grid("res://sprites/beast_camel_chew.png")]
	S.crate = outline(crate(18, 14))
	S.crateSmall = outline(crate(12, 10))
	S.sack = outline(parse(["....11....", "...2442...", "..234432..", ".23444432.", "2344444332",
		"2334444332", "2333443322", "2233333322", ".22222222."]))
	S.pot = outline(parse(["..bbbb..", "...cc...", ".bccddb.", "bcccddcb", "bccccccb", "bbccccbb", ".bbbbbb."]))
	S.jar = outline(parse([".aaaa.", ".dddd.", "cdddcc", "c3333c", "cccccb", ".bbbb."]))
	S.fruit = outline(parse([".2.2.2.", "2121212", "1212121"]))
	S.rolls = outline(parse(["cdddddddc", "bccccccbb", "342222243", "231111132"]))
	S.lantern = outline(parse(["....11....", "...2..2...", "..222222..", ".21111112.", ".24pp4442.",
		".24ppp442.", ".244pp442.", ".24444442.", ".21111112.", "..222222..", "...1111..."]))
	S.arrow = parse(["AAAAA", ".AAA.", "..A.."])
	S.awning1 = outline(awning(76, "c", "p"))
	S.awning2 = outline(awning(76, "2", "4"))
	S.counter = outline(counter(64, 16))
	var post := ["22", "22", "22"]
	for i in 40: post.append("21")
	S.post = outline(parse(post))
	S.sun = parse(["..4.4..", ".44444.", "4444444", ".44444.", "4444444", ".44444.", "..4.4.."])
	S.coin = outline(parse([".444.", "44p34", "44434", "43332", ".222."]))
	S.flags = []
	for ch in ["c", "4", "2", "p"]:
		S.flags.append(outline(parse([ch.repeat(5), "." + ch.repeat(3), ".." + ch])))

# ------------------------------------------------------------------ 3x5 font (subset used here)
const GLYPHS := {
	"A": ".#. #.# ### #.# #.#", "D": "##. #.# #.# #.# ##.", "E": "### #.. ##. #.. ###",
	"N": "##. #.# #.# #.# #.#", "O": ".#. #.# #.# #.# .#.", "R": "##. #.# ##. #.# #.#",
	"T": "### .#. .#. .#. .#.", "Y": "#.# #.# .#. .#. .#.",
	"0": "### #.# #.# #.# ###", "1": ".#. ##. .#. .#. ###", "2": "##. ..# .#. #.. ###",
	"3": "##. ..# .#. ..# ##.", "4": "#.# #.# ### ..# ..#", "8": "### #.# ### #.# ###",
	",": "... ... ... .#. #..", " ": "... ... ... ... ...",
}
func text(s: String, x: int, y: int, c: int) -> void:
	for n in s.length():
		var rows: PackedStringArray = GLYPHS[s[n]].split(" ")
		for j in 5:
			for i in 3:
				if rows[j][i] == "#": px(x + n * 4 + i, y + j, c)

func tw(s: String) -> int: return s.length() * 4 - 1
func panel(x, y, w, h) -> void: rect(x, y, w, h, INK); box(x + 1, y + 1, w - 2, h - 2, C2)
func chip(label: String, x, y, role) -> int:
	var w := tw(label) + 4
	rect(x, y, w, 7, role); text(label, x + 2, y + 1, INK)
	return w

# ------------------------------------------------------------------ key scene
func backdrop() -> void:
	rect(0, 0, W, H, SKY)
	for y in range(-9, 10):
		for x in range(-9, 10):
			if x * x + y * y <= 80: px(262 + x, 30 + y, PAPER)
	for x in W:
		var top := 86 + roundi(5 * sin(x / 26.0) + 3 * sin(x / 11.0 + 1))
		rect(x, top, 1, GROUND - top, FAR)
	for t in [[40, 10], [58, 6], [120, 14], [300, 8]]:
		var dx: int = t[0]; var dw: int = t[1]
		var top: int = 80 - dw / 2
		rect(dx, top + dw / 2, dw, 10, FAR)
		for y in range(0, ceili(dw / 2.0)):
			var half := roundi(sqrt(pow(dw / 2.0, 2) - pow(dw / 2.0 - y, 2)))
			rect(dx + dw / 2.0 - half, top + y, half * 2, 1, FAR)
	for c in [[70, 24, 5], [170, 40, 4]]:
		rect(c[0], c[1], c[2] * 8, 4, PAPER); rect(c[0] + 6, c[1] - 3, c[2] * 4, 3, PAPER)
		rect(c[0] + 10, c[1] - 5, c[2] * 2, 2, PAPER)
	rect(0, GROUND, W, H - GROUND, W3)
	rect(0, GROUND, W, 1, W4)
	var ty := GROUND + 4
	while ty < H:
		var tx := 0 if ty % 24 != 0 else 8
		while tx < W:
			rect(tx + 2, ty, 4, 1, W4); rect(tx + 12, ty + 6, 3, 1, W2); tx += 22
		ty += 12

func shadow(x, y, w) -> void:
	rect(x + 1, y, w - 2, 1, W2); rect(x + 2, y + 1, w - 4, 1, W2)

func stall(x: int, ground_y: int, awn, keeper, goods: Callable) -> void:
	var top := ground_y - 58
	shadow(x - 2, ground_y, 70)
	spr(S.post, x + 2, top + 10); spr(S.post, x + 62, top + 10)
	spr(keeper, x + 24, ground_y - 40)
	spr(S.counter, x, ground_y - 17)
	goods.call(x, ground_y - 17)
	spr(awn, x - 6, top)

func bunting(x0: int, y0: int, x1: int, y1: int) -> void:
	var n := 0
	for x in range(x0, x1 + 1):
		var u := float(x - x0) / (x1 - x0)
		var y := roundi(y0 + (y1 - y0) * u + 14 * u * (1 - u))
		px(x, y, INK)
		if (x - x0) % 12 == 6:
			spr(S.flags[n % 4], x - 3, y); n += 1

func key_scene() -> void:
	backdrop()
	stall(14, 146, S.awning1, S.trader[0], func(x, y):
		spr(S.pot, x + 4, y - 8); spr(S.jar, x + 16, y - 7); spr(S.jar, x + 24, y - 7)
		spr(S.fruit, x + 44, y - 4); spr(S.pot, x + 52, y - 8))
	stall(234, 146, S.awning2, S.trader2[1], func(x, y):
		spr(S.rolls, x + 3, y - 5); spr(S.lantern, x + 18, y - 12); spr(S.rolls, x + 44, y - 5))
	bunting(86, 92, 228, 92)
	shadow(96, 146, 20); spr(S.crate, 96, 132); spr(S.crateSmall, 100, 120); spr(S.jar, 104, 113)
	shadow(121, 157, 34); spr(S.camel[0], 120, 130)
	shadow(208, 150, 12); spr(S.sack, 208, 140); spr(S.sack, 218, 142)
	shadow(187, 165, 14); spr(S.player[1], 186, 141)
	spr(S.crate, -6, 160); spr(S.crate, 300, 162); spr(S.sack, 12, 166)
	spr(S.arrow, 264, 90)
	chip("E TRADE", 251, 81, ACCENT)
	panel(4, 4, 52, 13); spr(S.coin, 7, 6); text("12,480", 17, 8, PAPER)
	panel(278, 4, 38, 13); spr(S.sun, 281, 7); text("DAY 3", 291, 8, PAPER)   # the sun high = noon

func _ready() -> void:
	var pal := Image.create_empty(16, 1, false, Image.FORMAT_RGBA8)
	for i in 16: pal.set_pixel(i, 0, Color(PALETTE[i]))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://palette.gdshader")
	mat.set_shader_parameter("palette", ImageTexture.create_from_image(pal))
	material = mat
	build_sprites()
	key_scene()
