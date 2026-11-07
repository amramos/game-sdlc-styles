extends Node3D
## Port of toybox-low-poly/demo.html?frame=key-scene (autumn palette, t = 0.8 s).

const P := {
	"ink": "#2F2A3D", "paper": "#FBF4E6", "sky-top": "#A8C6E6", "sky-low": "#F7DEC9", "ground": "#A9BF88",
	"path": "#EEDDBB", "shadow": "#605D85", "accent": "#13C4B4", "signal-blocked": "#F2A0A0",
	"material-cap": "#E5937E", "material-stem": "#F4E8D6", "material-wood": "#A88262",
	"material-leaf": "#EAC27E", "material-foliage": "#C6B771", "material-stone": "#B9B5C6",
	"material-cloth": "#8FA9D6",
}
const N := 12
const T := 0.8
var flat_shader := preload("res://flat.gdshader")
var ghost_shader := preload("res://ghost.gdshader")
var unlit_shader := preload("res://unlit.gdshader")
var mats := {}

func c(role: String) -> Color: return Color(P[role])
func lin3(col: Color) -> Vector3:
	var l := col.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)
func tile_x(i: float) -> float: return i - N / 2.0 + 0.5

# ------------------------------------------------------------------ seeded random (mulberry32)
var _seed := 20261107
func imul(x: int, y: int) -> int:
	return ((x & 0xFFFF) * y + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF
func rnd() -> float:
	_seed = (_seed + 0x6D2B79F5) & 0xFFFFFFFF
	var t := imul(_seed ^ (_seed >> 15), 1 | _seed)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

# ------------------------------------------------------------------ materials
func mat(role: String) -> Material:
	if mats.has(role): return mats[role]
	var m := ShaderMaterial.new()
	m.shader = ghost_shader if role == "ghost" else flat_shader
	var sky := c("sky-top").srgb_to_linear().lerp(Color(1, 1, 1), 0.45)
	m.set_shader_parameter("sky_linear", Vector3(sky.r, sky.g, sky.b))
	m.set_shader_parameter("ground_linear", lin3(c("shadow")))
	m.set_shader_parameter("fog_linear", lin3(c("sky-low")))
	if role == "ghost":
		m.set_shader_parameter("albedo", c("paper"))
		m.set_shader_parameter("emission_linear", lin3(c("accent")) * 0.25)
		m.set_shader_parameter("alpha", 0.7)
		m.render_priority = 2
	else:
		m.set_shader_parameter("albedo", c(role))
	mats[role] = m
	return m

func unlit(col: Color, blob := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = unlit_shader
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("fog_color", c("sky-low"))
	m.set_shader_parameter("blob", blob)
	if blob: m.render_priority = 1
	return m

# ------------------------------------------------------------------ geometry: convex triangle lists
## Each generator returns triangles (arrays of 3 Vector3) around the origin; orient() makes each
## face point away from the origin, which holds for every convex primitive here.
func orient(tris: Array) -> Array:
	for t in tris:
		var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0])
		if n.dot((t[0] + t[1] + t[2]) / 3.0) < 0:
			var tmp = t[1]; t[1] = t[2]; t[2] = tmp
	return tris

func quad(a, b, cc, d) -> Array: return [[a, b, cc], [a, cc, d]]

func ring_quads(r1: Array, r2: Array) -> Array:
	var out := []
	for i in r1.size():
		var j := (i + 1) % r1.size()
		out += quad(r1[i], r1[j], r2[j], r2[i])
	return out

func fan(ring: Array) -> Array:
	var out := []
	for i in range(1, ring.size() - 1): out.append([ring[0], ring[i], ring[i + 1]])
	return out

## three.js chamferBox: an extruded rectangle with one 45-degree bevel on its top and bottom edges.
func chamfer_box(w: float, h: float, d: float, b: float) -> Array:
	var depth := maxf(h - 2 * b, 0.001)
	var rect := func(hx: float, hz: float, y: float) -> Array:
		return [Vector3(-hx, y, -hz), Vector3(hx, y, -hz), Vector3(hx, y, hz), Vector3(-hx, y, hz)]
	var x := w / 2 - b; var z := d / 2 - b
	var top_in: Array = rect.call(x, z, depth / 2 + b); var top_out: Array = rect.call(x + b, z + b, depth / 2)
	var bot_out: Array = rect.call(x + b, z + b, -depth / 2); var bot_in: Array = rect.call(x, z, -depth / 2 - b)
	return orient(fan(top_in) + ring_quads(top_in, top_out) + ring_quads(top_out, bot_out) + ring_quads(bot_out, bot_in) + fan(bot_in))

## three.js CylinderGeometry (x = r sin(theta), z = r cos(theta)), one height segment, capped.
func cylinder(rt: float, rb: float, h: float, seg: int) -> Array:
	var top := []; var bot := []
	for i in seg:
		var th := float(i) / seg * TAU
		top.append(Vector3(rt * sin(th), h / 2, rt * cos(th))); bot.append(Vector3(rb * sin(th), -h / 2, rb * cos(th)))
	return orient(ring_quads(top, bot) + fan(top) + fan(bot))

## three.js SphereGeometry(r, ws, hs, 0, 2pi, 0, theta_len): x = -r cos(phi) sin(t), y = r cos(t), z = r sin(phi) sin(t).
func sphere(r: float, ws: int, hs: int, theta_len := PI) -> Array:
	var rows := []
	for iy in hs + 1:
		var row := []
		var t := float(iy) / hs * theta_len
		for ix in ws + 1:
			var ph := float(ix) / ws * TAU
			row.append(Vector3(-r * cos(ph) * sin(t), r * cos(t), r * sin(ph) * sin(t)))
		rows.append(row)
	var out := []
	for iy in hs:
		for ix in ws:
			var a: Vector3 = rows[iy][ix + 1]; var b: Vector3 = rows[iy][ix]
			var cc: Vector3 = rows[iy + 1][ix]; var d: Vector3 = rows[iy + 1][ix + 1]
			if iy != 0: out.append([a, b, d])
			if iy != hs - 1 or theta_len < PI: out.append([b, cc, d])
	return orient(out)

## three.js CircleGeometry: a disc in XY facing +z (not oriented by the origin rule).
func circle(r: float, seg: int) -> Array:
	var out := []
	for i in seg:
		var a := float(i) / seg * TAU; var b := float(i + 1) / seg * TAU
		out.append([Vector3.ZERO, Vector3(r * cos(a), r * sin(a), 0), Vector3(r * cos(b), r * sin(b), 0)])
	return out

func polyhedron(verts: Array, idx: Array, r: float, detail: int) -> Array:
	var out := []
	for f in range(0, idx.size(), 3):
		var a: Vector3 = verts[idx[f]]; var b: Vector3 = verts[idx[f + 1]]; var cc: Vector3 = verts[idx[f + 2]]
		if detail == 0:
			out.append([a, b, cc])
		else:   # detail 1: midpoint split, as three's subdivideFace with two columns
			var ab := (a + b) / 2; var ac := (a + cc) / 2; var bc := (b + cc) / 2
			out += [[a, ab, ac], [ab, b, bc], [ac, bc, cc], [ab, bc, ac]]
	for t in out:
		for k in 3: t[k] = t[k].normalized() * r
	return orient(out)

func icosa(r: float, detail := 0) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var i := [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	return polyhedron(v, i, r, detail)

func dodeca(r: float) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0; var q := 1.0 / t
	var v := [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(1, -1, -1), Vector3(1, -1, 1),
		Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(0, -q, -t), Vector3(0, -q, t), Vector3(0, q, -t), Vector3(0, q, t),
		Vector3(-q, -t, 0), Vector3(-q, t, 0), Vector3(q, -t, 0), Vector3(q, t, 0), Vector3(-t, 0, -q), Vector3(t, 0, -q),
		Vector3(-t, 0, q), Vector3(t, 0, q)]
	var i := [3, 11, 7, 3, 7, 15, 3, 15, 13, 7, 19, 17, 7, 17, 6, 7, 6, 15, 17, 4, 8, 17, 8, 10, 17, 10, 6, 8, 0, 16, 8, 16, 2,
		8, 2, 10, 0, 12, 1, 0, 1, 18, 0, 18, 16, 6, 10, 2, 6, 2, 13, 6, 13, 15, 2, 16, 18, 2, 18, 3, 2, 3, 13, 18, 1, 9, 18, 9, 11,
		18, 11, 3, 4, 14, 12, 4, 12, 0, 4, 0, 8, 11, 9, 5, 11, 5, 19, 11, 19, 7, 19, 5, 14, 19, 14, 4, 19, 4, 17, 1, 12, 14, 1, 14, 5, 1, 5, 9]
	return polyhedron(v, i, r, 0)

func octa(r: float) -> Array:
	var v := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	return polyhedron(v, [0, 2, 4, 0, 4, 3, 0, 3, 5, 0, 5, 2, 1, 2, 5, 1, 5, 3, 1, 3, 4, 1, 4, 2], r, 0)

## three.js CapsuleGeometry (r160): a lathe of two quarter arcs (4 steps each) and the straight side.
func capsule(r: float, length: float, radial: int) -> Array:
	var prof := []
	for k in 5:
		var a := 1.5 * PI + k / 4.0 * 0.5 * PI
		prof.append(Vector2(r * cos(a), -length / 2 + r * sin(a)))
	for k in 5:
		var a := k / 4.0 * 0.5 * PI
		prof.append(Vector2(r * cos(a), length / 2 + r * sin(a)))
	var out := []
	for i in radial:
		var p0 := float(i) / radial * TAU; var p1 := float(i + 1) / radial * TAU
		for k in prof.size() - 1:
			var a: Vector2 = prof[k]; var b: Vector2 = prof[k + 1]
			var v := [Vector3(a.x * sin(p0), a.y, a.x * cos(p0)), Vector3(a.x * sin(p1), a.y, a.x * cos(p1)),
				Vector3(b.x * sin(p1), b.y, b.x * cos(p1)), Vector3(b.x * sin(p0), b.y, b.x * cos(p0))]
			for tri in quad(v[0], v[1], v[2], v[3]):
				if (tri[1] - tri[0]).cross(tri[2] - tri[0]).length() > 1e-12: out.append(tri)
	return orient(out)

func ring_square(r_in: float, r_out: float) -> Array:   # RingGeometry(r_in, r_out, 4, 1, pi/4)
	var a := []; var b := []
	for k in 4:
		var th := PI / 4 + k * PI / 2
		a.append(Vector3(r_in * cos(th), r_in * sin(th), 0)); b.append(Vector3(r_out * cos(th), r_out * sin(th), 0))
	var out := []
	for k in 4:
		var j := (k + 1) % 4
		out += [[a[k], b[k], b[j]], [a[k], b[j], a[j]]]
	return out

# ------------------------------------------------------------------ parts
func smooth01(x: float, lo: float, hi: float) -> float:   # THREE.MathUtils.smoothstep
	if x <= lo: return 0.0
	if x >= hi: return 1.0
	var t := (x - lo) / (hi - lo)
	return t * t * (3 - 2 * t)

## Flat-shaded mesh: transform baked in, each triangle its own vertices, baked ground shading in COLOR.
func build_mesh(tris: Array, xf: Transform3D, ao := Vector3(0, 0.55, 0.72)) -> ArrayMesh:
	var v := PackedVector3Array(); var n := PackedVector3Array(); var col := PackedColorArray()
	for t in tris:
		var p := [xf * t[0], xf * t[1], xf * t[2]]
		var fn: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
		for k in [0, 2, 1]:   # Godot: clockwise front faces
			v.append(p[k]); n.append(fn)
			var s := ao.z + (1 - ao.z) * smooth01(p[k].y, ao.x, ao.y)
			col.append(Color(s, s, s))
	var a := []; a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v; a[Mesh.ARRAY_NORMAL] = n; a[Mesh.ARRAY_COLOR] = col
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m

func xform(pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot, EULER_ORDER_XYZ).scaled_local(scl), pos)

func part(g: Node3D, tris: Array, role: String, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, ao := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build_mesh(tris, xform(pos, rot, scl), Vector3(0, 0.55, 0.72) if ao else Vector3(-1, -0.99, 0.72))
	mi.material_override = mat(role)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if role == "ghost" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	g.add_child(mi)
	return mi

var blob_mat: ShaderMaterial
func blob(g: Node3D, r: float, y := 0.006) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(r * 2, r * 2)
	mi.mesh = pm; mi.position.y = y
	mi.material_override = blob_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)

func group(parent: Node3D = null) -> Node3D:
	var g := Node3D.new()
	if parent: parent.add_child(g)
	return g

# ------------------------------------------------------------------ props (same as demo.html)
func house(o := {}) -> Node3D:
	var g := group()
	var w: float = o.get("w", 1.0); var sh: float = o.get("stemH", 0.9); var cr: float = o.get("capR", 0.72); var ch: float = o.get("capH", 0.75)
	var ghost: bool = o.get("ghost", false)
	var role := func(r: String) -> String: return "ghost" if ghost else r
	part(g, cylinder(0.36 * w, 0.46 * w, sh, 8), role.call("material-stem"), Vector3(0, sh / 2, 0))
	if o.get("built", true):
		part(g, sphere(cr, 8, 4, PI / 2), role.call("material-cap"), Vector3(0, sh - 0.06, 0), Vector3(0, PI / 8, 0), Vector3(1, ch, 1))
		part(g, circle(cr, 8), role.call("material-stem"), Vector3(0, sh - 0.06, 0), Vector3(PI / 2, 0, PI / 8))
		for s in [[0.75, 0.6, 1.0], [0.5, 2.6, 0.8], [0.95, 4.4, 0.9]]:
			var phi: float = s[0]; var th: float = s[1]
			var x := cr * sin(phi) * cos(th); var z := cr * sin(phi) * sin(th); var y := sh - 0.06 + ch * cr * cos(phi)
			part(g, icosa(0.1 * s[2]), role.call("material-stem"), Vector3(x, y, z), Vector3(phi * cos(th + PI / 2), 0, -phi * sin(th + PI / 2)), Vector3(1, 0.45, 1))
	var zr := 0.42 * w
	part(g, chamfer_box(0.26, 0.42, 0.08, 0.025), role.call("material-wood"), Vector3(0, 0.21, zr))
	if sh > 0.6:
		part(g, chamfer_box(0.16, 0.16, 0.06, 0.02), role.call("material-wood"), Vector3(sin(0.9) * 0.38 * w, sh * 0.62, cos(0.9) * 0.38 * w), Vector3(0, 0.9, 0))
	part(g, chamfer_box(0.32, 0.05, 0.18, 0.015), role.call("material-stone"), Vector3(0, 0.025, zr + 0.18))
	if not ghost: blob(g, 0.8 * w)
	return g

func tree(kind: String) -> Node3D:
	var g := group()
	part(g, cylinder(0.07, 0.1, 0.5, 6), "material-wood", Vector3(0, 0.25, 0))
	var r := "material-leaf" if kind == "leaf" else "material-foliage"
	part(g, icosa(0.4), r, Vector3(0, 0.72, 0))
	part(g, icosa(0.28), r, Vector3(0.05, 1.04, -0.02), Vector3(0.4, 0.3, 0))
	blob(g, 0.55)
	return g

func leaf_pile() -> Node3D:
	var g := group()
	part(g, icosa(0.28), "material-leaf", Vector3(0, 0.06, 0), Vector3(0, rnd() * 3, 0), Vector3(1, 0.5, 1))
	part(g, icosa(0.15), "material-cap", Vector3(0.08, 0.18, 0.04), Vector3(0.5, 0, 0), Vector3(1, 0.55, 1))
	blob(g, 0.4)
	return g

func stone() -> Node3D:
	var g := group()
	var rx := rnd(); var ry := rnd()
	part(g, dodeca(0.14), "material-stone", Vector3(0, 0.05, 0), Vector3(rx, ry, 0), Vector3(1, 0.6, 1))
	blob(g, 0.22)
	return g

func fence_run(g: Node3D, ax: float, az: float, bx: float, bz: float) -> void:
	var length := Vector2(bx - ax, bz - az).length(); var n := int(floor(length / 0.5 + 0.5)); var ang := atan2(bz - az, bx - ax)
	for i in n + 1:
		var t := float(i) / n
		part(g, chamfer_box(0.09, 0.38, 0.09, 0.02), "material-wood", Vector3(ax + (bx - ax) * t, 0.19, az + (bz - az) * t))
	for y in [0.14, 0.28]:
		part(g, chamfer_box(length, 0.06, 0.04, 0.015), "material-wood", Vector3((ax + bx) / 2, y, (az + bz) / 2), Vector3(0, -ang, 0))

func villager(carry: bool) -> Node3D:
	var g := group()
	part(g, cylinder(0.14, 0.2, 0.38, 8), "material-cloth", Vector3(0, 0.19, 0))
	part(g, icosa(0.16, 1), "material-stem", Vector3(0, 0.52, 0))
	part(g, sphere(0.21, 8, 3, PI / 2), "material-cap", Vector3(0, 0.6, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	part(g, circle(0.21, 8), "material-stem", Vector3(0, 0.6, 0), Vector3(PI / 2, 0, 0))
	for s in [-1, 1]:
		part(g, chamfer_box(0.035, 0.06, 0.03, 0.008), "ink", Vector3(s * 0.06, 0.53, 0.15), Vector3.ZERO, Vector3.ONE, false)
		part(g, capsule(0.045, 0.14, 6), "material-cloth", Vector3(s * 0.16, 0.26, 0.08), Vector3(-1.0, 0, s * 0.25))
	if carry: part(g, chamfer_box(0.62, 0.05, 0.12, 0.015), "material-wood", Vector3(0, 0.27, 0.2), Vector3(0, 0, 0.08))
	blob(g, 0.3)
	return g

func construction_site() -> Node3D:
	var g := house({"stemH": 0.45, "built": false})
	for p in [[-0.55, -0.55], [0.55, -0.55], [0.55, 0.55], [-0.55, 0.55]]:
		part(g, chamfer_box(0.07, 1.05, 0.07, 0.015), "material-wood", Vector3(p[0], 0.525, p[1]))
	part(g, chamfer_box(1.2, 0.05, 0.12, 0.015), "material-wood", Vector3(0, 0.8, -0.55))
	part(g, chamfer_box(0.12, 0.05, 1.2, 0.015), "material-wood", Vector3(0.55, 0.8, 0))
	for i in 3:
		part(g, chamfer_box(0.6, 0.05, 0.12, 0.015), "material-wood", Vector3(-0.85, 0.025 + i * 0.05, 0.75 - i * 0.02), Vector3(0, 0.6 + i * 0.12, 0))
	return g

var marker_mat: ShaderMaterial
func marker(g: Node3D, y: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = build_mesh(octa(0.11), Transform3D.IDENTITY)
	mi.material_override = marker_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1, 1.4, 1)
	mi.position.y = y + sin(T * 2.4) * 0.05
	mi.rotation.y = T * 1.2
	g.add_child(mi)

# ------------------------------------------------------------------ scene
var village: Node3D
func place(obj: Node3D, i: int, j: int, rot_y := 0.0) -> Node3D:
	obj.position = Vector3(tile_x(i), 0, tile_x(j)); obj.rotation.y = rot_y
	village.add_child(obj)
	return obj

func _ready() -> void:
	blob_mat = unlit(c("shadow"), true)
	blob_mat.set_shader_parameter("blob", true)
	marker_mat = unlit(c("accent"))
	village = group(self)
	var island := group(village)
	var isl := part(island, chamfer_box(N + 0.4, 0.9, N + 0.4, 0.3), "ground", Vector3(0, -0.45, 0), Vector3.ZERO, Vector3.ONE, false)
	isl.mesh = build_mesh(chamfer_box(N + 0.4, 0.9, N + 0.4, 0.3), xform(Vector3(0, -0.45, 0)), Vector3(-0.9, 0, 0.8))
	var path_tiles := []
	for i in range(1, 11): path_tiles.append([i, 6])
	for j in range(2, 6): path_tiles.append([5, j])
	for j in range(7, 11): path_tiles.append([8, j])
	for p in path_tiles:
		part(village, chamfer_box(0.94, 0.07, 0.94, 0.025), "path", Vector3(tile_x(p[0]), 0.005, tile_x(p[1])), Vector3.ZERO, Vector3.ONE, false)
	place(house(), 3, 4)
	place(house({"stemH": 1.25, "capR": 0.66, "capH": 0.9}), 7, 4)
	place(house({"capR": 0.8, "capH": 0.6}), 3, 8, PI)
	place(house({"stemH": 1.1}), 10, 4)
	place(house({"w": 0.9, "capR": 0.65}), 10, 9, -PI / 2)
	var site := place(construction_site(), 6, 8); marker(site, 1.45)
	for t in [[1, 1, "f"], [0, 3, "leaf"], [11, 1, "f"], [11, 7, "leaf"], [0, 10, "f"], [2, 11, "leaf"], [1, 4, "f"], [11, 11, "f"], [6, 0, "leaf"], [8, 1, "f"]]:
		var tr := tree(t[2]); place(tr, t[0], t[1], rnd() * 6)
	for t in [[4, 10], [9, 7], [2, 2], [7, 10]]: place(leaf_pile(), t[0], t[1])
	for t in [[1, 9], [6, 4], [11, 5]]: place(stone(), t[0], t[1])
	var fences := group(village)
	fence_run(fences, tile_x(9) - 0.5, tile_x(8) - 0.5, tile_x(11) + 0.45, tile_x(8) - 0.5)
	fence_run(fences, tile_x(2) - 0.5, tile_x(7) - 0.5, tile_x(4) + 0.5, tile_x(7) - 0.5)
	for n in 40:
		var x := (rnd() - 0.5) * (N - 0.6); var z := (rnd() - 0.5) * (N - 0.6)
		var role := "material-leaf" if rnd() < 0.5 else "material-cap"
		part(village, chamfer_box(0.12, 0.02, 0.08, 0.005), role, Vector3(x, 0.012, z), Vector3(0, rnd() * 6, 0), Vector3.ONE, false)
	var v1 := place(villager(true), 5, 6, 0.6); marker(v1, 0.95)
	v1.position.y = absf(sin(T * 3)) * 0.03
	var v2 := place(villager(false), 8, 7, 1.2); marker(v2, 0.95)
	# placement ghost and accent tile ring at (6, 2)
	var ghost := house({"ghost": true, "stemH": 1.25, "capR": 0.66, "capH": 0.9})
	ghost.position = Vector3(tile_x(6), 0, tile_x(2)); village.add_child(ghost)
	var ring := MeshInstance3D.new()
	ring.mesh = build_mesh(ring_square(0.56, 0.68), Transform3D.IDENTITY)
	ring.material_override = unlit(c("accent"))
	ring.rotation.x = -PI / 2; ring.position = Vector3(tile_x(6), 0.08, tile_x(2))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	village.add_child(ring)
	build_env()

func build_env() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#FFF3E0")
	sun.shadow_enabled = OS.get_environment("TOY_NOSH") == ""
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = float(OS.get_environment("TOY_MAXD")) if OS.get_environment("TOY_MAXD") != "" else 30.0
	sun.shadow_blur = float(OS.get_environment("TOY_BLUR")) if OS.get_environment("TOY_BLUR") != "" else 0.5
	sun.shadow_normal_bias = 1.0
	add_child(sun)
	sun.look_at_from_position(Vector3(-7, 16, 9), Vector3.ZERO)

	var bg := CanvasLayer.new(); bg.layer = -1; add_child(bg)
	var bg_rect := ColorRect.new(); bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_mat := ShaderMaterial.new(); bg_mat.shader = preload("res://skybg.gdshader")
	bg_mat.set_shader_parameter("top", c("sky-top")); bg_mat.set_shader_parameter("low", c("sky-low"))
	bg_rect.material = bg_mat; bg.add_child(bg_rect)
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS; env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR   # black: the shader adds the fill
	env.ambient_light_color = Color.BLACK; env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 11.5; cam.near = 0.1; cam.far = 200
	add_child(cam)
	var pitch := atan(1.0 / sqrt(2.0)); var yaw := deg_to_rad(45.0); var target := Vector3(0, 0, 0.3)
	cam.look_at_from_position(target + 40.0 * Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)), target)
	cam.current = true

	if OS.get_environment("TOY_NOTILT") == "":
		var layer := CanvasLayer.new(); add_child(layer)
		for k in 2:
			if k == 1:
				var bb := BackBufferCopy.new(); bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT; layer.add_child(bb)
			var rect := ColorRect.new(); rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			var tm := ShaderMaterial.new(); tm.shader = preload("res://tilt.gdshader")
			tm.set_shader_parameter("step_uv", Vector2(2.5 / 1280.0, 0) if k == 0 else Vector2(0, 2.5 / 720.0))
			rect.material = tm; layer.add_child(rect)
