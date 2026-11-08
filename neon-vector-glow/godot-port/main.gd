extends Node2D
## Port of neon-vector-glow/demo.html?frame=key-scene ("cold-core" palette), 720p logical units.
## Draw order as drawWorld() + drawHud(): void (clear colour), grid, world glow pass, void rims,
## danger glow pass, edge fade, HUD glow pass.

const P := {
	"void": "#05060C", "grid": "#172652", "player": "#33F0FF", "core": "#5CFFA8", "pickup": "#F0FF3D",
	"danger": "#FF2B3A", "enemy-seeker": "#FF3DD8", "enemy-splitter": "#FF8A1F", "enemy-warden": "#9A5CFF",
	"hud-ink": "#E6EEFF",
}
const BLOOM := {   # r: blur radius in 720p px; g: gain; s: working resolution
	"world":  [{"r": 2.0, "g": 1.2, "s": 1.0}, {"r": 7.0, "g": 1.8, "s": 0.5}, {"r": 24.0, "g": 3.2, "s": 0.25}],
	"danger": [{"r": 2.0, "g": 1.0, "s": 1.0}, {"r": 6.0, "g": 1.2, "s": 0.5}],
	"hud":    [{"r": 1.5, "g": 0.55, "s": 1.0}, {"r": 5.0, "g": 0.45, "s": 0.5}],
}
const W := 1280.0
const H := 720.0
var add_mat := CanvasItemMaterial.new()

func col(role: String) -> Color: return Color(P[role])
func whiter(c: Color, t: float) -> Color: return GlowPass.whiter(c, t)

# ------------------------------------------------------------------ seeded random (mulberry32)
var _seed := 7
func imul(x: int, y: int) -> int:
	return ((x & 0xFFFF) * y + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF
func rng() -> float:
	_seed = (_seed + 0x6D2B79F5) & 0xFFFFFFFF
	var t := imul(_seed ^ (_seed >> 15), 1 | _seed)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
func rr(a: float, b: float) -> float: return a + (b - a) * rng()

# ------------------------------------------------------------------ paths: arrays of {pts, closed}
func sub(pts: PackedVector2Array, closed := false) -> Dictionary: return {"pts": pts, "closed": closed}
func poly(pts: Array, closed := true) -> Dictionary: return sub(PackedVector2Array(pts), closed)
func arc(cx: float, cy: float, r: float, a0: float, a1: float) -> Dictionary:
	var full := absf(a1 - a0) >= TAU - 1e-6
	var n := maxi(8, int(ceil(absf(a1 - a0) * maxf(r, 4.0) / 3.0)))   # ~3 px chords
	var pts := PackedVector2Array()
	for i in (n if full else n + 1):
		var a := a0 + (a1 - a0) * i / n
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return sub(pts, full)
func seg(ax: float, ay: float, bx: float, by: float) -> Dictionary:
	return sub(PackedVector2Array([Vector2(ax, ay), Vector2(bx, by)]))

func shape(kind: String, r: float) -> Array:
	match kind:
		"player":
			return [poly([Vector2(r, 0), Vector2(-0.7 * r, 0.62 * r), Vector2(-0.32 * r, 0), Vector2(-0.7 * r, -0.62 * r)]), seg(-0.5 * r, 0, -0.95 * r, 0)]
		"seeker":
			var c := []
			for a in [0.0, 2.094, 4.189]: c.append(Vector2(cos(a) * r, sin(a) * r))
			var out := []
			for i in 3:
				var a: Vector2 = c[i]; var b: Vector2 = c[(i + 1) % 3]
				out.append(sub(PackedVector2Array([a.lerp(b, 0.18), a.lerp(b, 0.82)])))
			out.append(arc(0, 0, r * 0.12, 0, TAU))
			return out
		"splitter":
			var out := []
			for i in 3:
				var a := -PI / 2 + i * 2.094
				out.append(arc(cos(a) * r * 0.5, sin(a) * r * 0.5, r * 0.42, 0, TAU))
			return out
		"warden":
			return [poly([Vector2(-0.3 * r, -r), Vector2(-r, -r), Vector2(-r, r), Vector2(-0.3 * r, r)], false),
				poly([Vector2(0.3 * r, -r), Vector2(r, -r), Vector2(r, r), Vector2(0.3 * r, r)], false), seg(-0.4 * r, 0, 0.4 * r, 0)]
		"shard":
			return [arc(0, 0, r, 0, TAU), arc(0, 0, r * 0.25, 0, TAU)]
		"multiplier":
			var q := r * 0.45
			return [arc(0, 0, r, 0, TAU), seg(-q, -q, q, q), seg(q, -q, -q, q)]
		"shield":
			return [arc(0, 0, r, PI * 0.75, PI * 2.25), seg(r * 0.5, 0, -r * 0.5, 0), seg(0, -r * 0.5, 0, r * 0.5)]
	return []

func hexagon(r: float, rot: float) -> Array:
	var pts := []
	for i in 6:
		var a := rot + i * PI / 3
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return [poly(pts)]

## Plain fills on the main canvas, normal blend.
class Painter extends Node2D:
	var fn: Callable
	func _draw() -> void: fn.call(self)
func paint(fn: Callable) -> void:
	var p := Painter.new(); p.fn = fn; add_child(p)

func glow_pass(spec: Array, blur_lines := false) -> GlowPass:
	var g := GlowPass.new(); add_child(g); g.setup(spec, blur_lines)
	return g

# ------------------------------------------------------------------ the spring grid (exact port)
const GS := 40.0
const GC := 33   # W / GS + 1
const GR := 19   # H / GS + 1
const KA := 0.025
const KN := 0.06
const GD := 0.07
const GMAX := 0.6 * GS
var gpx := PackedFloat32Array(); var gpy := PackedFloat32Array(); var gvx := PackedFloat32Array(); var gvy := PackedFloat32Array()

func grid_reset() -> void:
	for a in [gpx, gpy, gvx, gvy]: a.resize(GC * GR)
	for y in GR:
		for x in GC:
			var i := y * GC + x
			gpx[i] = x * GS; gpy[i] = y * GS; gvx[i] = 0; gvy[i] = 0

func grid_impulse(x: float, y: float, strength: float, radius: float) -> void:
	for i in GC * GR:
		var dx := gpx[i] - x; var dy := gpy[i] - y; var d := sqrt(dx * dx + dy * dy)
		if d < radius and d > 0.001:
			var f := strength * pow(1 - d / radius, 2)
			gvx[i] += dx / d * f; gvy[i] += dy / d * f

func grid_step() -> void:
	for y in range(1, GR - 1):
		for x in range(1, GC - 1):
			var i := y * GC + x; var rx := x * GS; var ry := y * GS
			var fx := (rx - gpx[i]) * KA; var fy := (ry - gpy[i]) * KA
			var ox := gpx[i] - rx; var oy := gpy[i] - ry
			for j in [i - 1, i + 1, i - GC, i + GC]:
				var jx: int = j % GC; var jy: int = (j - jx) / GC
				fx += ((gpx[j] - jx * GS) - ox) * KN
				fy += ((gpy[j] - jy * GS) - oy) * KN
			gvx[i] = (gvx[i] + fx) * (1 - GD); gvy[i] = (gvy[i] + fy) * (1 - GD)
	for y in range(1, GR - 1):
		for x in range(1, GC - 1):
			var i := y * GC + x; var rx := x * GS; var ry := y * GS
			gpx[i] += gvx[i]; gpy[i] += gvy[i]
			var ox := gpx[i] - rx; var oy := gpy[i] - ry; var o := sqrt(ox * ox + oy * oy)
			if o > GMAX:
				gpx[i] = rx + ox / o * GMAX; gpy[i] = ry + oy / o * GMAX

func draw_grid(root: Node2D) -> void:
	var gc := col("grid")
	# Rest pass: one CanvasGroup per weight, so crossings don't stack alpha (one canvas stroke).
	for major in [false, true]:
		var g := CanvasGroup.new(); g.self_modulate.a = 1.0 if major else 0.55; root.add_child(g)
		var w := 1.5 if major else 1.0
		for y in GR:
			if (y % 4 == 0) == major:
				var pts := PackedVector2Array()
				for x in GC: pts.append(Vector2(gpx[y * GC + x], gpy[y * GC + x]))
				GlowPass.line(g, sub(pts), gc, w, null, Line2D.LINE_CAP_NONE, Line2D.LINE_JOINT_SHARP)
		for x in GC:
			if (x % 4 == 0) == major:
				var pts := PackedVector2Array()
				for y in GR: pts.append(Vector2(gpx[y * GC + x], gpy[y * GC + x]))
				GlowPass.line(g, sub(pts), gc, w, null, Line2D.LINE_CAP_NONE, Line2D.LINE_JOINT_SHARP)
	# Warp pass: displaced segments add the grid colour again.
	var warp := Node2D.new(); root.add_child(warp)
	var off := func(i: int) -> float: return Vector2(gpx[i] - (i % GC) * GS, gpy[i] - floor(i / GC) * GS).length()
	for y in GR:
		for x in GC:
			var i := y * GC + x
			for j in [i + 1 if x < GC - 1 else -1, i + GC if y < GR - 1 else -1]:
				if j < 0: continue
				var d: float = (off.call(i) + off.call(j)) / 2
				if d < 2: continue
				GlowPass.line(warp, seg(gpx[i], gpy[i], gpx[j], gpy[j]), Color(gc, minf(1, d / 14)), 1.5, add_mat, Line2D.LINE_CAP_NONE)

# ------------------------------------------------------------------ particles
var parts := []
func burst(x: float, y: float, c: Color, n: int, vmin: float, vmax: float, life: float) -> void:
	for i in n:
		var a := rr(0, TAU); var v := rr(vmin, vmax); var l := life * rr(0.6, 1)
		parts.append({"x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v, "life": l, "max": l, "col": c})
func step_parts(dt: float) -> void:
	var damp := pow(0.05, dt)
	for p in parts:
		p.x += p.vx * dt; p.y += p.vy * dt; p.vx *= damp; p.vy *= damp; p.life -= dt
	parts = parts.filter(func(p): return p.life > 0)

# ------------------------------------------------------------------ HUD text
## The demo's own font files (assets/fonts/ on the web), in the one weight the key scene uses.
var f_body: Font = load("res://fonts/OpenSans-Bold.woff")
var f_num: Font = load("res://fonts/CascadiaMono-Bold.woff")
var f_label := FontVariation.new()   # body font with 2 px tracking (ctx.letterSpacing = "2px")
## Glyphs are rasterised at the supersampled size (size x SS under a 1/SS transform), not scaled up.
## Tracked text (f_label) measures 2 px wider, as the canvas counts the spacing after the last letter.
func text(ci: CanvasItem, f: Font, s: String, x: float, y: float, size: int, alpha := 1.0, right := false) -> float:
	var ss := GlowPass.SS
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size * ss).x / ss
	if f == f_label: w += 2
	if right: x -= w
	ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE / ss)
	ci.draw_string(f, Vector2(x, y) * ss, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size * ss, Color(col("hud-ink"), alpha))
	ci.draw_set_transform(Vector2.ZERO)
	return w

# ------------------------------------------------------------------ key scene
func _ready() -> void:
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	f_label.base_font = f_body; f_label.spacing_glyph = 2 * GlowPass.SS

	grid_reset()
	var player := Vector2(470, 420); var pa := -0.32
	var pbul := []
	for i in 7:
		var d := 40 + i * 52; var a := pa + rr(-0.03, 0.03)
		pbul.append({"x": player.x + cos(a) * d, "y": player.y + sin(a) * d, "vx": cos(a) * 900, "vy": sin(a) * 900})
	grid_impulse(700, 520, 8, 160)
	burst(700, 520, col("enemy-seeker"), 40, 120, 420, 0.7)
	for i in 10:
		grid_step(); step_parts(1.0 / 60)
	grid_impulse(830, 300, 12, 220)
	burst(830, 300, col("enemy-splitter"), 110, 160, 560, 0.9)
	burst(830, 300, whiter(col("enemy-splitter"), 0.5), 20, 60, 200, 0.5)
	for i in 6:
		grid_step(); step_parts(1.0 / 60)

	# Void and grid on one antialiased layer (no bloom: the grid never glows).
	var ground := glow_pass([])
	ground.paint(func(ci: CanvasItem): ci.draw_rect(Rect2(0, 0, W, H), col("void")))
	draw_grid(ground.lines)

	# World pass: sparks, pickups, core, player shots, enemies, player, hazard.
	var world := glow_pass(BLOOM.world)
	for p in parts:
		world.spark(Vector2(p.x, p.y), Vector2(p.x - p.vx * 0.035, p.y - p.vy * 0.035), p.col, 0.8 * (p.life / p.max))
	for k in [["shard", 828, 340, 0.0], ["shard", 860, 300, 0.0], ["multiplier", 790, 286, 0.3], ["shard", 880, 360, 0.0], ["shield", 560, 300, 0.0]]:
		world.stroke(shape(k[0], 8), col("pickup"), 2, 0.55, Transform2D(k[3], Vector2(k[1], k[2])))
	var core_xf := Transform2D(0, Vector2(W / 2, H / 2 + 20)); var r := 46.0; var rot := 0.35
	world.stroke(hexagon(r, rot), col("core"), 2.5, 1, core_xf)
	world.stroke(hexagon(r * 0.55, rot + PI / 6), col("core"), 2, 1, core_xf)
	for i in 6:   # integrity arcs: 4 of 6 lit
		var a0 := -rot * 0.6 + i * PI / 3 + 0.12; var a1 := a0 + PI / 3 - 0.24
		if i < 4: world.stroke([arc(0, 0, r * 1.38, a0, a1)], col("core"), 2, 0.8, core_xf)
		else: world.plain([arc(0, 0, r * 1.38, a0, a1)], Color(col("core"), 0.25), 1.5, core_xf)
	var shots := []
	for b in pbul:
		var v := Vector2(b.vx, b.vy).length()
		shots.append(seg(b.x, b.y, b.x - b.vx / v * 14, b.y - b.vy / v * 14))
	world.stroke(shots, col("player"), 2.5, 0.8)
	for e in [["seeker", 905, 214, 17, PI * 0.85], ["seeker", 980, 470, 17, PI * 1.05], ["seeker", 300, 220, 17, 0.6],
			["seeker", 1110, 330, 17, PI], ["seeker", 640, 610, 17, -PI / 2], ["splitter", 745, 168, 22, 0.2],
			["splitter", 1040, 590, 22, 1.1], ["splitter", 220, 560, 22, 0.4], ["warden", 1130, 150, 21, 0.0], ["warden", 160, 330, 21, 0.0]]:
		world.stroke(shape(e[0], e[3]), col("enemy-" + e[0]), 2.5, 1, Transform2D(e[4], Vector2(e[1], e[2])))
	world.stroke(shape("player", 16), col("player"), 3, 1.3, Transform2D(pa, player))   # the widest halo
	# Hazard telegraph: dashed ring [12, 9], offset -t * 40, then a 6% fill growing with the telegraph.
	var hz := Vector2(1000, 470); var hr := 70.0; var ht := 0.9
	world.stroke(dashed_ring(hz, hr, 12, 9, -ht * 40), col("danger"), 2, 0.7)
	world.paint(func(ci: CanvasItem): ci.draw_circle(hz, hr * minf(1, ht / 1.5), Color(col("danger"), 0.06)))

	# Danger shots: a void rim cut into the finished bloom, then their own tighter pass.
	var ebul := [Vector2(1046, 186), Vector2(960, 228), Vector2(600, 470), Vector2(236, 360), Vector2(330, 392)]
	var rims := glow_pass([])
	rims.paint(func(ci: CanvasItem):
		for b in ebul: ci.draw_circle(b, 5 + 4, col("void")))
	var danger := glow_pass(BLOOM.danger)
	for b in ebul:
		danger.stroke([arc(b.x, b.y, 5, 0, TAU)], col("danger"), 2.5)
		danger.paint(func(ci: CanvasItem): ci.draw_circle(b, 5 * 0.45, whiter(col("danger"), 0.6)))

	# HUD: an edge fade (not a box), then text and life icons in a tight pass that blurs its own lines.
	paint(func(ci: CanvasItem):
		var v := col("void")
		ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 112), Vector2(0, 112)]),
			PackedColorArray([Color(v, 0.85), Color(v, 0.85), Color(v, 0), Color(v, 0)])))
	var hud := glow_pass(BLOOM.hud, true)
	hud.paint(func(ci: CanvasItem):
		var sw := text(ci, f_num, "1,284,350", 28, 56, 36)
		text(ci, f_num, "×24", 28 + sw + 16, 56, 24, 0.8)
		var ww := text(ci, f_num, "07", W - 28, 56, 36, 1.0, true)
		text(ci, f_label, "WAVE", W - 28 - ww - 12, 56, 16, 0.65, true))
	for i in 3:   # lives: the player's shape pointing up, a plain 2 px line
		hud.plain(shape("player", 9), col("player"), 2, Transform2D(-PI / 2, Vector2(38 + i * 26, 84)))

## A dashed ring as one open arc per dash. Phase at arc length s is fposmod(s + offset, on + off).
func dashed_ring(c: Vector2, r: float, on: float, off: float, offset: float) -> Array:
	var out := []
	var circ := TAU * r; var s := 0.0; var period := on + off
	while s < circ:
		var phase := fposmod(s + offset, period)
		var next := s + (on - phase if phase < on else period - phase)
		if phase < on: out.append(arc(c.x, c.y, r, s / r, minf(next, circ) / r))
		s = next
	return out
