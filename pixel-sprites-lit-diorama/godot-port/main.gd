extends Node3D
## Port of pixel-sprites-lit-diorama/demo.html?frame=key-scene (day palette, animation time 2.0 s).
## Geometry is built the way three.js builds it (same vertices, normals and UVs), so the toon bands
## and the world-unit texel grid land where the web frame has them.

const W := 1280.0
const H := 720.0
const T := 2.0
const P := {
	"sky": "#9CC8E8", "fog": "#C9DCE6", "key": "#FFF1D8", "fill-sky": "#CFE2F2", "fill-ground": "#8A7A66", "rim": "#FFFFFF",
	"glow-lamp": "#FFE2A8", "ground": "#B9A58A",
	"material-plaster": "#C8B8A0", "material-roof": "#B07052", "material-wood": "#8A6448", "material-stone": "#9A968C",
	"material-leaf": "#6E9450", "material-cloth": "#4F7FA8", "material-cloth2": "#BFA060",
	"outline": "#221C24", "tint": "#FFF6EA", "accent": "#19C2A0", "ink": "#F6F1E6", "plate": "#1C1820", "white": "#FFFFFF",
}
## The lighting scheme belongs to the palette (demo.html's "light" block).
const L := {"key": 2.8, "key_pos": Vector3(-9, 14, 7), "hemi": 1.25, "rim": 0.4, "rim_pos": Vector3(7, 9, -12),
	"fog": 0.0085, "grade": 0.15, "vignette": 0.35, "shafts": 0.025, "mist": 0.05}
const KEY_TARGET := Vector3(0, 0, -1)
const HOME_POS := Vector3(-1.4, 6.0, 12.8)
const HOME_LOOK := Vector3(0.4, 0.2, -3.0)
# sprites: 32 x 48, feet on row 46, 1.8 m tall
const CW := 32
const CH := 48
const FEET := 46
const PX := 1.8 / CH
const TILE := {"floor": 4.0, "roof": 2.4, "plaster": 8.0, "wood": 2.0}   # world units one value map covers

var S_TOON := preload("res://shaders/toon.gdshader")
var S_TOON2 := preload("res://shaders/toon_double.gdshader")
var S_CUT := preload("res://shaders/toon_cutout.gdshader")
var S_SPRITE := preload("res://shaders/sprite.gdshader")
var S_UNLIT := preload("res://shaders/unlit.gdshader")
var S_BLOB := preload("res://shaders/blob.gdshader")
var S_ADD := preload("res://shaders/additive.gdshader")
var S_MIST := preload("res://shaders/mist.gdshader")

# ------------------------------------------------------------------ helpers
class Rng:   # mulberry32, as the web demo seeds it
	var s: int
	func _init(seed_value: int) -> void: s = seed_value & 0xFFFFFFFF
	static func imul(x: int, y: int) -> int:
		return ((x & 0xFFFF) * y + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF
	func next() -> float:
		s = (s + 0x6D2B79F5) & 0xFFFFFFFF
		var t := imul(s ^ (s >> 15), 1 | s)
		t = ((t + imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

class Geo:   # three.js-style geometry: CCW triangles, UV v up
	var v := []
	var n := []
	var uv := []
	var i := []

var rnd := Rng.new(20261107)
func col(role: String) -> Color: return Color(P[role])
func lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)
## three.js Color(a).lerp(Color(b), t).getHexString(): mixed in linear, stored as 8-bit sRGB
func srgb(v: Vector3) -> Color: return Color(v.x, v.y, v.z).linear_to_srgb()   # for source_color uniforms
func hex_mix(a: Color, b: Color, t: float) -> Color:
	var m := a.srgb_to_linear().lerp(b.srgb_to_linear(), t).linear_to_srgb()
	return Color8(roundi(m.r * 255), roundi(m.g * 255), roundi(m.b * 255))

func to_mesh(g: Geo, lines := false) -> ArrayMesh:
	var a := []; a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array(g.v)
	if not lines:
		a[Mesh.ARRAY_NORMAL] = PackedVector3Array(g.n)
		var uv := PackedVector2Array()
		for t in g.uv: uv.append(Vector2(t.x, 1.0 - t.y))   # three.js v runs up, Godot's down
		a[Mesh.ARRAY_TEX_UV] = uv
		var idx := PackedInt32Array()
		for k in range(0, g.i.size(), 3): idx.append_array([g.i[k], g.i[k + 2], g.i[k + 1]])   # CCW -> Godot's CW
		a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP if lines else Mesh.PRIMITIVE_TRIANGLES, a)
	return m

# ------------------------------------------------------------------ three.js geometries
func _plane(g: Geo, u: int, v: int, w: int, udir: float, vdir: float, width: float, height: float, depth: float) -> void:
	var s := g.v.size()
	for iy in 2:
		for ix in 2:
			var p := Vector3(); p[u] = (ix * width - width / 2) * udir; p[v] = (iy * height - height / 2) * vdir; p[w] = depth / 2
			var nn := Vector3(); nn[w] = 1.0 if depth > 0 else -1.0
			g.v.append(p); g.n.append(nn); g.uv.append(Vector2(ix, 1 - iy))
	g.i.append_array([s, s + 2, s + 1, s + 2, s + 3, s + 1])

func box_geo(w: float, h: float, d: float) -> Geo:
	var g := Geo.new()
	_plane(g, 2, 1, 0, -1, -1, d, h, w); _plane(g, 2, 1, 0, 1, -1, d, h, -w)
	_plane(g, 0, 2, 1, 1, 1, w, d, h); _plane(g, 0, 2, 1, 1, -1, w, d, -h)
	_plane(g, 0, 1, 2, 1, -1, w, h, d); _plane(g, 0, 1, 2, -1, -1, w, h, -d)
	return g

## box UVs in world units, so every face shows the map at one texel size whatever the box's size
func world_uv(g: Geo, tile: float, o: Vector3) -> void:
	for k in g.v.size():
		var p: Vector3 = g.v[k] + o; var nn: Vector3 = g.n[k]
		if absf(nn.x) > 0.5: g.uv[k] = Vector2(p.z, p.y) / tile
		elif absf(nn.y) > 0.5: g.uv[k] = Vector2(p.x, p.z) / tile
		else: g.uv[k] = Vector2(p.x, p.y) / tile

func plane_geo(w: float, h: float, dy := 0.0) -> Geo:
	var g := Geo.new()
	for iy in 2:
		for ix in 2:
			g.v.append(Vector3(ix * w - w / 2, -(iy * h - h / 2) + dy, 0)); g.n.append(Vector3(0, 0, 1)); g.uv.append(Vector2(ix, 1 - iy))
	g.i.append_array([0, 2, 1, 2, 3, 1])
	return g

func cyl_geo(rt: float, rb: float, h: float, rs: int, open_ended := false, ts := 0.0, tl := TAU) -> Geo:
	var g := Geo.new(); var hh := h / 2; var slope := (rb - rt) / h
	var rows := []
	for y in 2:
		var row := []; var r := y * (rb - rt) + rt
		for x in rs + 1:
			var u := float(x) / rs; var th := u * tl + ts
			row.append(g.v.size())
			g.v.append(Vector3(r * sin(th), -y * h + hh, r * cos(th)))
			g.n.append(Vector3(sin(th), slope, cos(th)).normalized()); g.uv.append(Vector2(u, 1 - y))
		rows.append(row)
	for x in rs:
		var a: int = rows[0][x]; var b: int = rows[1][x]; var c: int = rows[1][x + 1]; var d: int = rows[0][x + 1]
		if rt > 0: g.i.append_array([a, b, d])
		if rb > 0: g.i.append_array([b, c, d])
	if not open_ended:
		for top in [true, false]:
			var r := rt if top else rb
			if r <= 0: continue
			var sg := 1.0 if top else -1.0; var c0 := g.v.size()
			for x in rs:
				g.v.append(Vector3(0, hh * sg, 0)); g.n.append(Vector3(0, sg, 0)); g.uv.append(Vector2(0.5, 0.5))
			var c1 := g.v.size()
			for x in rs + 1:
				var th := float(x) / rs * tl + ts
				g.v.append(Vector3(r * sin(th), hh * sg, r * cos(th))); g.n.append(Vector3(0, sg, 0))
				g.uv.append(Vector2(cos(th) * 0.5 + 0.5, sin(th) * 0.5 * sg + 0.5))
			for x in rs:
				if top: g.i.append_array([c1 + x, c1 + x + 1, c0 + x])
				else: g.i.append_array([c1 + x + 1, c1 + x, c0 + x])
	return g

func icosa_geo(r: float, detail := 0) -> Geo:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var vs := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var ix := [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var tris := []
	var cols := detail + 1
	for f in range(0, ix.size(), 3):   # three.js PolyhedronGeometry.subdivideFace
		var a: Vector3 = vs[ix[f]]; var b: Vector3 = vs[ix[f + 1]]; var c: Vector3 = vs[ix[f + 2]]
		var grid := []
		for i in cols + 1:
			var aj := a.lerp(c, float(i) / cols); var bj := b.lerp(c, float(i) / cols); var rows := cols - i
			var row := []
			for j in rows + 1: row.append(aj if (j == 0 and i == cols) else aj.lerp(bj, float(j) / rows))
			grid.append(row)
		for i in cols:
			for j in 2 * (cols - i) - 1:
				var k := j / 2
				if j % 2 == 0: tris.append_array([grid[i][k + 1], grid[i + 1][k], grid[i][k]])
				else: tris.append_array([grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]])
	var g := Geo.new()
	for k in range(0, tris.size(), 3):
		var p := [tris[k].normalized() * r, tris[k + 1].normalized() * r, tris[k + 2].normalized() * r]
		var fn: Vector3 = (p[2] - p[1]).cross(p[0] - p[1]).normalized()
		for q in 3:
			var v: Vector3 = p[q]
			g.v.append(v); g.n.append(fn if detail == 0 else v.normalized())
			g.uv.append(Vector2(atan2(v.z, -v.x) / TAU + 0.5, atan2(-v.y, Vector2(v.x, v.z).length()) / PI + 0.5))
			g.i.append(g.v.size() - 1)
	return g

func ring_geo(ri: float, ro: float, segs: int) -> Geo:   # RingGeometry, rotated flat
	var g := Geo.new()
	for j in 2:
		var r := ri + j * (ro - ri)
		for i in segs + 1:
			var th := float(i) / segs * TAU
			g.v.append(Vector3(r * cos(th), 0, -r * sin(th))); g.n.append(Vector3.UP); g.uv.append(Vector2(0, 0))
	for i in segs:
		var a := i; var b := i + segs + 1; var c := i + segs + 2; var d := i + 1
		g.i.append_array([a, b, d, b, c, d])
	return g

# ------------------------------------------------------------------ textures drawn in code
## brushy grain: short pale strokes on white (canvas fillRect at 35% over the last result)
func grain_image(seed_value: int, w := 128, h := 128, n := 900) -> Image:
	var r := Rng.new(seed_value)
	var buf := PackedFloat32Array(); buf.resize(w * h); buf.fill(255.0)
	for k in n:
		var g := 196 + int(r.next() * 59)
		var x0 := int(r.next() * w); var y0 := int(r.next() * h); var rw := 4 + int(r.next() * 18); var rh := 1 + int(r.next() * 2)
		for y in range(y0, mini(y0 + rh, h)):
			for x in range(x0, mini(x0 + rw, w)):
				buf[y * w + x] = roundf(buf[y * w + x] * 0.65 + g * 0.35)
	var bytes := PackedByteArray(); bytes.resize(w * h * 3)
	for k in w * h:
		var b := int(buf[k]); bytes[k * 3] = b; bytes[k * 3 + 1] = b; bytes[k * 3 + 2] = b
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, bytes)

func tex_from(img: Image, mipmaps := true) -> ImageTexture:
	if mipmaps: img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## awning stripes in two set roles, grain multiplied on top
func awning_image(a: String, b: String) -> Image:
	var grain := grain_image(3, 128, 64, 400)
	var img := Image.create(128, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 128:
			var c := col(b if (x / 16) % 2 == 1 else a); var gv := grain.get_pixel(x, y).r8
			img.set_pixel(x, y, Color8(roundi(c.r8 * gv / 255.0), roundi(c.g8 * gv / 255.0), roundi(c.b8 * gv / 255.0)))
	return img

## the painted backdrop: gradient sky, a halo round the key, 70 brushy cloud strokes, two layers of far
## hills, fog below the horizon. Composited in sRGB like a 2D canvas.
var sky_buf := PackedFloat32Array()
func _blend(x: int, y: int, c: Color, a: float) -> void:
	var k := (y * 1024 + x) * 3
	sky_buf[k] = sky_buf[k] * (1 - a) + c.r * a; sky_buf[k + 1] = sky_buf[k + 1] * (1 - a) + c.g * a; sky_buf[k + 2] = sky_buf[k + 2] * (1 - a) + c.b * a

func sky_image() -> Image:
	var w := 1024; var h := 512; var hz := h * 0.58
	sky_buf.resize(w * h * 3)
	var sky := col("sky"); var fogc := col("fog"); var key := col("key")
	var low := hex_mix(sky, fogc, 0.85)
	for y in h:
		var c := sky.lerp(low, clampf((y + 0.5) / hz, 0, 1))
		for x in w:
			var k := (y * w + x) * 3; sky_buf[k] = c.r; sky_buf[k + 1] = c.g; sky_buf[k + 2] = c.b
	var hot := hex_mix(key, Color.WHITE, 0.3)
	for y in range(50, 250):
		for x in range(540, 740):
			var om := (Vector2(x + 0.5 - 640, y + 0.5 - 150).length() - 4.0) / 86.0
			if om > 1.0: continue
			om = maxf(om, 0.0)
			if om < 0.18: _blend(x, y, hot.lerp(key, om / 0.18), 0.85)
			else: _blend(x, y, key, 0.85 * (1.0 - (om - 0.18) / 0.82))
	var r := Rng.new(5)
	var cloud := hex_mix(sky, fogc, 0.7)
	for n in 70:
		var ga := 0.12 + r.next() * 0.18
		var c := hex_mix(cloud, key, r.next() * 0.35)
		var cx := r.next() * w; var cy := 40 + r.next() * (hz - 120); var rx := 30 + r.next() * 90; var ry := 5 + r.next() * 9
		for y in range(maxi(0, floori(cy - ry - 1)), mini(h, ceili(cy + ry + 1))):
			for x in range(maxi(0, floori(cx - rx - 1)), mini(w, ceili(cx + rx + 1))):
				var dx := (x + 0.5 - cx) / rx; var dy := (y + 0.5 - cy) / ry; var q := sqrt(dx * dx + dy * dy)
				var grad := sqrt(dx * dx / (rx * rx) + dy * dy / (ry * ry)) / maxf(q, 1e-4)
				var cov := clampf(0.5 - (q - 1.0) / maxf(grad, 1e-4), 0, 1)
				if cov > 0: _blend(x, y, c, ga * cov)
	for layer in [[0.006, 46.0, hex_mix(fogc, sky, 0.35)], [0.011, 30.0, hex_mix(fogc, col("outline"), 0.12)]]:
		var k: float = layer[0]; var amp: float = layer[1]; var c: Color = layer[2]
		var knots := []
		for i in range(0, w + 1, 8): knots.append(hz - amp * (0.55 + 0.45 * sin(i * k + amp) * sin(i * k * 2.3)))
		for x in w:
			var xc := x + 0.5; var s := int(xc / 8.0)
			var top: float = lerpf(knots[s], knots[s + 1], (xc - s * 8) / 8.0)
			for y in range(maxi(0, floori(top)), h): _blend(x, y, c, clampf(y + 1 - top, 0, 1))
	for y in range(int(hz), h):
		for x in w: _blend(x, y, fogc, clampf(y + 1 - hz, 0, 1))
	var bytes := PackedByteArray(); bytes.resize(w * h * 3)
	for k in w * h * 3: bytes[k] = clampi(roundi(sky_buf[k] * 255.0), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, bytes)

# ------------------------------------------------------------------ materials
var grain_tex: ImageTexture
var TEX := {}
var mats := {}

func light_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("key_linear", lin(col("key")) * L.key / PI)
	m.set_shader_parameter("rim_linear", lin(col("rim")) * L.rim / PI)
	m.set_shader_parameter("rim_dir", (L.rim_pos - KEY_TARGET).normalized())
	m.set_shader_parameter("sky_linear", lin(col("fill-sky")) * L.hemi / PI)
	m.set_shader_parameter("ground_linear", lin(col("fill-ground")) * L.hemi / PI)
	var z: Vector3 = (L.key_pos).normalized()   # the shadow camera looks from key_pos + target at the target
	var x := Vector3.UP.cross(z).normalized(); var y := z.cross(x)
	m.set_shader_parameter("shadow_center", KEY_TARGET); m.set_shader_parameter("shadow_x", x); m.set_shader_parameter("shadow_y", y)
	m.set_shader_parameter("fog_linear", lin(col("fog")))
	fog_params(m)

func fog_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("fog_color", col("fog")); m.set_shader_parameter("fog_density", L.fog)

## toon paint: role colour x a map (grain, a tiling value map, or pixel art), 4-step light
func paint(role: String, map = null, key := "", shader: Shader = null) -> ShaderMaterial:
	if key == "": key = role
	if mats.has(key): return mats[key]
	var m := ShaderMaterial.new(); m.shader = shader if shader else S_TOON
	m.set_shader_parameter("albedo", col(role))
	if map == null:
		m.set_shader_parameter("grain_map", grain_tex)
	elif map is String:   # a value map by name
		m.set_shader_parameter("map_kind", 1); m.set_shader_parameter("value_map", TEX[map]); m.set_meta("tile", TILE[map])
	else:
		m.set_shader_parameter("map_kind", 2); m.set_shader_parameter("pixel_map", map)
	light_params(m)
	mats[key] = m
	return m
func M(r: String) -> ShaderMaterial: return paint("material-" + r)
const SURF := {"plaster": "plaster", "stone": "plaster", "wood": "wood", "roof": "roof"}
func MT(r: String) -> ShaderMaterial: return paint("material-" + r, SURF[r], "tex-" + r)

func flat(shader: Shader, c: Color, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = shader
	m.set_shader_parameter("color", c); fog_params(m)
	for k in extra: m.set_shader_parameter(k, extra[k])
	return m

# ------------------------------------------------------------------ scene helpers
var world: Node3D
func mesh(g: Geo, m: Material, x: float, y: float, z: float, parent: Node3D = null, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = to_mesh(g); mi.material_override = m
	mi.position = Vector3(x, y, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else world).add_child(mi)
	return mi

func box(w: float, h: float, d: float, m: ShaderMaterial, x: float, y: float, z: float, parent: Node3D = null) -> MeshInstance3D:
	var g := box_geo(w, h, d)
	if m.has_meta("tile"): world_uv(g, m.get_meta("tile"), Vector3(x, y + h / 2, z))
	return mesh(g, m, x, y + h / 2, z, parent)

var blob_quad: ArrayMesh
func blob(x: float, z: float, r: float, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = blob_quad
	mi.material_override = flat(S_BLOB, col("outline"))
	mi.position = Vector3(x, 0.012, z); mi.scale = Vector3(r, 1, r)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else world).add_child(mi)
	return mi

func lamp(x: float, y: float, z: float) -> void:
	var g := Node3D.new(); g.position = Vector3(x, y, z); world.add_child(g)
	box(0.05, 0.25, 0.05, M("wood"), 0, 0.18, 0, g)
	box(0.34, 0.06, 0.34, M("wood"), 0, 0.16, 0, g).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh(icosa_geo(0.16), flat(S_UNLIT, srgb(lin(col("glow-lamp")) * 0.8)), 0, 0, 0, g, false)   # unlit core (dim by day)

var stalls := {}
func stall(id: String, x: float, z: float, stripe_a: String, stripe_b: String, goods: Callable) -> void:
	var g := Node3D.new(); g.position = Vector3(x, 0, z); world.add_child(g)
	box(2.4, 0.95, 0.9, MT("wood"), 0, 0, 0, g)
	box(2.56, 0.08, 1.02, MT("wood"), 0, 0.95, 0, g)
	for sx in [-1.15, 1.15]:
		box(0.1, 2.5, 0.1, MT("wood"), sx, 0, -0.42, g); box(0.1, 2.05, 0.1, MT("wood"), sx, 0, 0.42, g)
	var aw := mesh(plane_geo(2.9, 1.6), paint("white", tex_from(awning_image(stripe_a, stripe_b)), "awning-" + id, S_TOON2), 0, 2.3, 0.1, g)
	aw.rotation.x = -PI / 2 + 0.45
	goods.call(g)
	# the painted sign board on the counter's front (generated pixel art), no mipmaps
	var sign_tex: Texture2D = load("res://assets/signs/%s.png" % id)
	mesh(plane_geo(1.2, 0.6), paint("white", sign_tex, "sign-" + id, S_CUT), 0, 0.5, 0.46, g, false)
	blob(0, 0, 1.6, g).scale = Vector3(1.6, 1, 1.6 * 0.55)
	stalls[id] = {"g": g, "anchor": Vector3(x, 2.95, z)}

func fruit(g: Node3D, role: String, n: int, y := 1.12) -> void:
	for i in n:
		mesh(icosa_geo(0.12), M(role), -0.95 + (i % 9) * 0.24, y + (i / 9) * 0.05, 0.25 - (i / 9) * 0.26, g)

func bunting(a: Vector3, b: Vector3, sag: float, n: int, roles: Array) -> void:
	var pts := []
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) + Vector3(0, -sag * 4 * t * (1 - t), 0))
	var lg := Geo.new(); lg.v = pts
	var line := MeshInstance3D.new(); line.mesh = to_mesh(lg, true); line.material_override = flat(S_UNLIT, col("outline"))
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; world.add_child(line)
	for i in n:
		var p0: Vector3 = pts[i]; var p1: Vector3 = pts[i + 1]; var mid := p0.lerp(p1, 0.5)
		var A := p0.lerp(mid, 0.15); var B := p1.lerp(mid, 0.15); var C := mid + Vector3(0, -0.34, 0.02)
		var fn := (C - B).cross(A - B).normalized()
		var g := Geo.new(); g.v = [A, B, C]; g.n = [fn, fn, fn]; g.uv = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]; g.i = [0, 1, 2]
		var role: String = roles[i % roles.size()]
		var m := paint("material-" + role, null, "flag-" + role, S_TOON2)
		m.set_shader_parameter("grain_corner", true)   # no UVs in the web demo: one grain texel
		mesh(g, m, 0, 0, 0)

func planter(x: float, z: float, w: float, d: float) -> void:
	box(w, 0.55, d, MT("wood"), x, 0, z)
	var r := maxf(w, d) * 0.62
	blob(x, z, r).scale = Vector3(r * (1.0 if w > d else 0.5), 1, r * (0.5 if w > d else 1.0))
	var n := roundi(maxf(w, d) / 0.55)
	for i in n:
		var t := (i + 0.5) / n - 0.5
		var leaf := mesh(icosa_geo(0.32 + rnd.next() * 0.08), M("leaf"), x + (t * w if w > d else 0.0), 0.72, z + (0.0 if w > d else t * d))
		leaf.scale = Vector3(1, 0.75, 1)

func tree(x: float, z: float, s := 1.0) -> void:
	mesh(cyl_geo(0.38 * s, 0.3 * s, 0.6 * s, 8), M("roof"), x, 0.3 * s, z)
	mesh(cyl_geo(0.07, 0.09, 1.2 * s, 6), M("wood"), x, 0.9 * s, z)
	mesh(icosa_geo(0.85 * s), M("leaf"), x, 1.85 * s, z).scale = Vector3(1, 0.85, 1)
	blob(x, z, 0.9 * s)

## a 4-sided roof whose UVs run in world units: tiles across, rows up the slope
func roof_cone(r: float, h: float) -> Geo:
	var g := cyl_geo(0, r, h, 4)
	var around := 4 * r * sqrt(2.0); var up := Vector2(h, r * 0.71).length()
	for k in g.uv.size(): g.uv[k] = Vector2(g.uv[k].x * around / TILE.roof, g.uv[k].y * up / TILE.roof)
	return g

# ------------------------------------------------------------------ the cast
var people := {}
var cam: Camera3D
func first_row(img: Image) -> int:
	for y in CH:
		for x in CW:
			if img.get_pixel(x, y).a > 0.5: return y
	return 0

func person(id: String, x: float, z: float, face := 1.0) -> void:
	var tex: Texture2D = load("res://assets/sprites/%s.png" % id)
	var m := ShaderMaterial.new(); m.shader = S_SPRITE
	m.set_shader_parameter("tex", tex); m.set_shader_parameter("tint", col("tint")); fog_params(m)
	var g := plane_geo(CW * PX, CH * PX, (CH / 2.0 - (CH - FEET - 1)) * PX)   # the feet row stands on the floor
	var mi := mesh(g, m, x, 0, z, null, false)
	mi.scale.x = face
	mi.rotation.y = atan2(HOME_POS.x - x, HOME_POS.z - z)   # yaw-only billboard (fixed stage camera)
	blob(x, z, 0.42)
	var top := first_row(tex.get_image())
	people[id] = {"id": id, "x": x, "z": z, "mi": mi, "top": top, "anchor": Vector3(x, (FEET + 1 - top) * PX, z)}

# ------------------------------------------------------------------ build
func _ready() -> void:
	grain_tex = tex_from(grain_image(7))
	for k in [["floor", "floor-tiles"], ["roof", "roof-tiles"], ["plaster", "plaster"], ["wood", "wood-planks"]]:
		TEX[k[0]] = load("res://assets/textures/%s.png" % k[1])
	var bq := Geo.new()   # unit disc as a quad on the floor; the shader cuts the radial falloff
	for iz in 2:
		for ix in 2:
			bq.v.append(Vector3(ix * 2 - 1, 0, iz * 2 - 1)); bq.n.append(Vector3.UP); bq.uv.append(Vector2(ix, 1 - iz))
	bq.i = [0, 2, 1, 2, 3, 1]
	blob_quad = to_mesh(bq)
	world = Node3D.new(); add_child(world)

	box(15, 0.3, 10, paint("ground", "floor", "ground-tiles"), 0, -0.3, -0.5)     # the terrace floor
	box(15.2, 8, 10.2, MT("plaster"), 0, -8.3, -0.5)                               # the building under it
	for y in [-2.6, -5.6]:
		var x := -6.0
		while x <= 6.01:
			box(0.8, 1.1, 0.06, paint("outline"), x, y, 4.62); x += 2.4
	box(15, 0.6, 0.3, MT("plaster"), 0, 0, -5.35)                                 # parapet, back and sides
	for sx in [-7.35, 7.35]: box(0.3, 0.6, 9.7, MT("plaster"), sx, 0, -0.5)

	stall("seed", -4.4, -3.3, "material-cloth2", "material-plaster", func(g: Node3D) -> void:
		for i in 4: box(0.42, 0.24, 0.42, MT("wood"), -0.8 + i * 0.53, 0.99, 0.05, g)
		for i in 3: mesh(icosa_geo(0.34, 1), M("cloth2"), -1.6 + i * 0.4, 0.26, 0.8 + (i % 2) * 0.2, g).scale = Vector3(1, 0.75, 1))
	stall("fig", 0.3, -3.3, "material-cloth", "material-plaster", func(g: Node3D) -> void:
		fruit(g, "roof", 18); fruit(g, "cloth2", 6, 1.2))
	stall("herb", 4.8, -3.3, "material-leaf", "material-plaster", func(g: Node3D) -> void:
		for i in 5:
			box(0.3, 0.2, 0.3, M("roof"), -0.9 + i * 0.45, 0.99, 0.1, g)
			mesh(icosa_geo(0.2), M("leaf"), -0.9 + i * 0.45, 1.36, 0.1, g))
	lamp(1.55, 1.85, -2.75)
	box(0.06, 0.06, 0.4, M("wood"), 1.45, 2.05, -2.8)
	lamp(-5.7, 1.7, -2.75); lamp(6.1, 1.7, -2.75)

	for x in [-7.15, 7.15]: box(0.12, 3.3, 0.12, MT("wood"), x, 0, -5.2)
	box(0.12, 3.0, 0.12, MT("wood"), -2.05, 0, -5.2); box(0.12, 3.0, 0.12, MT("wood"), 2.55, 0, -5.2)
	var flags := ["cloth", "cloth2", "roof", "plaster", "leaf"]
	bunting(Vector3(-7.15, 3.25, -5.2), Vector3(-2.05, 2.95, -5.2), 0.35, 11, flags)
	bunting(Vector3(-2.05, 2.95, -5.2), Vector3(2.55, 2.95, -5.2), 0.3, 10, flags.slice(2) + flags.slice(0, 2))
	bunting(Vector3(2.55, 2.95, -5.2), Vector3(7.15, 3.25, -5.2), 0.35, 11, flags)

	planter(-6.5, 1.6, 0.6, 3.0); planter(6.5, 1.6, 0.6, 3.0); planter(-1.4, 3.7, 1.8, 0.55)
	tree(-6.2, -4.7); tree(6.3, -4.7, 1.1); tree(6.0, 3.6, 0.8)
	box(0.5, 0.5, 0.5, MT("wood"), -2.1, 0, -2.5); box(0.38, 0.38, 0.38, MT("wood"), -2.05, 0.5, -2.5).rotation.y = 0.5
	box(0.5, 0.5, 0.5, MT("wood"), 2.9, 0, -2.3).rotation.y = -0.3; blob(-2.1, -2.5, 0.5); blob(2.9, -2.3, 0.5)
	box(1.7, 0.42, 0.5, MT("wood"), -2.6, 0, 1.9); blob(-2.6, 1.9, 1.0).scale = Vector3(1.0, 1, 0.45)

	# the hill town falling away behind and beside the terrace (same seeded draws as the web demo)
	var town := Node3D.new(); world.add_child(town)
	for row in 4:
		var z := -9.5 - row * 6.5; var base := -4 - row * 3.6
		var x := -26 + rnd.next() * 3
		while x < 26:
			var w := 3 + rnd.next() * 1.6; var d := 3.4 + rnd.next() * 1.4; var h := 3.2 + rnd.next() * 2.4
			var walls := MT("plaster") if rnd.next() < 0.7 else MT("stone")
			var zz := z + rnd.next() * 1.5
			box(w, h, d, walls, x, base, zz, town)
			var roof := mesh(roof_cone(maxf(w, d) * 0.74, 1.4 + rnd.next() * 0.6), MT("roof"), x, base + h + 0.75, zz, town)
			roof.rotation.y = PI / 4; roof.scale = Vector3(w / maxf(w, d), 1, d / maxf(w, d))
			x += 4.2 + rnd.next() * 2
	for side in [-1, 1]:
		for i in 4:
			var x: float = side * (11 + i * 4.5 + rnd.next() * 1.5); var z := -3 + rnd.next() * 7; var base := -9 - i * 1.5; var h := 6 + rnd.next() * 2
			box(3.6, h, 3.8, MT("plaster"), x, base, z, town)
			mesh(roof_cone(2.7, 1.6), MT("roof"), x, base + h + 0.8, z, town).rotation.y = PI / 4

	# the animated banded valley surface
	var valley := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(320, 180)
	pm.subdivide_width = 199; pm.subdivide_depth = 109; valley.mesh = pm
	var vm := ShaderMaterial.new(); vm.shader = preload("res://shaders/valley.gdshader")
	var leaf := col("material-leaf").srgb_to_linear().lerp(col("ground").srgb_to_linear(), 0.25)
	vm.set_shader_parameter("time", T)
	vm.set_shader_parameter("base_color", leaf.linear_to_srgb())
	vm.set_shader_parameter("crest_color", hex_mix(col("material-leaf"), col("fog"), 0.55))
	vm.set_shader_parameter("key_dir", (L.key_pos as Vector3).normalized())
	vm.set_shader_parameter("key_color", srgb(lin(col("key")) * L.key / PI))
	vm.set_shader_parameter("fill_color", srgb(lin(col("fill-sky")) * L.hemi / PI))
	vm.set_shader_parameter("fog_color", col("fog")); vm.set_shader_parameter("density", L.fog)
	valley.material_override = vm; valley.position = Vector3(0, -20, -80)
	valley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(valley)

	# painted backdrop on a far open cylinder
	var bm := ShaderMaterial.new(); bm.shader = preload("res://shaders/backdrop.gdshader")
	bm.set_shader_parameter("sky", tex_from(sky_image()))
	var backdrop := MeshInstance3D.new(); backdrop.mesh = to_mesh(cyl_geo(190, 190, 160, 48, true, PI - 1.25, 2.5))
	backdrop.material_override = bm; backdrop.position = Vector3(0, 20, 0)
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(backdrop)

	# light shafts and drifting mist
	for i in 4:
		var s := mesh(plane_geo(2.2 + i * 0.6, 40), flat(preload("res://shaders/shaft.gdshader"), col("key"), {"opacity": L.shafts}),
			-9 + i * 5.5, 4, -14 - i * 2, self, false)
		s.rotation.z = 0.42
	var mist_geo := plane_geo(1, 1)
	for i in 18:
		var x := -24 + rnd.next() * 48; var y := -6 + rnd.next() * 5; var z := -8 - rnd.next() * 30
		var sc := 9 + rnd.next() * 7; var ph := rnd.next() * 6
		var s := mesh(mist_geo, flat(S_MIST, col("fog"), {"opacity": L.mist}), x + sin(T * 0.05 + ph) * 2, y, z, self, false)
		s.scale = Vector3(sc, sc, sc)

	person("vendor", 0.0, -3.95); person("shopper", 1.2, -1.7, -1); person("elder", -4.6, 0.6); person("kid", 3.4, 1.4, -1)
	ring = mesh(ring_geo(0.5, 0.64, 48), flat(S_ADD, col("accent")), 0, 0.02, 0, world, false)
	build_env()
	build_post()
	build_captions()
	select("shopper")

var ring: MeshInstance3D
func build_env() -> void:
	var key := DirectionalLight3D.new()
	key.light_color = col("key")
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 40.0
	key.shadow_bias = 0.02; key.shadow_normal_bias = 1.0; key.shadow_blur = 1.0
	add_child(key)
	key.look_at_from_position(L.key_pos + KEY_TARGET, KEY_TARGET)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = col("fog")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR   # black: the toon shader adds the fill
	env.ambient_light_color = Color.BLACK; env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR             # palette colours land as authored
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)

	cam = Camera3D.new(); cam.fov = 46; cam.near = 0.3; cam.far = 600
	add_child(cam); cam.look_at_from_position(HOME_POS, HOME_LOOK); cam.current = true

## post: tilt-shift (horizontal, vertical), then the grade, each reading the screen
func build_post() -> void:
	var layer := CanvasLayer.new(); layer.layer = 1; add_child(layer)
	var passes := [["tilt", {"step_uv": Vector2(2.4 / W, 0), "focus": 0.40}], ["tilt", {"step_uv": Vector2(0, 2.4 / H), "focus": 0.40}],
		["grade", {"tint": grade_tint(), "amount": L.grade, "vignette": L.vignette, "time": 0.0}]]
	for k in passes.size():
		if k > 0:
			var bb := BackBufferCopy.new(); bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT; layer.add_child(bb)
		var rect := ColorRect.new(); rect.set_anchors_preset(Control.PRESET_FULL_RECT); rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new(); m.shader = load("res://shaders/%s.gdshader" % passes[k][0])
		for p in passes[k][1]: m.set_shader_parameter(p, passes[k][1][p])
		rect.material = m; layer.add_child(rect)

func grade_tint() -> Vector3:
	var f := lin(col("fill-ground")); return f / maxf(f.x, maxf(f.y, f.z))

# ------------------------------------------------------------------ captions: live text placed by the recipe's layout
const CAPS := {
	"shopper": ["Tomasina Ferreira-Valcourt", "Tomasina", "Wants six pots of rosemary; pays double before the rain"],
	"vendor": ["Mira, the fig seller", "Mira", "Her figs spoil if the rain reaches them"],
	"elder": ["Old Anselm", "Anselm", "Knows which clouds bring rain; ask him before noon"],
	"kid": ["Pip", "Pip", "Will carry a message for two coins"],
	"fig": ["Fig and apricot stall", "Figs", "Uncovered · 18 baskets left"],
	"herb": ["Herb and tea stall", "Herbs", "Rosemary: 4 pots, two short of the order"],
	"seed": ["Seed and bulb stall", "Seeds", "Closed until the delivery"],
}
const SHOWN := ["shopper", "elder", "fig"]
const FOCUS_STALL := "fig"
const MAX_FULL := 4
const MAX_W := 240.0
const PAD := Vector4(9, 3, 9, 4)   # left, top, right, bottom
var f_name: FontVariation
var f_line: FontVariation
const EMBOLDEN := 0.2         # Chrome on Windows draws the light-on-dark names a little heavier than FreeType
const BASELINE_SHIFT := -1.0  # Chrome places the baseline 1 px higher than the hhea-centred line box
var cap_layer: Control
var placed_caps := []
var selected := "shopper"

func build_captions() -> void:
	# the font files the web demo bundles (assets/fonts): Alegreya, variable upright and italic
	var ts := TextServerManager.get_primary_interface()
	f_name = FontVariation.new(); f_name.base_font = load("res://fonts/Alegreya-Variable.woff")
	f_name.variation_opentype = {ts.name_to_tag("wght"): 600}                     # font-weight 600
	f_name.opentype_features = {ts.name_to_tag("smcp"): 1}                       # small caps
	f_name.spacing_glyph = 1                                                     # .06em
	f_name.variation_embolden = EMBOLDEN
	f_line = FontVariation.new(); f_line.base_font = load("res://fonts/Alegreya-Italic.woff")
	var layer := CanvasLayer.new(); layer.layer = 2; add_child(layer)
	cap_layer = Control.new(); cap_layer.set_anchors_preset(Control.PRESET_FULL_RECT); cap_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cap_layer)
	cap_layer.draw.connect(draw_captions)

func wrap_text(text: String, font: Font, size: int, width: float) -> Array:   # breaks after spaces and hyphens
	var words := []
	var cur := ""
	for ch in text:
		cur += ch
		if ch == " " or ch == "-":
			words.append(cur); cur = ""
	if cur != "": words.append(cur)
	var lines := []; var line := ""
	for w in words:
		var tryline: String = line + w
		if line != "" and font.get_string_size(tryline.strip_edges(false, true), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			lines.append(line.strip_edges(false, true)); line = w
		else: line = tryline
	lines.append(line.strip_edges(false, true))
	return lines

func measure(id: String, short: bool) -> Dictionary:
	var inner := MAX_W - PAD.x - PAD.z
	var b := wrap_text(CAPS[id][1] if short else CAPS[id][0], f_name, 17, inner)
	var i := [] if short else wrap_text(CAPS[id][2], f_line, 16, inner)
	# shrink-to-fit: the unwrapped (max-content) width, capped; a caption that wraps takes the full 240 px
	var widest := f_name.get_string_size(CAPS[id][1] if short else CAPS[id][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	if not short: widest = maxf(widest, f_line.get_string_size(CAPS[id][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var w := minf(MAX_W, ceilf(widest) + PAD.x + PAD.z)
	var h := PAD.y + PAD.w + b.size() * 17 * 1.2 + i.size() * 16 * 1.2   # line-height 1.2
	return {"id": id, "b": b, "i": i, "w": w, "h": h}

func to_screen(p: Vector3) -> Vector2: return cam.unproject_position(p)
func sprite_rect(q: Dictionary) -> Rect2:   # the drawn figure: head top to feet, 0.6 of its height wide
	var top := to_screen(Vector3(q.x, (FEET + 1 - q.top) * PX, q.z)); var foot := to_screen(Vector3(q.x, 0, q.z))
	var h := foot.y - top.y; var w := h * 0.6
	return Rect2(top.x - w / 2, top.y, w, h)
func stall_rect(id: String) -> Rect2:
	var g: Vector3 = stalls[id].g.position; var lo := Vector2(1e9, 1e9); var hi := Vector2(-1e9, -1e9)
	for dx in [-1.45, 1.45]:
		for dy in [0.0, 2.7]:
			for dz in [-0.6, 0.9]:
				var p := to_screen(g + Vector3(dx, dy, dz)); lo = lo.min(p); hi = hi.max(p)
	return Rect2(lo, hi - lo)
func hits(a: Rect2, b: Rect2, gap: float) -> bool:
	return a.position.x < b.end.x + gap and b.position.x < a.end.x + gap and a.position.y < b.end.y + gap and b.position.y < a.end.y + gap

func find_spot(anc: Vector2, own: Rect2, w: float, h: float, B: Rect2, placed: Array, hard: Array, soft: Array) -> Variant:
	var ok := func(r: Rect2) -> bool:
		if r.position.x < B.position.x or r.position.y < B.position.y or r.end.x > B.end.x or r.end.y > B.end.y: return false
		for p in placed:
			if hits(r, p, 4): return false
		for p in hard + soft:
			if hits(r, p, 2): return false
		return true
	var cx := own.position.x + own.size.x / 2; var top := own.position.y
	var tries := []
	for dy in [0, -14, -28, -42, -56, -70, -84]:
		for dx in [0, -50, 50, -100, 100, -150, 150]: tries.append(Vector2(cx - w / 2 + dx, top - h - 4 + dy))   # above, sliding out
	for dy in [0, 16, -16, 32, 48]:
		tries.append(Vector2(own.end.x + 6, own.position.y + dy)); tries.append(Vector2(own.position.x - w - 6, own.position.y + dy))   # beside
	for dx in [0, -60, 60]: tries.append(Vector2(cx - w / 2 + dx, own.end.y + 4))   # below
	for t in tries:
		var r := Rect2(t, Vector2(w, h))
		if ok.call(r): return r
	return null

func layout_captions() -> void:
	var B := Rect2(12, 12, W - 24, H - 24)
	var sprites := []; var sprite_of := {}
	for id in people:
		var r := sprite_rect(people[id]); sprites.append(r); sprite_of[id] = r
	var stall_of := {}
	for id in stalls: stall_of[id] = stall_rect(id)
	var order := CAPS.keys()
	var live := SHOWN.duplicate()
	live.sort_custom(func(a, b): return rank(a, order) < rank(b, order))
	placed_caps = []; var placed := []; var full := 0
	for id in live:
		var own: Rect2 = sprite_of[id] if people.has(id) else stall_of[id]
		var others := []
		for s in stall_of:
			if s != id: others.append(stall_of[s])
		var anc := to_screen(people[id].anchor if people.has(id) else stalls[id].anchor)
		for short in ([false, true] if full < MAX_FULL else [true]):
			var m := measure(id, short); var w := roundf(m.w); var h := roundf(m.h)   # offsetWidth/Height
			var spot = find_spot(anc, own, w, h, B, placed, sprites, []) if id == selected \
				else find_spot(anc, own, w, h, B, placed, sprites, others)
			if spot == null and id != selected: spot = find_spot(anc, own, w, h, B, placed, sprites, [])
			if spot != null:
				if not short: full += 1
				m.pos = Vector2(roundf(spot.position.x), roundf(spot.position.y)); m.w = w; m.h = h   # snapped to pixels
				placed_caps.append(m); placed.append(spot)
				break
	cap_layer.queue_redraw()

func rank(id: String, order: Array) -> int: return -2 if id == selected else (-1 if id == FOCUS_STALL else order.find(id))

var glow_boxes := []
func draw_captions() -> void:
	var plate := col("plate")
	if glow_boxes.is_empty():   # box-shadow 0 0 10px 2px plate at 60%: 1 px rings outside the box
		for k in 14:
			var s := StyleBoxFlat.new(); s.draw_center = false; s.set_border_width_all(1); s.set_corner_radius_all(5 + k)
			s.set_expand_margin_all(k + 1)
			var a := 0.6 * 0.5 * (1.0 - erf_approx((k + 0.5 - 2.0) / (5.0 * sqrt(2.0))))
			s.border_color = Color(plate, a); glow_boxes.append(s)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(plate, 0.85); bg.set_corner_radius_all(4)
	for c in placed_caps:
		var r := Rect2(c.pos, Vector2(c.w, c.h))
		for s in glow_boxes: cap_layer.draw_style_box(s, r)
		cap_layer.draw_style_box(bg, r)
		var y: float = c.pos.y + PAD.y
		var inner: float = c.w - PAD.x - PAD.z
		for s in c.b:
			text_line(s, f_name, 17, c.pos.x + PAD.x, inner, y, col("accent") if c.id == selected else col("ink")); y += 17 * 1.2
		for s in c.i:
			text_line(s, f_line, 16, c.pos.x + PAD.x, inner, y, col("ink")); y += 16 * 1.2

## one centred line in a CSS line box: the font's content area centred in line-height 1.2
func text_line(s: String, f: Font, size: int, x: float, inner: float, top: float, c: Color) -> void:
	var lw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := f.get_ascent(size); var desc := f.get_descent(size)
	var base := roundf(top + (size * 1.2 - (asc + desc)) / 2 + asc + BASELINE_SHIFT)
	cap_layer.draw_string(f, Vector2(x + (inner - lw) / 2, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func erf_approx(x: float) -> float:   # Abramowitz-Stegun 7.1.26
	var s := signf(x); x = absf(x)
	var t := 1.0 / (1.0 + 0.3275911 * x)
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x)
	return s * y

# ------------------------------------------------------------------ selection (click a townsperson)
func select(id: String) -> void:
	selected = id; ring.position = Vector3(people[id].x, 0.02, people[id].z)
	layout_captions()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var o := cam.project_ray_origin(e.position); var d := cam.project_ray_normal(e.position)
		var best := ""; var best_t := INF
		for id in people:   # generous invisible hit spheres (r 0.75 at chest height), never the caption text
			var c := Vector3(people[id].x, 0.9, people[id].z); var oc := o - c
			var b := oc.dot(d); var disc := b * b - (oc.length_squared() - 0.75 * 0.75)
			if disc >= 0 and -b - sqrt(disc) < best_t: best_t = -b - sqrt(disc); best = id
		if best != "": select(best)
