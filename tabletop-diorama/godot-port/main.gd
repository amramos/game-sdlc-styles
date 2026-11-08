extends Node3D
## Port of tabletop-diorama/demo.html?frame=key-scene (sunny-kitchen palette, t = 2.0 s).
## Four image-to-3D models with painted maps, tiling table and street, code-built figurines and
## props, one sun + hemisphere fill, fog, tilt-shift / vignette / grade / ACES, paper-card HUD.

const P := {
	"room": "#D9CDB8", "table": "#A47E58", "wood-bare": "#E6CFA6", "paint-red": "#C2452F",
	"paint-ochre": "#D4A24A", "paint-blue": "#3E6E9E", "paint-green": "#5E8C4A", "paint-cream": "#E8DAB8",
	"paint-brown": "#7A4E2E", "key": "#FFF1D6", "fill": "#B8CCE0", "paper": "#F4ECD8", "ink": "#2B2118",
	"signal-warn": "#A3261A", "signal-ok": "#2F5D34", "accent": "#E8308C",
}
const KEY_POS := Vector3(-6, 7.5, 3)
const KEY_I := 3.0                # three.js DirectionalLight intensity (physical units)
const FILL_I := 2.0               # three.js HemisphereLight intensity
const FOG := Vector2(15, 28)
const OUT_SCALE := 0.5            # scene written at half value; lens.gdshader undoes it
const T := 2.0                    # the demo's fixed frame time

var wood_shader := preload("res://wood.gdshader")
var ring_shader := preload("res://ring.gdshader")
var font: FontFile
var grain: ImageTexture
var mats := {}

func c(role: String) -> Color: return Color(P[role])
func lin3(col: Color) -> Vector3:
	var l := col.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)

# ------------------------------------------------------------------ seeded random (mulberry32)
var _seed := 20261107
func imul(x: int, y: int) -> int:
	return ((x & 0xFFFF) * y + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF
func rnd() -> float:
	_seed = (_seed + 0x6D2B79F5) & 0xFFFFFFFF
	var t := imul(_seed ^ (_seed >> 15), 1 | _seed)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

# ------------------------------------------------------------------ grain texture (demo's canvas)
## 256x256 neutral grey, mean about 0.9: 90 wavy antialiased strokes and 1,400 speckles.
func make_grain() -> ImageTexture:
	var n := 256
	var buf := PackedFloat32Array(); buf.resize(n * n); buf.fill(236.0)
	var cov := PackedFloat32Array(); cov.resize(n * n)
	var stamp := PackedInt32Array(); stamp.resize(n * n); stamp.fill(-1)
	var path_id := 0
	for i in 90:
		var y0 := rnd() * n; var amp := 4.0 * (0.4 + rnd()); var f := 1 + floori(rnd() * 3); var ph := rnd() * 6.283
		var g := float(roundi(140 + rnd() * 70)); var alpha := 0.22 * (0.5 + rnd()); var lw := 1.0 + rnd()
		for dy in [-n, 0, n]:
			var pts := PackedVector2Array()
			for px in range(0, n + 1, 8):
				pts.append(Vector2(px, y0 + dy + sin(float(px) / n * 6.283 * f + ph) * amp))
			if y0 + dy + amp < -3 or y0 + dy - amp > n + 3: continue
			path_id += 1
			var touched := PackedInt32Array()
			for s in pts.size() - 1:
				var a: Vector2 = pts[s]; var b: Vector2 = pts[s + 1]
				var x0 := maxi(0, floori(minf(a.x, b.x) - lw)); var x1 := mini(n - 1, ceili(maxf(a.x, b.x) + lw))
				var yy0 := maxi(0, floori(minf(a.y, b.y) - lw - 1)); var yy1 := mini(n - 1, ceili(maxf(a.y, b.y) + lw + 1))
				var ab := b - a; var l2 := ab.length_squared()
				for yy in range(yy0, yy1 + 1):
					for xx in range(x0, x1 + 1):
						var p := Vector2(xx + 0.5, yy + 0.5)
						var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
						var d := (a + ab * t).distance_to(p)
						var cv := clampf(lw / 2.0 + 0.5 - d, 0.0, 1.0)
						if cv <= 0.0: continue
						var k := yy * n + xx
						if stamp[k] != path_id:
							stamp[k] = path_id; cov[k] = 0.0; touched.append(k)
						cov[k] = maxf(cov[k], cv)
			for k in touched:
				var w := alpha * cov[k]
				buf[k] = buf[k] * (1.0 - w) + g * w
	for i in 1400:
		var g := float(roundi(180 + rnd() * 60)); var x := rnd() * n; var y := rnd() * n
		var ix := floori(x); var iy := floori(y); var fx := x - ix; var fy := y - iy
		for q in [[0, 0, (1 - fx) * (1 - fy)], [1, 0, fx * (1 - fy)], [0, 1, (1 - fx) * fy], [1, 1, fx * fy]]:
			var xx: int = ix + q[0]; var yy: int = iy + q[1]
			if xx >= n or yy >= n: continue
			var w: float = 0.4 * q[2]
			buf[yy * n + xx] = buf[yy * n + xx] * (1.0 - w) + g * w
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for k in n * n:
		var v := buf[k] / 255.0
		img.set_pixel(k % n, k / n, Color(v, v, v))
	return lin_img(img)

# ------------------------------------------------------------------ colour textures, linearised
## Compatibility filters textures before it decodes sRGB, so mipmaps of a contrasty map come out
## darker than on the web. Colour maps are converted to linear bytes once, and their mipmaps are
## built from the linear values; the shader samples them raw.
func lin_img(img: Image) -> ImageTexture:
	img.clear_mipmaps()
	if img.get_format() != Image.FORMAT_RGB8 and img.get_format() != Image.FORMAT_RGBA8: img.convert(Image.FORMAT_RGBA8)
	img.srgb_to_linear()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func lin_tex(path: String) -> ImageTexture:
	return lin_img((load(path) as Texture2D).get_image())

# ------------------------------------------------------------------ materials
func lit(m: ShaderMaterial) -> ShaderMaterial:
	var key := lin3(c("key")) * KEY_I
	m.set_shader_parameter("key_lin", key)
	m.set_shader_parameter("sky_lin", lin3(c("fill")) * FILL_I)
	m.set_shader_parameter("ground_lin", lin3(c("table")) * 0.5 * FILL_I)
	m.set_shader_parameter("fog_lin", lin3(c("room")))
	m.set_shader_parameter("fog_range", FOG)
	m.set_shader_parameter("out_scale", OUT_SCALE)
	return m

## One material per palette role: paint x grain (repeat 2), matte. noGrain: plain paint.
func paint(role: String, rough := 0.8, no_grain := false) -> ShaderMaterial:
	var k := "%s|%s|%s" % [role, rough, no_grain]
	if mats.has(k): return mats[k]
	var m := ShaderMaterial.new(); m.shader = wood_shader
	m.set_shader_parameter("color_lin", lin3(c(role)))
	if not no_grain:
		m.set_shader_parameter("map", grain)
		m.set_shader_parameter("repeat", Vector2(2, 2))
	m.set_shader_parameter("rough", rough)
	mats[k] = lit(m)
	return m

func textured(tex: Texture2D, rough: float, flip := false, color := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = wood_shader
	m.set_shader_parameter("color_lin", lin3(color))
	m.set_shader_parameter("map", tex)
	m.set_shader_parameter("flip_y", flip)
	m.set_shader_parameter("rough", rough)
	return lit(m)

# ------------------------------------------------------------------ geometry (three.js generators)
## A triangle is [p0, p1, p2, uv0, uv1, uv2], counter-clockwise from the front (three.js order);
## to_mesh() reverses it for Godot and gives each triangle its own face normal (flat shading).
func tri(a, b, cc, ua, ub, uc) -> Array: return [a, b, cc, ua, ub, uc]

func orient(tris: Array) -> Array:   # convex pieces centred on the origin: faces point outward
	for t in tris:
		var nn: Vector3 = (t[1] - t[0]).cross(t[2] - t[0])
		if nn.dot((t[0] + t[1] + t[2]) / 3.0) < 0:
			var tmp = t[1]; t[1] = t[2]; t[2] = tmp
			tmp = t[4]; t[4] = t[5]; t[5] = tmp
	return tris

func quad(out: Array, a, b, cc, d, ua, ub, uc, ud) -> void:
	out.append(tri(a, b, d, ua, ub, ud)); out.append(tri(b, cc, d, ub, uc, ud))

## three.js r160 generators, vertex for vertex and in the same index order, so the seeded carve
## below moves the same vertices by the same offsets as on the web.
## Each builds [positions, uvs, indices]; tris() expands them into triangles.
func tris(g: Array) -> Array:
	var pos: PackedVector3Array = g[0]; var uv: PackedVector2Array = g[1]; var idx: PackedInt32Array = g[2]
	var out := []
	for t in range(0, idx.size(), 3):
		out.append(tri(pos[idx[t]], pos[idx[t + 1]], pos[idx[t + 2]], uv[idx[t]], uv[idx[t + 1]], uv[idx[t + 2]]))
	return out

## CylinderGeometry(rt, rb, h, seg): torso, then the top and bottom caps.
func cylinder(rt: float, rb: float, h: float, seg: int) -> Array:
	var pos := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	var hh := h / 2.0
	for y in 2:
		var v := float(y); var r := v * (rb - rt) + rt
		for x in seg + 1:
			var u := float(x) / seg; var th := u * TAU
			pos.append(Vector3(r * sin(th), -v * h + hh, r * cos(th))); uv.append(Vector2(u, 1 - v))
	for x in seg:
		var a := x; var b := seg + 1 + x; var cc := seg + 1 + x + 1; var d := x + 1
		idx.append_array([a, b, d, b, cc, d])
	for top in [true, false]:
		var r := rt if top else rb; var sg := 1.0 if top else -1.0
		var c0 := pos.size()
		for x in seg:
			pos.append(Vector3(0, hh * sg, 0)); uv.append(Vector2(0.5, 0.5))
		var e0 := pos.size()
		for x in seg + 1:
			var th := float(x) / seg * TAU
			pos.append(Vector3(r * sin(th), hh * sg, r * cos(th))); uv.append(Vector2(cos(th) * 0.5 + 0.5, sin(th) * 0.5 * sg + 0.5))
		for x in seg:
			var cc := c0 + x; var i := e0 + x
			if top: idx.append_array([i, i + 1, cc])
			else: idx.append_array([i + 1, i, cc])
	return tris([pos, uv, idx])

## SphereGeometry(r, ws, hs), full sphere.
func sphere(r: float, ws: int, hs: int) -> Array:
	var pos := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	for iy in hs + 1:
		var v := float(iy) / hs
		var uo := 0.5 / ws if iy == 0 else (-0.5 / ws if iy == hs else 0.0)
		for ix in ws + 1:
			var u := float(ix) / ws
			pos.append(Vector3(-r * cos(u * TAU) * sin(v * PI), r * cos(v * PI), r * sin(u * TAU) * sin(v * PI)))
			uv.append(Vector2(u + uo, 1 - v))
	for iy in hs:
		for ix in ws:
			var a := iy * (ws + 1) + ix + 1; var b := iy * (ws + 1) + ix
			var cc := (iy + 1) * (ws + 1) + ix; var d := (iy + 1) * (ws + 1) + ix + 1
			if iy != 0: idx.append_array([a, b, d])
			if iy != hs - 1: idx.append_array([b, cc, d])
	return tris([pos, uv, idx])

func sph_uv(v: Vector3) -> Vector2:
	return Vector2(atan2(v.z, -v.x) / TAU + 0.5, atan2(-v.y, Vector2(v.x, v.z).length()) / PI + 0.5)

func lerp3(a: Vector3, b: Vector3, t: float) -> Vector3: return a + (b - a) * t   # three's Vector3.lerp

## IcosahedronGeometry(r, 1): PolyhedronGeometry.subdivideFace with two columns, spherical uv.
func icosa(r: float) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var vs := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var ix := [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var out := []
	for f in range(0, ix.size(), 3):
		var a: Vector3 = vs[ix[f]]; var b: Vector3 = vs[ix[f + 1]]; var cc: Vector3 = vs[ix[f + 2]]
		var v := [[a, lerp3(a, b, 0.5), b], [lerp3(a, cc, 0.5), lerp3(lerp3(a, cc, 0.5), lerp3(b, cc, 0.5), 1.0)], [cc]]
		for q in [[v[0][1], v[1][0], v[0][0]], [v[0][1], v[1][1], v[1][0]], [v[0][2], v[1][1], v[0][1]], [v[1][1], v[2][0], v[1][0]]]:
			var p0: Vector3 = q[0].normalized() * r; var p1: Vector3 = q[1].normalized() * r; var p2: Vector3 = q[2].normalized() * r
			out.append(tri(p0, p1, p2, sph_uv(p0), sph_uv(p1), sph_uv(p2)))
	return out

## EllipseCurve.getPoint for a counter-clockwise arc.
func arc_pt(cx: float, cy: float, r: float, a0: float, a1: float, t: float) -> Vector2:
	var da := a1 - a0
	while da < 0: da += TAU
	var a := a0 + t * da
	return Vector2(cx + r * cos(a), cy + r * sin(a))

## CapsuleGeometry(r, length, 2, radial): two Path.absarc, getPoints(2) (an arc in 4 steps, the
## straight side as a line), then a LatheGeometry. Points equal to the previous one are dropped.
func capsule(r: float, length: float, radial: int) -> Array:
	var pts := []
	for k in 5: pts.append(arc_pt(0, -length / 2, r, PI * 1.5, 0, k / 4.0))
	for k in 5:
		var p := arc_pt(0, length / 2, r, 0, PI * 0.5, k / 4.0)
		if p != pts[-1]: pts.append(p)
	var pos := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	var inv := 1.0 / radial
	for i in radial + 1:
		var phi := i * inv * TAU
		for j in pts.size():
			pos.append(Vector3(pts[j].x * sin(phi), pts[j].y, pts[j].x * cos(phi))); uv.append(Vector2(float(i) / radial, float(j) / (pts.size() - 1)))
	for i in radial:
		for j in pts.size() - 1:
			var base := j + i * pts.size()
			var a := base; var b := base + pts.size(); var cc := base + pts.size() + 1; var d := base + 1
			idx.append_array([a, b, d, cc, d, b])
	return tris([pos, uv, idx])

## TorusGeometry(radius, tube, radialSegments, tubularSegments, arc).
func torus(rr: float, tube: float, rs: int, ts: int, arc: float) -> Array:
	var pos := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	for j in rs + 1:
		for i in ts + 1:
			var u := float(i) / ts * arc; var v := float(j) / rs * PI * 2
			pos.append(Vector3((rr + tube * cos(v)) * cos(u), (rr + tube * cos(v)) * sin(u), tube * sin(v)))
			uv.append(Vector2(float(i) / ts, float(j) / rs))
	for j in range(1, rs + 1):
		for i in range(1, ts + 1):
			var a := (ts + 1) * j + i - 1; var b := (ts + 1) * (j - 1) + i - 1; var cc := (ts + 1) * (j - 1) + i; var d := (ts + 1) * j + i
			idx.append_array([a, b, d, b, cc, d])
	return tris([pos, uv, idx])

## The demo's chamferBox: an extruded rectangle with a 45-degree bevel on its top and bottom edges,
## with ExtrudeGeometry's world-unit uv (caps: x, -z; walls: x or -z along, 1 - height).
func chamfer_box(w: float, h: float, d: float, b: float) -> Array:
	var depth := maxf(h - 2 * b, 0.001)
	var x := w / 2 - b; var z := d / 2 - b
	var rect := func(hx: float, hz: float, y: float) -> Array:
		return [Vector3(-hx, y, -hz), Vector3(hx, y, -hz), Vector3(hx, y, hz), Vector3(-hx, y, hz)]
	var rings := [rect.call(x, z, depth / 2 + b), rect.call(x + b, z + b, depth / 2), rect.call(x + b, z + b, -depth / 2), rect.call(x, z, -depth / 2 - b)]
	var out := []
	var cap_uv := func(p: Vector3) -> Vector2: return Vector2(p.x, -p.z)
	for capi in [0, 3]:
		var r: Array = rings[capi]
		out.append(tri(r[0], r[1], r[2], cap_uv.call(r[0]), cap_uv.call(r[1]), cap_uv.call(r[2])))
		out.append(tri(r[0], r[2], r[3], cap_uv.call(r[0]), cap_uv.call(r[2]), cap_uv.call(r[3])))
	for k in 3:
		var r1: Array = rings[k]; var r2: Array = rings[k + 1]
		for i in 4:
			var j := (i + 1) % 4
			var along_x := absf(r1[i].z - r1[j].z) < absf(r1[i].x - r1[j].x)
			var wuv := func(p: Vector3) -> Vector2: return Vector2(p.x if along_x else -p.z, 1.0 - (p.y + depth / 2))
			quad(out, r1[i], r1[j], r2[j], r2[i], wuv.call(r1[i]), wuv.call(r1[j]), wuv.call(r2[j]), wuv.call(r2[i]))
	return orient(out)

func box(w: float, h: float, d: float) -> Array:
	return chamfer_box(w, h, d, 0.0001)

func circle(r: float, seg: int) -> Array:   # facing +z
	var out := []
	for i in seg:
		var a := float(i) / seg * TAU; var b := float(i + 1) / seg * TAU
		var pa := Vector3(r * cos(a), r * sin(a), 0); var pb := Vector3(r * cos(b), r * sin(b), 0)
		out.append(tri(Vector3.ZERO, pa, pb, Vector2(0.5, 0.5), Vector2(pa.x / r, pa.y / r) * 0.5 + Vector2(0.5, 0.5), Vector2(pb.x / r, pb.y / r) * 0.5 + Vector2(0.5, 0.5)))
	return out

func plane(w: float, h: float) -> Array:    # facing +z, uv (0,0) bottom-left
	var out := []
	quad(out, Vector3(-w / 2, -h / 2, 0), Vector3(w / 2, -h / 2, 0), Vector3(w / 2, h / 2, 0), Vector3(-w / 2, h / 2, 0),
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	return out

func ring_geo(r0: float, r1: float, seg: int) -> Array:
	var out := []
	for i in seg:
		var a := float(i) / seg * TAU; var b := float(i + 1) / seg * TAU
		quad(out, Vector3(r0 * cos(a), r0 * sin(a), 0), Vector3(r1 * cos(a), r1 * sin(a), 0), Vector3(r1 * cos(b), r1 * sin(b), 0), Vector3(r0 * cos(b), r0 * sin(b), 0),
			Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	return out

## JavaScript's toFixed(3) as a key: a tiny negative and zero are different keys, as on the web.
func jkey(x: float) -> String: return ("-" if x < 0.0 else "") + str(int(floor(absf(x) * 1000.0 + 0.5)))

## Knife facets: move each vertex by a seeded offset keyed by its position, so shared corners stay shut.
func carve(tris: Array, amt: float) -> Array:
	var offs := {}
	for t in tris:
		for k in 3:
			var p: Vector3 = t[k]
			var key := "%s,%s,%s" % [jkey(p.x), jkey(p.y), jkey(p.z)]
			if not offs.has(key):
				offs[key] = Vector3((rnd() - 0.5) * 2 * amt, (rnd() - 0.5) * 2 * amt, (rnd() - 0.5) * 2 * amt)
			t[k] = p + offs[key]
	return tris

## An open vessel from a carved cylinder(): the wall, the wall again wound the other way (its inside)
## and the base, without the lid. Carve the closed cylinder first so the seeded jitter stays in step.
func open_top(t: Array, seg: int) -> Array:
	var out := t.slice(0, 2 * seg)
	for w in t.slice(0, 2 * seg): out.append(tri(w[0], w[2], w[1], w[3], w[5], w[4]))
	out.append_array(t.slice(3 * seg))
	return out

func to_mesh(tris: Array) -> ArrayMesh:
	var v := PackedVector3Array(); var nrm := PackedVector3Array(); var uv := PackedVector2Array()
	for t in tris:
		var fn: Vector3 = (t[1] - t[0]).cross(t[2] - t[0]).normalized()
		for k in [0, 2, 1]:   # Godot: clockwise front faces
			v.append(t[k]); nrm.append(fn); uv.append(t[k + 3])
	var a := []; a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v; a[Mesh.ARRAY_NORMAL] = nrm; a[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m

func xform(pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot, EULER_ORDER_XYZ).scaled_local(scl), pos)

func part(g: Node3D, tris: Array, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = to_mesh(tris); mi.material_override = m; mi.transform = xform(pos, rot, scl)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	return mi

func group(parent: Node3D, pos := Vector3.ZERO, rot_y := 0.0) -> Node3D:
	var g := Node3D.new(); g.position = pos; g.rotation.y = rot_y
	if parent: parent.add_child(g)
	return g

# ------------------------------------------------------------------ the models (GLB, flat-shaded)
var geom := {}
## Triangles of the model's first mesh, centred on x/z with its base on y = 0 (as the demo).
func model_tris(name: String) -> Array:
	if geom.has(name): return geom[name]
	var root: Node = (load("res://models/%s.glb" % name) as PackedScene).instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var xf: Transform3D = mi.transform
	var a := mi.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var aabb := AABB(xf * pos[0], Vector3.ZERO)
	for p in pos: aabb = aabb.expand(xf * p)
	var off := Vector3(-(aabb.position.x + aabb.end.x) / 2, -aabb.position.y, -(aabb.position.z + aabb.end.z) / 2)
	var out := []
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]; var i1 := idx[t + 2]; var i2 := idx[t + 1]   # back to counter-clockwise
		out.append(tri(xf * pos[i0] + off, xf * pos[i1] + off, xf * pos[i2] + off, uv[i0], uv[i1], uv[i2]))
	root.free()
	geom[name] = [out, aabb.size.y]
	return geom[name]

func model(name: String, height: float, m: Material, wide := 1.0, deep := 1.0) -> Node3D:
	var gd: Array = model_tris(name)
	var s: float = height / gd[1]
	var g := Node3D.new()
	var mi := MeshInstance3D.new(); mi.mesh = to_mesh(gd[0]); mi.material_override = m
	mi.scale = Vector3(s * wide, s, s * deep); g.add_child(mi)
	return g

## The demo's raycast onto the shop's blank sign board: nearest hit along -z from (0, y, 5).
func ray_z(name: String, scl: Vector3, y: float) -> float:
	var best := -INF
	for t in model_tris(name)[0]:
		var hit = Geometry3D.ray_intersects_triangle(Vector3(0, y, 5), Vector3(0, 0, -1), t[0] * scl, t[1] * scl, t[2] * scl)
		if hit != null and hit.z > best: best = hit.z
	return best if best > -INF else 0.4

# ------------------------------------------------------------------ live text on signs and cards
class TextCanvas extends Control:
	var lines: Array; var fnt: Font; var fs: int; var bg: Color; var ink: Color
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), bg)
		var asc := fnt.get_ascent(fs); var desc := fnt.get_descent(fs)
		for i in lines.size():
			var s: String = lines[i]
			var wdt := fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var k := minf(1.0, (size.x - 24) / wdt)   # canvas fillText maxWidth squeezes the text
			var cy := size.y * (i + 0.5) / lines.size()
			draw_set_transform(Vector2(size.x / 2, cy), 0, Vector2(k, 1))
			draw_string(fnt, Vector2(-wdt / 2, (asc - desc) / 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

var pending_labels := []
## A paper or painted sign with live text: drawn once in a SubViewport, then kept as a mipmapped texture.
func label(lines: Array, w: int, h: int, role := "paper") -> ShaderMaterial:
	var vp := SubViewport.new(); vp.size = Vector2i(w, h); vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var tc := TextCanvas.new(); tc.size = Vector2(w, h)
	tc.lines = lines; tc.fnt = font; tc.fs = int(minf(float(h) / lines.size() * 0.62, 64)); tc.bg = c(role); tc.ink = c("ink")
	vp.add_child(tc); add_child(vp)
	var m := textured(vp.get_texture(), 0.85, true)
	pending_labels.append([vp, m])
	return m

func bake_labels() -> void:
	await RenderingServer.frame_post_draw
	for pl in pending_labels:
		var img: Image = pl[0].get_texture().get_image()
		pl[1].set_shader_parameter("map", lin_img(img))
		pl[0].queue_free()

# ------------------------------------------------------------------ pieces
func loaf(kind: String, pos := Vector3.ZERO, s := 1.0) -> Node3D:
	var g := Node3D.new(); g.position = pos; g.scale = Vector3.ONE * s
	if kind == "round":
		part(g, carve(sphere(0.07, 7, 4), 0.004), paint("paint-ochre"), Vector3.ZERO, Vector3(0, rnd() * 3, 0), Vector3(1, 0.62, 1))
		for dx in [-0.022, 0.022]:
			part(g, box(0.008, 0.008, 0.07), paint("paint-brown"), Vector3(dx, 0.04, 0), Vector3(0, 0.3, 0), Vector3.ONE, false)
	else:
		part(g, carve(capsule(0.034, 0.16, 6), 0.003), paint("paint-ochre"), Vector3.ZERO, Vector3(0, 0, PI / 2), Vector3(1, 1, 0.8))
	return g

## One figurine body for every character: base, legs, coat, arms, head, and one silhouette piece.
func figurine(o: Dictionary) -> Node3D:
	var g := Node3D.new(); var C := 0.006
	part(g, carve(cylinder(0.14, 0.15, 0.045, 10), C), paint("paint-brown"), Vector3(0, 0.0225, 0))
	part(g, carve(cylinder(0.07, 0.085, 0.2, 8), C), paint(o.legs), Vector3(0, 0.145, 0))
	part(g, carve(cylinder(0.075, 0.115, 0.21, 8), C), paint(o.coat), Vector3(0, 0.345, 0))
	for s in [-1, 1]:
		part(g, carve(capsule(0.026, 0.13, 6), C * 0.6), paint(o.coat), Vector3(s * 0.1, 0.35, 0.02), Vector3(-0.35, 0, s * 0.22))
	part(g, carve(icosa(0.068), C * 0.8), paint("wood-bare", 0.9), Vector3(0, 0.505, 0))
	for s in [-1, 1]:
		part(g, box(0.012, 0.016, 0.01), paint("ink", 0.8, true), Vector3(s * 0.024, 0.515, 0.064), Vector3.ZERO, Vector3.ONE, false)
	if o.has("hat"):
		part(g, carve(cylinder(0.11, 0.11, 0.014, 10), C * 0.4), paint(o.hat), Vector3(0, 0.56, 0))
		part(g, carve(cylinder(0.055, 0.065, 0.07, 8), C * 0.4), paint(o.hat), Vector3(0, 0.6, 0))
	if o.get("basket", false):
		part(g, carve(cylinder(0.075, 0.06, 0.08, 8), C * 0.5), paint("paint-ochre"), Vector3(-0.13, 0.27, 0.06))
		g.add_child(loaf("long", Vector3(-0.13, 0.33, 0.06), 0.6))
	g.scale = Vector3.ONE * o.get("scale", 1.0)
	return g

func shop(o: Dictionary) -> Node3D:
	var h: float = o.h
	var bare: bool = o.get("bare", false)
	var m: Material = paint("wood-bare", 0.9) if bare else textured(lin_tex("res://textures/bakery_%s.jpg" % o.paint), 0.82)
	var g := model("bakery", h, m, 1.1, 0.65)
	if not bare:
		var y := h * 0.49
		var hz := ray_z("bakery", g.get_child(0).scale, y)
		var w := 0.36 * h; var sh := 0.075 * h
		part(g, plane(w, sh), label([o.sign], 512, roundi(512 * sh / w), "paint-cream"), Vector3(0, y, hz + 0.006), Vector3.ZERO, Vector3.ONE, false)
	return g

# ------------------------------------------------------------------ scene
func _ready() -> void:
	font = load("res://fonts/Gelasio-Variable.woff")   # the demo's bundled face (variable; default instance is 400)
	grain = make_grain()
	var world := group(self)

	var tm := textured(lin_tex("res://textures/table_color.jpg"), 0.7, true, c("table"))
	tm.set_shader_parameter("repeat", Vector2(26.0 / 12.0, 18.0 / 6.0))
	tm.set_shader_parameter("use_normal", true)
	# three.js builds the tangent frame from screen derivatives and scales both axes by the longer one:
	# a tile stretched 12 x 6 units halves the x tilt of the normal map. Same here.
	tm.set_shader_parameter("normal_scale", Vector2(0.5, 1.0))
	tm.set_shader_parameter("normal_tex", load("res://textures/table_normal.jpg"))
	part(world, plane(26, 18), tm, Vector3.ZERO, Vector3(-PI / 2, 0, 0), Vector3.ONE, false)

	part(world, chamfer_box(7.3, 0.18, 4.55, 0.03), paint("paint-brown"), Vector3(0, 0.09, 0))
	part(world, chamfer_box(7.0, 0.06, 4.25, 0.015), paint("wood-bare", 0.9), Vector3(0, 0.19, 0))
	var board := group(world, Vector3(0, 0.22, 0))

	var sm := textured(lin_tex("res://textures/cobble_color.jpg"), 0.88, true, c("wood-bare"))
	sm.set_shader_parameter("repeat", Vector2(6.7 / 1.5, 1.42 / 1.5))
	sm.set_shader_parameter("use_normal", true); sm.set_shader_parameter("normal_tex", load("res://textures/cobble_normal.jpg"))
	sm.set_shader_parameter("normal_scale", Vector2(1.4, -1.4))
	part(board, plane(6.7, 1.42), sm, Vector3(0, 0.004, -0.04), Vector3(-PI / 2, 0, 0), Vector3.ONE, false)

	for s in [{"x": -2.8, "h": 1.8, "paint": "cream", "sign": "BREAD"}, {"x": -1.48, "h": 2.1, "paint": "blue", "sign": "CAKES & BUNS"},
			{"x": -0.1, "h": 1.9, "paint": "ochre", "sign": "FLOUR"}, {"x": 1.32, "h": 2.2, "paint": "green", "sign": "PIES"},
			{"x": 2.62, "h": 1.5, "bare": true}]:
		var g := shop(s); g.position = Vector3(s.x, 0, -1.4); board.add_child(g)

	var stall := model("stall", 1.25, textured(lin_tex("res://textures/stall_finish.jpg"), 0.82))
	part(stall, plane(0.34, 0.14), label(["Rye 3 · Buns 1"], 512, 211), Vector3(0.18, 0.3, 0.33), Vector3(-0.12, 0, 0))
	stall.position = Vector3(-2.2, 0, 1.45); stall.rotation.y = 0.15; board.add_child(stall)
	var baker := model("baker", 0.68, textured(lin_tex("res://textures/baker_finish.jpg"), 0.82))
	baker.position = Vector3(-0.45, 0, 0.2); baker.rotation.y = 0.35; board.add_child(baker)
	var customer := figurine({"legs": "paint-blue", "coat": "paint-green", "hat": "paint-brown", "basket": true})
	customer.position = Vector3(-1.75, 0, 0.55); customer.rotation.y = 0.9; board.add_child(customer)
	var child := figurine({"legs": "paint-blue", "coat": "paint-red", "hat": "paint-ochre", "scale": 0.75})
	child.position = Vector3(2.1, 0, 0.75); child.rotation.y = -0.5; board.add_child(child)
	var cart_a := model("cart", 0.55, textured(lin_tex("res://textures/cart_tc.jpg"), 0.82))
	cart_a.position = Vector3(0.85, 0, 0.3); cart_a.rotation.y = -0.25; board.add_child(cart_a)
	var cart_b := model("cart", 0.5, textured(lin_tex("res://textures/cart_red.jpg"), 0.82))
	cart_b.position = Vector3(2.6, 0, 1.5); cart_b.rotation.y = 0.5; board.add_child(cart_b)
	for p in [Vector3(-0.2, 0.04, 1.6), Vector3(0.25, 0.04, 1.75), Vector3(3.0, 0.04, 0.2)]:
		board.add_child(loaf("round", p))
	part(board, carve(chamfer_box(0.34, 0.16, 0.26, 0.012), 0.006), paint("wood-bare", 0.9), Vector3(3.05, 0.08, -0.55))

	# the accent's one job: what the player can act on now (the loaded cart), pulsing 6% at 1.2 Hz
	var rm := ShaderMaterial.new(); rm.shader = ring_shader
	rm.set_shader_parameter("color_lin", lin3(c("accent"))); rm.set_shader_parameter("fog_lin", lin3(c("room")))
	rm.set_shader_parameter("fog_range", FOG); rm.set_shader_parameter("out_scale", OUT_SCALE)
	rm.render_priority = 1
	part(board, ring_geo(0.56, 0.6, 48), rm, Vector3(0.85, 0.012, 0.3), Vector3(-PI / 2, 0, 0), Vector3.ONE * (1 + 0.06 * sin(T * TAU * 1.2)), false)

	# full-size objects hold the scale: rolling pin, cup on its saucer, a stack of cards, a candle
	var pin := group(world, Vector3(-4.4, 0.2, 2.9), 0.45)
	part(pin, carve(cylinder(0.2, 0.2, 2.6, 10), 0.01), paint("wood-bare", 0.9), Vector3.ZERO, Vector3(0, 0, PI / 2))
	for s in [-1, 1]:
		part(pin, carve(cylinder(0.07, 0.08, 0.55, 8), 0.006), paint("wood-bare", 0.9), Vector3(s * 1.57, 0, 0), Vector3(0, 0, PI / 2))
	var cup := group(world, Vector3(-4.7, 0, -1.7))
	part(cup, carve(cylinder(0.72, 0.6, 0.06, 14), 0.008), paint("paint-cream", 0.5), Vector3(0, 0.03, 0))
	part(cup, open_top(carve(cylinder(0.48, 0.35, 0.8, 14), 0.008), 14), paint("paint-blue", 0.5), Vector3(0, 0.46, 0))
	# coffee 0.04 below the rim, its corners turned onto the wall's (half a segment) and kept inside it
	part(cup, circle(0.46, 14), paint("paint-brown", 0.3, true), Vector3(0, 0.82, 0), Vector3(-PI / 2, 0, PI / 14))
	part(cup, carve(torus(0.17, 0.045, 6, 10, PI * 1.3), 0.004), paint("paint-blue", 0.5), Vector3(0.5, 0.5, 0), Vector3(0, 0, -PI * 0.65))
	var cards := group(world, Vector3(4.75, 0, 1.7), -0.3)
	for i in 4:
		var px := rnd() * 0.06; var pz := rnd() * 0.06; var ry := (rnd() - 0.5) * 0.2
		part(cards, box(0.9, 0.012, 0.6), paint("paper", 0.9, true), Vector3(px, 0.006 + i * 0.013, pz), Vector3(0, ry, 0))
	part(cards, plane(0.86, 0.56), label(["Today's bake", "rye · seed · honey"], 512, 334), Vector3(0.02, 0.06, 0.02), Vector3(-PI / 2, 0, 0), Vector3.ONE, false)
	var candle := group(world, Vector3(3.95, 0, -2.75))
	part(candle, carve(cylinder(0.5, 0.55, 0.06, 12), 0.006), paint("paint-brown", 0.5), Vector3(0, 0.03, 0))
	part(candle, carve(cylinder(0.2, 0.22, 1.0, 10), 0.006), paint("paint-cream", 0.6, true), Vector3(0, 0.56, 0))

	build_env()
	build_hud()
	bake_labels()

func build_env() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color.WHITE; sun.light_energy = 1.0   # colour and intensity live in wood.gdshader
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 22.0
	# Compatibility ignores shadow_blur; the 4096 atlas over 22 units gives the closest penumbra
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 2.0   # 1.0 left lit faces about 1.5% darker (self-shadowing in the filter)
	add_child(sun)
	sun.look_at_from_position(KEY_POS, Vector3.ZERO)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	var bg := c("room").srgb_to_linear() * OUT_SCALE
	env.background_color = Color(bg.r, bg.g, bg.b).linear_to_srgb()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR   # black: wood.gdshader adds the fill
	env.ambient_light_color = Color.BLACK; env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)

	var cam := Camera3D.new(); cam.fov = 36; cam.near = 0.1; cam.far = 60
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 7.0, 8.2), Vector3(0, 0.35, -0.3))
	cam.position.x += sin(T * 0.13) * 0.05   # idle sway, posed at the frame time
	cam.current = true

	var layer := CanvasLayer.new(); layer.layer = 1; add_child(layer)
	var rect := ColorRect.new(); rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var lm := ShaderMaterial.new(); lm.shader = preload("res://lens.gdshader")
	lm.set_shader_parameter("in_scale", 1.0 / OUT_SCALE)
	rect.material = lm; layer.add_child(rect)

# ------------------------------------------------------------------ interface: paper cards
func small_caps(s: String, size: int) -> String:
	var out := ""; var small := int(round(size * 0.7))   # Chrome synthesises small caps at 0.7 of the size
	for ch in s:
		if ch != ch.to_upper():
			out += "[font_size=%d]%s[/font_size]" % [small, ch.to_upper()]
		else:
			out += ch
	return out

## CSS height is fixed here (content + half-leading), so the rotated card lands where the browser puts it.
func card(pos: Vector2, width: float, height: float, deg: float, pad: Vector2, nudge := 0.0) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = c("paper"); sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.3); sb.shadow_size = 8; sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = pad.x; sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y + nudge; sb.content_margin_bottom = pad.y - nudge   # nudge: glyph placement vs Chrome
	pc.add_theme_stylebox_override("panel", sb)
	pc.position = pos; pc.custom_minimum_size = Vector2(width, height); pc.size = Vector2(width, height)
	pc.rotation_degrees = deg
	pc.resized.connect(func(): pc.pivot_offset = pc.size / 2)
	return pc

func text(s: String, size: int, line_h: float, center := false) -> Label:
	var l := Label.new(); l.text = s
	l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c("ink"))
	var fh := font.get_height(size)
	l.add_theme_constant_override("line_spacing", int(round(line_h - fh)))
	var lead := StyleBoxEmpty.new()   # CSS half-leading above the first line and below the last
	lead.content_margin_top = (line_h - fh) / 2.0; lead.content_margin_bottom = (line_h - fh) / 2.0
	l.add_theme_stylebox_override("normal", lead)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func build_hud() -> void:
	var hud := CanvasLayer.new(); hud.layer = 2; add_child(hud)
	var day := card(Vector2(20, 18), 320, 12 + 24 + 6 + 16 * 1.32 + 12, -1.4, Vector2(16, 12)); hud.add_child(day)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 6); day.add_child(vb)
	var line := MarginContainer.new()   # the h3 in CSS's 24 px line box: a taller font box overhangs it by the half-leading
	var lead := int(round((24 - font.get_height(20)) / 2.0))
	line.add_theme_constant_override("margin_top", lead); line.add_theme_constant_override("margin_bottom", lead)
	vb.add_child(line)
	var h3 := RichTextLabel.new(); h3.bbcode_enabled = true; h3.fit_content = true; h3.scroll_active = false
	var spaced := FontVariation.new(); spaced.base_font = font
	spaced.spacing_glyph = 1   # letter-spacing .03em (0.6 px; Godot spacing is whole pixels)
	h3.add_theme_font_override("normal_font", spaced); h3.add_theme_font_size_override("normal_font_size", 20)
	h3.add_theme_color_override("default_color", c("ink"))
	h3.text = small_caps("Day 12 · 5:40 in the morning", 20)
	line.add_child(h3)
	vb.add_child(text("Three orders before the market bell", 16, 16 * 1.32))
	var spoken := card(Vector2(360, 18), 520, 10 + 2 * 24 * 1.36 + 10, -0.5, Vector2(20, 10)); hud.add_child(spoken)
	spoken.add_child(text("The first loaves are out. Which cart goes up the hill before the bell?", 24, 24 * 1.36, true))
