extends Node3D
## Port of cel-shaded-3d/demo.html?frame=key-scene (noon palette, t = 1.25 s).

const P := {
	"ink": "#24203A", "key": "#FFF3DA", "shadow-tint": "#8FA0E8", "sky-top": "#3A8EE6",
	"sky-horizon": "#CFEFFF", "cloud": "#FFFFFF", "base-grass": "#6CCB4A", "base-rock": "#D09A62",
	"base-wood": "#C27A42", "base-roof": "#D9483B", "base-cloth": "#2F72D6", "base-skin": "#FFCFAA",
	"base-hair": "#9B6BE0", "accent": "#FF3FA0",
}
const T := 1.25
const FOG := Vector2(30.0, 210.0)
## Slot tables of the generated models: [palette role, multiplier] (see the models' README).
const COURIER_SLOTS := [["base-skin", 1.0], ["base-hair", 1.0], ["base-cloth", 1.0], ["base-cloth", 0.62],
	["base-roof", 1.0], ["base-wood", 1.0], ["base-wood", 0.55], ["cloud", 1.0], ["ink", 1.0]]
const WINDMILL_SLOTS := [["base-rock", 1.0], ["base-rock", 0.82], ["base-roof", 1.0], ["base-wood", 1.0],
	["base-wood", 0.7], ["cloud", 1.0], ["cloud", 0.78]]
var KEY_DIR := Vector3(-8, 12, 6).normalized()
var toon_shader := preload("res://toon.gdshader")
var slots_shader := preload("res://toon_slots.gdshader")
var outline_shader := preload("res://outline.gdshader")
var mats := {}
var outline_mats := {}
var smooth_cache := {}

func c(role: String) -> Color: return Color(P[role])
## Linear colour as a Vector3: a Color would be converted again by Forward+ but not by Compatibility.
func lin3(col: Color) -> Vector3:
	var l := col.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)
func srgb3(col: Color) -> Vector3: return Vector3(col.r, col.g, col.b)

# ------------------------------------------------------------------ materials
func set_light_params(m: ShaderMaterial, rim: bool, receive: bool) -> void:
	m.set_shader_parameter("rim_amount", 0.35 if rim else 0.0)
	m.set_shader_parameter("rim_linear", lin3(c("sky-horizon")))
	m.set_shader_parameter("ambient_linear", lin3(c("shadow-tint")))
	m.set_shader_parameter("fog_srgb", srgb3(c("sky-horizon")))
	m.set_shader_parameter("fog_range", FOG)
	m.set_shader_parameter("receive_shadow", receive)

func mat(role: String, rim := false, receive := true) -> Material:
	var k := "%s|%s|%s" % [role, rim, receive]
	if mats.has(k): return mats[k]
	var m := ShaderMaterial.new()
	m.shader = toon_shader
	m.set_shader_parameter("base_color", c(role))
	set_light_params(m, rim, receive)
	mats[k] = m
	return m

## Material for a generated model whose texture holds palette slots.
func slot_mat(tex: Texture2D, slots: Array, rim: bool, face_slot: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = slots_shader
	m.set_shader_parameter("slot_map", tex)
	var cols := PackedColorArray(); cols.resize(16)
	for i in slots.size():   # the multiplier scales the linear colour, as in the web demo
		var l := c(slots[i][0]).srgb_to_linear() * float(slots[i][1])
		cols[i] = Color(l.r, l.g, l.b).linear_to_srgb()
	m.set_shader_parameter("slot_col", cols)
	m.set_shader_parameter("face_slot", face_slot)
	set_light_params(m, rim, false)
	return m

func outline_mat(w: float) -> Material:
	if outline_mats.has(w): return outline_mats[w]
	var m := ShaderMaterial.new()
	m.shader = outline_shader
	m.set_shader_parameter("ink", c("ink"))
	m.set_shader_parameter("fog_color", c("sky-horizon"))
	m.set_shader_parameter("fog_range", FOG)
	m.set_shader_parameter("width_px", w)
	outline_mats[w] = m
	return m

func add_hull(mi: MeshInstance3D, line: float) -> void:
	if line <= 0.0: return
	var hull := MeshInstance3D.new()
	hull.mesh = mi.mesh
	hull.material_override = outline_mat(line)
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(hull)

# ------------------------------------------------------------------ geometry (three.js equivalents)
## Copies a mesh's arrays and adds the position-averaged normal as vertex colour (n * 0.5 + 0.5).
## replace_normals also makes it the shading normal (generated models: no band patches at UV seams).
func with_smooth(arrays: Array, replace_normals := false) -> ArrayMesh:
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nor: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var acc := {}
	for i in pos.size():
		var key := "%.4f,%.4f,%.4f" % [pos[i].x, pos[i].y, pos[i].z]
		acc[key] = acc.get(key, Vector3.ZERO) + nor[i]
	var cols := PackedColorArray(); cols.resize(pos.size())
	var smooth := PackedVector3Array(); smooth.resize(pos.size())
	for i in pos.size():
		var key := "%.4f,%.4f,%.4f" % [pos[i].x, pos[i].y, pos[i].z]
		var n: Vector3 = acc[key].normalized()
		smooth[i] = n
		cols[i] = Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0)
	arrays[Mesh.ARRAY_COLOR] = cols
	if replace_normals:
		arrays[Mesh.ARRAY_NORMAL] = smooth
		arrays[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func prim(key: String, p: PrimitiveMesh) -> ArrayMesh:
	if smooth_cache.has(key): return smooth_cache[key]
	smooth_cache[key] = with_smooth(p.get_mesh_arrays())
	return smooth_cache[key]

## three.js SphereGeometry(r, ws, hs): same rows, seam and poles as the web demo (Godot's
## SphereMesh uses rings + 1 rows and another start meridian, so cloud silhouettes would differ).
func sphere(r: float, ws: int, hs: int) -> ArrayMesh:
	var key := "s%s,%s,%s" % [r, ws, hs]
	if smooth_cache.has(key): return smooth_cache[key]
	var v := PackedVector3Array(); var n := PackedVector3Array(); var idx := PackedInt32Array()
	for iy in hs + 1:
		var th := float(iy) / hs * PI
		for ix in ws + 1:
			var ph := float(ix) / ws * TAU
			var d := Vector3(-cos(ph) * sin(th), cos(th), sin(ph) * sin(th))
			v.append(d * r); n.append(d.normalized())
	for iy in hs:
		for ix in ws:
			var a := iy * (ws + 1) + ix + 1; var b := iy * (ws + 1) + ix
			var cc := (iy + 1) * (ws + 1) + ix; var d := (iy + 1) * (ws + 1) + ix + 1
			if iy != 0: idx.append_array([a, d, b])        # Godot: clockwise front faces
			if iy != hs - 1: idx.append_array([b, d, cc])
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_INDEX] = idx
	smooth_cache[key] = with_smooth(arr)
	return smooth_cache[key]

func cylinder(rt: float, rb: float, h: float, seg: int) -> ArrayMesh:
	var m := CylinderMesh.new(); m.top_radius = rt; m.bottom_radius = rb; m.height = h
	m.radial_segments = seg; m.rings = 0
	return prim("c%s,%s,%s,%s" % [rt, rb, h, seg], m)

func cone(r: float, h: float, seg: int) -> ArrayMesh:
	return cylinder(0.0, r, h, seg)

func box(x: float, y: float, z: float) -> ArrayMesh:
	var m := BoxMesh.new(); m.size = Vector3(x, y, z)
	return prim("b%s,%s,%s" % [x, y, z], m)

## three.js TorusGeometry(R, tube, radial, tubular): lies in XY, same seams as the web demo
## (TorusMesh lies in XZ: this saves rotating it).
func torus(R: float, tube: float, radial: int, tubular: int) -> ArrayMesh:
	var key := "t%s,%s,%s,%s" % [R, tube, radial, tubular]
	if smooth_cache.has(key): return smooth_cache[key]
	var v := PackedVector3Array(); var n := PackedVector3Array(); var idx := PackedInt32Array()
	for j in radial + 1:
		var a := float(j) / radial * TAU
		for i in tubular + 1:
			var u := float(i) / tubular * TAU
			var p := Vector3((R + tube * cos(a)) * cos(u), (R + tube * cos(a)) * sin(u), tube * sin(a))
			v.append(p); n.append((p - Vector3(R * cos(u), R * sin(u), 0)).normalized())
	for j in range(1, radial + 1):
		for i in range(1, tubular + 1):
			var a := (tubular + 1) * j + i - 1; var b := (tubular + 1) * (j - 1) + i - 1
			var cc := (tubular + 1) * (j - 1) + i; var d := (tubular + 1) * j + i
			idx.append_array([a, d, b, b, d, cc])   # Godot: clockwise front faces
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = n; arr[Mesh.ARRAY_INDEX] = idx
	smooth_cache[key] = with_smooth(arr)
	return smooth_cache[key]

func jround(v: float) -> int: return int(floor(v + 0.5))   # JavaScript Math.round
func hash3(x: float, y: float, z: float) -> float:
	var s := sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453
	return s - floor(s)

## Lower hemisphere (28 x 12), merged, displaced, smooth normals: three's rockGeometry().
func rock(seed: int) -> ArrayMesh:
	var ws := 28; var hs := 12
	var idx_of := {}; var verts: Array[Vector3] = []; var grid := []
	for iy in hs + 1:
		var row := []
		var th := PI / 2 + float(iy) / hs * PI / 2
		for ix in ws + 1:
			var ph := float(ix) / ws * TAU
			var v := Vector3(-cos(ph) * sin(th), cos(th), sin(ph) * sin(th))
			var key := "%.4f,%.4f,%.4f" % [v.x, v.y, v.z]
			if not idx_of.has(key):
				idx_of[key] = verts.size(); verts.append(v)
			row.append(idx_of[key])
		grid.append(row)
	var faces := []
	for iy in hs:
		for ix in ws:
			var a: int = grid[iy][ix + 1]; var b: int = grid[iy][ix]
			var cc: int = grid[iy + 1][ix]; var d: int = grid[iy + 1][ix + 1]
			faces.append([a, b, d])
			if iy != hs - 1: faces.append([b, cc, d])
	for i in verts.size():
		var v := verts[i]
		var n := hash3(jround(v.x * 3), jround(v.y * 4), jround(v.z * 3) + seed)
		var r := (0.86 + 0.22 * n) * (1 + v.y * 0.55)
		verts[i] = Vector3(v.x * r, v.y * (1.0 + 0.5 * hash3(jround(v.x * 2), 7, jround(v.z * 2) + seed)), v.z * r)
	var nor: Array[Vector3] = []; nor.resize(verts.size()); nor.fill(Vector3.ZERO)
	var idx := PackedInt32Array()
	for f in faces:
		var fa: Vector3 = verts[f[0]]; var fb: Vector3 = verts[f[1]]; var fc: Vector3 = verts[f[2]]
		var fn := (fc - fb).cross(fa - fb)          # three: cb x ab, counter-clockwise front
		for k in 3: nor[f[k]] += fn
		idx.append(f[0]); idx.append(f[2]); idx.append(f[1])   # Godot: clockwise front faces
	var a := []; a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array(verts)
	var pn := PackedVector3Array()
	for n in nor: pn.append(n.normalized())
	a[Mesh.ARRAY_NORMAL] = pn
	a[Mesh.ARRAY_INDEX] = idx
	return with_smooth(a)

# ------------------------------------------------------------------ parts
func part(mesh: Mesh, role: String, o := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(role, o.get("rim", false), o.get("receive", true))
	mi.rotation_order = EULER_ORDER_XYZ
	mi.position = o.get("pos", Vector3.ZERO)
	mi.rotation = o.get("rot", Vector3.ZERO)
	mi.scale = o.get("scale", Vector3.ONE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if o.get("cast", true) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_hull(mi, o.get("line", 2.5))
	return mi

func group(pos := Vector3.ZERO) -> Node3D:
	var g := Node3D.new(); g.rotation_order = EULER_ORDER_XYZ; g.position = pos
	return g

func tree(x: float, z: float, s := 1.0, y := 0.6) -> Node3D:
	var g := group(Vector3(x, y, z))
	g.add_child(part(cylinder(0.16, 0.24, 1.6, 7), "base-wood", {"pos": Vector3(0, 0.8, 0)}))
	g.add_child(part(sphere(0.95, 14, 10), "base-grass", {"pos": Vector3(0, 2.1, 0), "scale": Vector3(1, 0.85, 1)}))
	g.add_child(part(sphere(0.65, 12, 8), "base-grass", {"pos": Vector3(0.45, 2.75, 0.1)}))
	g.scale = Vector3.ONE * s
	return g

func island(r: float, seed: int, pos := Vector3.ZERO, depth := -1.0, line := 2.0) -> Node3D:
	if depth < 0: depth = r * 0.9
	var g := group(pos)
	g.add_child(part(cylinder(r, r * 0.97, r * 0.13, 32), "base-grass", {"line": line}))
	g.add_child(part(rock(seed), "base-rock", {"pos": Vector3(0, -r * 0.06, 0),
		"scale": Vector3(r * 0.98, depth, r * 0.98), "line": line}))
	return g

func crate(size := 0.7, tag := false) -> Node3D:
	var g := group()
	g.add_child(part(box(size, size, size), "base-wood", {"pos": Vector3(0, size / 2, 0)}))
	g.add_child(part(box(size * 1.06, size * 0.12, size * 1.06), "base-wood", {"pos": Vector3(0, size * 0.94, 0)}))
	g.add_child(part(box(size * 1.03, size * 1.03, size * 0.14), "base-cloth", {"pos": Vector3(0, size / 2, 0), "line": 2.0}))
	if tag:
		g.add_child(part(box(size * 0.34, size * 0.24, 0.03), "accent",
			{"pos": Vector3(size * 0.2, size * 0.6, size * 0.53), "rot": Vector3(0, 0, -0.18), "line": 2.0}))
	return g

func cloud(x: float, y: float, z: float, s: float) -> Node3D:
	var g := group(Vector3(x, y, z))
	for i in 6:
		var r := 0.6 + hash3(i, s, x) * 0.6
		g.add_child(part(sphere(1, 14, 10), "cloud", {"pos": Vector3((i - 2.5) * 0.9, hash3(i, 2, s) * 0.5, hash3(s, i, 3) * 0.8 - 0.4),
			"scale": Vector3(r * 1.3, r * 0.75, r), "line": 0.0, "cast": false, "receive": false}))
	g.scale = Vector3.ONE * s
	return g

## Places an imported generated model: smooth normals for shading and the hull, the slot material,
## scaled to `height` with its feet on y = 0 and centred (as the web demo's placeModel()).
func place_model(scene: PackedScene, slots: Array, height: float, line: float, rim := false, face_slot := -1) -> Node3D:
	var src := scene.instantiate()
	var root := Node3D.new()
	var box := AABB(); var first := true
	for node in src.find_children("*", "MeshInstance3D", true, false):
		var src_mi := node as MeshInstance3D
		var xf := Transform3D.IDENTITY   # node transform relative to the model root
		var n: Node = src_mi
		while n != src:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var tex: Texture2D = (src_mi.get_active_material(0) as BaseMaterial3D).albedo_texture
		var mi := MeshInstance3D.new()
		mi.name = src_mi.name                # "tower" / "sails": sails turn about the node origin in a game
		mi.mesh = with_smooth(src_mi.mesh.surface_get_arrays(0), true)
		mi.material_override = slot_mat(tex, slots, rim, face_slot)
		mi.transform = xf
		add_hull(mi, line)
		root.add_child(mi)
		var b := xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	src.free()
	var s := height / box.size.y
	var ctr := box.get_center()
	var holder := Node3D.new()
	holder.add_child(root)
	root.scale = Vector3.ONE * s
	root.position = Vector3(-ctr.x * s, -box.position.y * s, -ctr.z * s)
	return holder

# ------------------------------------------------------------------ scene
func _ready() -> void:
	var world := group(); add_child(world)
	var MAIN_TOP := 9 * 0.13 / 2
	world.add_child(island(9, 1, Vector3.ZERO, 8))
	for t in [[-5, 1, 1], [-7, 2.5, 1.2], [-4, -9, 0.9], [-3.5, 4.8, 0.8]]:
		world.add_child(tree(t[0], t[1], t[2], MAIN_TOP))
	for i in 26:   # grass tufts: no outline
		var a := hash3(i, 1, 2) * TAU; var d := 2 + hash3(i, 3, 4) * 6
		world.add_child(part(cone(0.08, 0.32, 4), "base-grass", {"pos": Vector3(cos(a) * d, MAIN_TOP + 0.14, sin(a) * d),
			"rot": Vector3(0, a, 0.2), "line": 0.0, "cast": false}))
	# windmill: generated model, sails at angle 0 (as the frames pose them)
	var wm := group(Vector3(-2, MAIN_TOP, -5))
	wm.rotation.y = 0.35
	wm.add_child(place_model(load("res://models/windmill.glb"), WINDMILL_SLOTS, 6.4, 2.5))
	world.add_child(wm)
	# crates
	for cr in [[4.6, -2.0, 0.7, 0.3, false, 0.0], [4.6, -2.0, 0.6, -0.2, false, 0.7], [5.0, -0.9, 0.7, 0.5, true, 0.0], [-0.6, -6.2, 0.6, 0.1, false, 0.0]]:
		var cn := crate(cr[2], cr[4]); cn.position = Vector3(cr[0], MAIN_TOP + cr[5], cr[1]); cn.rotation.y = cr[3]
		world.add_child(cn)
	# route rings
	var rf := Vector3(5, 5.5, -9); var rt := Vector3(-9.5, 7.5, -45)
	for i in 6:
		var p := rf.lerp(rt, i / 5.0)
		p.y = rf.y + (rt.y - rf.y) * i / 5.0 + 0.15 * sin(T * 2 + i)
		var r := part(torus(1.4, 0.16, 8, 32), "accent", {"pos": p, "line": 2.5, "cast": false})
		var look := rt + Vector3(0, 0.5, -5)
		r.basis = Basis.looking_at(look - rf.lerp(rt, i / 5.0))  # rings are round: facing sign does not matter
		world.add_child(r)
	# far islands, a house on one
	var farA := island(7, 2, Vector3(-11.5, 3, -53), 6)
	farA.add_child(tree(-2.5, 1.5, 1.1, 0.45)); farA.add_child(tree(3, -2, 0.9, 0.45))
	var house := group(Vector3(0.5, 0.45, 0.5))
	house.add_child(part(box(2.2, 1.6, 1.8), "base-rock", {"pos": Vector3(0, 0.8, 0)}))
	house.add_child(part(cone(1.8, 1.3, 4), "base-roof", {"pos": Vector3(0, 2.2, 0), "rot": Vector3(0, PI / 4, 0)}))
	farA.add_child(house); world.add_child(farA)
	var farB := island(9, 3, Vector3(-15, 25, -94), 8); farB.add_child(tree(2, 0, 1.6, 0.6)); world.add_child(farB)
	var farC := island(10, 4, Vector3(-11.5, -12, -125), 9); farC.add_child(tree(-3, 2, 2, 0.65)); world.add_child(farC)
	world.add_child(island(6, 5, Vector3(-64, -4, -127), 5))
	# clouds: no outline
	for cl in [[6, -11, -14, 2.5], [2, -10, -26, 3], [-22, -15, -30, 3], [22, -3, -62, 3.5], [-35, 1, -110, 5], [42, -14, -92, 4],
			[-10, 14, -150, 6], [-30, -8, 6, 3], [30, 8, -150, 6]]:
		world.add_child(cloud(cl[0], cl[1], cl[2], cl[3]))
	# more clouds at three depths, by bearing from the key camera: [deg right, deg up, distance, size]
	# (64-bit floats, not a Vector3: cloud() hashes x, and float32 rounding changes the puffs)
	var fwd := atan2(-13.0, -13.0)
	for cl in [[-30, 9, 55, 2.2], [7, 11, 110, 3], [-37, 3, 180, 9], [26, 4, 190, 8],
			[14, -14, 120, 6], [-22, -9, 75, 3.5], [38, -20, 70, 4]]:
		var h := fwd + deg_to_rad(cl[0]); var el := deg_to_rad(cl[1]); var d: float = cl[2]
		world.add_child(cloud(11.0 + cos(h) * cos(el) * d, 3.6 + sin(el) * d, 3.0 + sin(h) * cos(el) * d, cl[3]))
	# courier: generated model, front +z, 1.75 m, idle bob at t
	var courier := group(Vector3(6, MAIN_TOP + 0.04 * sin(T * PI), -3))
	courier.rotation.y = 0.25
	courier.add_child(place_model(load("res://models/courier.glb"), COURIER_SLOTS, 1.75, 3.0, true, 0))
	add_child(courier)
	build_env()

func build_env() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = c("key")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_normal_bias = 1.5
	sun.shadow_bias = 0.03
	sun.shadow_blur = 0.0
	add_child(sun)
	sun.look_at_from_position(KEY_DIR * 40.0, Vector3.ZERO)

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://sky.gdshader")
	sky_mat.set_shader_parameter("top", c("sky-top"))
	sky_mat.set_shader_parameter("horizon", c("sky-horizon"))
	sky_mat.set_shader_parameter("sun", c("key"))
	sky_mat.set_shader_parameter("sun_dir", KEY_DIR)
	var sky := Sky.new(); sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR   # black: the toon shader adds the ambient
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = false   # fog is mixed in the toon shader
	var we := WorldEnvironment.new(); we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	cam.fov = 50; cam.near = 0.1; cam.far = 1000
	add_child(cam)
	cam.look_at_from_position(Vector3(11, 3.6, 3), Vector3(-2, 0.6, -10))
	cam.current = true
