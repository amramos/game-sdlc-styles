extends Node
## Port of retro-low-poly/demo.html?frame=key-scene: the diner seen from a counter stool,
## sunny-afternoon palette, every animated value posed at t = 1.3 s.

const P := {
	"ink": "#1C1824", "panel": "#F4ECD8", "key": "#FFF2D8", "ambient": "#8A94A8", "fog": "#DDEEF5",
	"sky": "#7FB8E0", "glow-sign": "#FF5A50", "glow-jukebox": "#FFC850", "glow-tube": "#F0FAFF",
	"accent": "#A23CFF", "material-floor-light": "#E0CCA0", "material-floor-dark": "#2A2A30",
	"material-wall": "#8FCFBF", "material-wood": "#7A4E2E", "material-vinyl": "#B02A34",
	"material-chrome": "#C4CCD6", "material-formica": "#E2CA7A", "material-skin": "#C68462",
	"material-cloth": "#F2F0EA", "material-paint": "#3A86B8", "material-brick": "#9A5A48",
	"material-asphalt": "#4E5058",
}
const LIGHT := {"amb": 0.75, "sun": 0.62, "sun_dir": Vector3(0.4, 0.8, 0.45), "tubes": 0.12,
	"sign": 0.35, "juke": 0.55, "head": 0.1, "kitchen": 0.25, "fog_near": 6.0, "fog_far": 55.0}
const LINES := 240                   # internal render height
const SEG := 0.5                     # faces split every 0.5 m: light lands, the affine warp never folds
const SEAT := Vector3(2.4, 1.5, -0.95)
const T := 1.3                       # the time the key-scene frame is posed at

var retro := preload("res://retro.gdshader")
var sv: SubViewport
var view: TextureRect
var world: Node3D
var camera: Camera3D
var tex := {}
var mats := {}                       # every ShaderMaterial, keyed like the web's material cache
var emit := {}                       # emit kind -> value
var hi := {}                         # highlight kind -> value

func v3(role: String, k := 1.0) -> Vector3:   # palette hex as authored, no sRGB decode
	var c := Color.html(P[role])
	return Vector3(c.r, c.g, c.b) * k

# ------------------------------------------------------------------ materials
func M(t: String, o := {}) -> ShaderMaterial:
	var key: String = t + (":e" + o.emit if o.has("emit") else "") + (":hi" if o.has("hi") else "") + (":u" if o.get("unlit", false) else "")
	if mats.has(key): return mats[key]
	var m := ShaderMaterial.new()
	m.shader = retro
	m.set_shader_parameter("albedo_tex", tex[t])
	m.set_shader_parameter("clamp_uv", t == "cook")
	m.set_meta("emit", o.get("emit", ""))
	m.set_meta("hi", o.get("hi", ""))
	m.set_shader_parameter("unlit", 1.0 if o.get("unlit", false) else 0.0)
	m.set_shader_parameter("fog_on", 0.0 if o.get("unlit", false) else 1.0)
	mats[key] = m
	return m

# ------------------------------------------------------------------ geometry helpers
func box(w: float, h: float, d: float, x: float, y: float, z: float, ry := 0.0) -> Geo:
	var g := Geo.box(w, h, d, ceili(w / SEG), ceili(h / SEG), ceili(d / SEG))
	if ry != 0.0: g.rotate_y(ry)
	return g.translate(x, y, z)

func cyl(r: float, h: float, n: int, x: float, y: float, z: float, r2 := -1.0) -> Geo:
	return Geo.cylinder(r if r2 < 0.0 else r2, r, h, n).translate(x, y, z)

func add(parent: Node3D, g: Geo, mat: ShaderMaterial, tile := 1.0, inside := false) -> MeshInstance3D:
	if tile != 0.0: g.box_uv(tile)
	var mi := MeshInstance3D.new()
	mi.mesh = g.to_mesh(inside)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## A quad that keeps 0..1 UVs (signs, machine fronts), split every 0.25 m or the affine warp folds it.
func decal(parent: Node3D, w: float, h: float, mat: ShaderMaterial, x: float, y: float, z: float, ry := 0.0) -> void:
	var g := Geo.plane(w, h, ceili(w / 0.25), ceili(h / 0.25))
	if ry != 0.0: g.rotate_y(ry)
	add(parent, g.translate(x, y, z), mat, 0.0)

# ------------------------------------------------------------------ scene
func _ready() -> void:
	var win := get_viewport().get_visible_rect().size
	sv = SubViewport.new()
	sv.size = Vector2i(roundi(LINES * win.x / win.y), LINES)        # 427 x 240 at 16:9
	sv.msaa_3d = Viewport.MSAA_DISABLED
	sv.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	sv.use_taa = false
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)

	view = TextureRect.new()
	view.texture = sv.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	var post := ShaderMaterial.new()
	post.shader = preload("res://dither.gdshader")
	post.set_shader_parameter("low_res", Vector2(sv.size))
	view.material = post
	add_child(view)
	# The interface goes in a CanvasLayer above `view`, at window resolution (none in this frame).

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html(P.fog)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	camera = Camera3D.new()
	camera.environment = env
	camera.fov = 55.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.05
	camera.far = 300.0
	camera.position = SEAT
	camera.rotation = Vector3(deg_to_rad(-7.0), deg_to_rad(84.0), 0.0)   # Godot's Euler order is YXZ
	sv.add_child(camera)
	world = Node3D.new()
	sv.add_child(world)

	make_textures()
	build_diner()
	apply_light(Vector2(sv.size), win)

func make_textures() -> void:
	var tx := RetroTextures.new(P)
	for n in ["floor", "formica", "brick"]:
		var src: Image = (load("res://assets/%s.png" % n) as Texture2D).get_image()
		src.convert(Image.FORMAT_RGBA8)
		tex[n] = tx.make(n, src)
	for n in ["wall", "tile", "ceiling", "wood", "vinyl", "chrome", "asphalt", "road", "paint", "glass",
			"dark", "cloth", "jukefront", "jukearch", "neon", "tube", "sign", "open", "menu", "hill", "sky"]:
		tex[n] = tx.make(n)

func build_diner() -> void:
	var w := world
	# shell: x -7..7, z -4..4, 3.2 m high
	add(w, box(14, 0.1, 8, 0, -0.05, 0), M("floor"), 1)
	add(w, box(14, 0.1, 8, 0, 3.25, 0), M("ceiling"), 1.2)
	# back wall with the pass window (x -1.6..1.6, y 1.2..2.2)
	add(w, box(14, 1.2, 0.2, 0, 0.6, -4.1), M("wall"), 1)
	add(w, box(14, 1.0, 0.2, 0, 2.7, -4.1), M("wall"), 1)
	add(w, box(5.4, 1.0, 0.2, -4.3, 1.7, -4.1), M("wall"), 1)
	add(w, box(5.4, 1.0, 0.2, 4.3, 1.7, -4.1), M("wall"), 1)
	add(w, box(3.4, 0.06, 0.5, 0, 1.2, -4.1), M("chrome"), 0.5)
	decal(w, 2.2, 1.0, M("menu"), -3.6, 2.55, -3.95)
	decal(w, 2.2, 1.0, M("menu"), 3.6, 2.55, -3.95)
	# front wall with three window bays (y 1.0..2.5)
	add(w, box(14, 1.0, 0.2, 0, 0.5, 4.1), M("wall"), 1)
	add(w, box(14, 0.7, 0.2, 0, 2.85, 4.1), M("wall"), 1)
	for x in [-7.0, -3.5, 0.0, 3.5, 7.0]: add(w, box(0.5, 1.5, 0.24, x, 1.75, 4.1), M("chrome"), 0.5)
	# left end wall: a window (z -3..0) and a door opening (z 1..2.2)
	add(w, box(0.2, 1.0, 3, -7.1, 0.5, -1.5), M("wall"), 1)
	add(w, box(0.2, 0.7, 3, -7.1, 2.85, -1.5), M("wall"), 1)
	add(w, box(0.2, 3.2, 1, -7.1, 1.6, -3.5), M("wall"), 1)
	add(w, box(0.2, 3.2, 1, -7.1, 1.6, 0.5), M("wall"), 1)
	add(w, box(0.2, 0.9, 1.2, -7.1, 2.75, 1.6), M("wall"), 1)
	add(w, box(0.2, 3.2, 1.8, -7.1, 1.6, 3.1), M("wall"), 1)
	add(w, box(0.2, 3.2, 8, 7.1, 1.6, 0), M("wall"), 1)
	decal(w, 2.6, 0.65, M("open", {"emit": "sign"}), -6.95, 2.85, -1.5, PI / 2)
	# chrome trim at sill height
	add(w, box(14, 0.06, 0.3, 0, 1.0, 3.95), M("chrome"), 0.5)
	add(w, box(0.3, 0.06, 3, -6.95, 1.0, -1.5), M("chrome"), 0.5)
	add(w, box(0.04, 0.08, 8, 6.98, 1.0, 0), M("chrome"), 0.5)
	# exterior brick skin around the shell
	for s in [-1, 1]: add(w, box(4.6, 3.6, 0.1, s * 5.0, 1.8, -4.26), M("brick"), 0.6)
	add(w, box(5.4, 3.6, 0.1, 0, 1.8, -6.46), M("brick"), 0.6)
	# ceiling fixtures
	for x in [-4.5, 0.0, 4.5]:
		add(w, box(1.9, 0.05, 0.42, x, 3.2, 0), M("chrome"), 0.5)
		add(w, box(1.8, 0.07, 0.32, x, 3.15, 0), M("tube", {"emit": "tube"}), 1)

	# kitchen behind the pass
	add(w, box(5, 3.2, 0.2, 0, 1.6, -6.3), M("brick"), 0.6)
	add(w, box(0.2, 3.2, 2.2, -2.6, 1.6, -5.2), M("tile"), 1)
	add(w, box(0.2, 3.2, 2.2, 2.6, 1.6, -5.2), M("tile"), 1)
	add(w, box(5, 0.1, 2.2, 0, -0.05, -5.2), M("tile"), 1)
	add(w, box(5, 0.1, 2.2, 0, 3.25, -5.2), M("ceiling"), 1.2)
	add(w, box(3, 0.9, 0.7, 0, 0.45, -5.8), M("chrome"), 0.6)
	add(w, box(3, 0.6, 0.8, 0, 2.6, -5.75), M("chrome"), 0.6)
	add(w, box(3, 0.05, 0.05, 0, 2.1, -4.0), M("chrome"), 0.5)
	for i in 5: add(w, box(0.13, 0.17, 0.01, -1.1 + i * 0.5, 1.98, -3.98), M("cloth"), 0.3)

	# counter, x -5..4
	add(w, box(9, 1.0, 0.7, -0.5, 0.5, -1.8), M("wall"), 1)
	add(w, box(9.2, 0.06, 0.9, -0.5, 1.03, -1.8), M("formica"), 0.8)
	add(w, box(9.2, 0.05, 0.05, -0.5, 1.0, -1.35), M("chrome"), 0.5)
	add(w, box(9, 0.14, 0.74, -0.5, 0.07, -1.8), M("dark"), 1)
	for x in [-4.2, -3.1, -2.0, -0.9, 0.2, 1.3, 3.5]:   # stools (2.4 is where the player sits)
		add(w, cyl(0.24, 0.04, 8, x, 0.02, -0.95), M("chrome"), 0.5)
		add(w, cyl(0.05, 0.7, 6, x, 0.38, -0.95), M("chrome"), 0.5)
		add(w, cyl(0.23, 0.1, 8, x, 0.76, -0.95), M("vinyl"), 0.5)
		add(w, cyl(0.235, 0.03, 8, x, 0.7, -0.95), M("chrome"), 0.5)
	# on the counter: cup and saucer, pie and slice, napkin box, bottles, cake stand
	add(w, cyl(0.075, 0.012, 8, 0.9, 1.066, -1.55), M("cloth"), 0.3)
	add(w, cyl(0.04, 0.08, 6, 0.9, 1.11, -1.55), M("cloth"), 0.3)
	add(w, cyl(0.12, 0.014, 8, 0.15, 1.067, -1.65), M("cloth"), 0.3)
	add(w, Geo.cylinder(0.09, 0.09, 0.05, 1, 1, false, 0, 0.8).translate(0.15, 1.1, -1.65), M("formica"), 0.2)
	add(w, box(0.1, 0.12, 0.06, -0.5, 1.12, -1.9), M("chrome"), 0.2)
	add(w, cyl(0.03, 0.16, 6, -0.62, 1.14, -1.9), M("vinyl"), 0.2)
	add(w, cyl(0.03, 0.16, 6, -0.7, 1.14, -1.9), M("formica"), 0.2)
	add(w, cyl(0.19, 0.02, 8, -2.6, 1.07, -1.9), M("chrome"), 0.3)
	add(w, cyl(0.13, 0.05, 8, -2.6, 1.1, -1.9), M("formica"), 0.3)
	add(w, Geo.sphere(0.18, 6, 3, 0, TAU, 0, PI / 2).translate(-2.6, 1.08, -1.9), M("chrome"), 0.3)

	# booths along the front windows
	for x in [-5.25, -1.75, 1.75, 5.25]:
		add(w, box(0.9, 0.05, 0.8, x, 0.76, 3.4), M("formica"), 0.8)
		add(w, box(0.92, 0.04, 0.82, x, 0.73, 3.4), M("chrome"), 0.5)
		add(w, cyl(0.05, 0.72, 6, x, 0.36, 3.4), M("chrome"), 0.5)
		for s in [-1, 1]:
			add(w, box(0.5, 0.45, 0.9, x + s * 0.75, 0.225, 3.45), M("vinyl"), 0.5)
			add(w, box(0.16, 0.8, 0.9, x + s * 1.05, 0.85, 3.45), M("vinyl"), 0.5)
		add(w, cyl(0.03, 0.15, 6, x + 0.2, 0.86, 3.6), M("vinyl"), 0.2)
		add(w, box(0.1, 0.12, 0.06, x - 0.1, 0.84, 3.65), M("chrome"), 0.2)

	var cook := build_cook()
	cook.position = Vector3(-0.6, 0, -3.0); cook.rotation.y = 0.35
	var juke := build_jukebox()
	juke.position = Vector3(-6.35, 0, -3.35); juke.rotation.y = PI / 4

	# outside: the lot in four pieces around the floor slab, never under it (a ground plane under
	# the floor pokes up through it once vertices snap)
	for q in [[-80, 80, -80, -6.4], [-80, 80, 4, 80], [-80, -7, -6.4, 4], [7, 80, -6.4, 4]]:
		var gw: float = q[1] - q[0]; var gd: float = q[3] - q[2]
		var g := Geo.plane(gw, gd, ceili(gw / 2), ceili(gd / 2)).rotate_x(-PI / 2)
		add(w, g.translate((q[0] + q[1]) / 2.0, -0.02, (q[2] + q[3]) / 2.0), M("asphalt"), 2)
	for x in [-9.2, -12.0]: add(w, box(0.08, 0.012, 4.8, x, 0, -1.6), M("cloth"), 0.5)
	for along_z in [false, true]:   # the road in front, and one along z beside the diner
		var g := Geo.plane(200, 7, 50, 2).rotate_x(-PI / 2)
		if along_z: g.rotate_y(PI / 2).translate(-24, -0.01, 0)
		else: g.translate(0, -0.01, 17)
		for i in g.count(): g.uv[i * 2] *= 50
		add(w, g, M("road"), 0)
	# a two-tone sedan, parked side-on to the end window
	var cx := -10.6; var cz := -1.6
	add(w, box(1.8, 0.55, 4.4, cx, 0.6, cz), M("paint"), 1.1)
	add(w, box(1.62, 0.34, 2.2, cx, 1.05, cz + 0.2), M("glass"), 1.2)
	add(w, box(1.66, 0.1, 2.0, cx, 1.26, cz + 0.2), M("cloth"), 1)
	for s in [-1, 1]: add(w, box(0.12, 0.26, 0.9, cx + s * 0.84, 0.98, cz - 1.75), M("paint"), 1)
	for s in [-1, 1]: add(w, box(1.92, 0.14, 0.16, cx, 0.42, cz + s * 2.25), M("chrome"), 0.4)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			add(w, Geo.cylinder(0.34, 0.34, 0.26, 8).rotate_z(PI / 2).translate(cx + sx * 0.84, 0.34, cz + sz * 1.4), M("dark"), 0.5)
			add(w, Geo.cylinder(0.16, 0.16, 0.28, 6).rotate_z(PI / 2).translate(cx + sx * 0.84, 0.34, cz + sz * 1.4), M("chrome"), 0.3)
	for s in [-1, 1]: add(w, box(0.32, 0.14, 0.04, cx + s * 0.55, 0.66, cz + 2.21), M("tube", {"emit": "head"}), 1)
	# the roadside sign
	var sx0 := -15.0; var sz0 := -2.2
	for s in [-1, 1]: add(w, cyl(0.06, 2.0, 6, sx0, 1.0, sz0 + s * 1.2), M("chrome"), 0.5)
	add(w, box(0.3, 1.3, 3.0, sx0, 2.6, sz0), M("dark"), 1)
	decal(w, 2.9, 1.2, M("sign", {"emit": "sign"}), sx0 + 0.17, 2.6, sz0, PI / 2)
	# poles, hills, the sky dome
	for x in range(-60, 61, 15):
		add(w, cyl(0.1, 7, 6, x, 3.5, 20.5), M("wood"), 1)
		add(w, box(1.6, 0.1, 0.1, x, 6.6, 20.5), M("wood"), 1)
	for hl in [[-60, -20, 14, 7], [-55, 25, 12, 5], [10, 70, 16, 6], [-30, 60, 11, 8], [45, 55, 14, 5], [-75, 2, 12, 6], [-40, -45, 15, 9]]:
		add(w, Geo.cylinder(0, hl[2], hl[3], 5).translate(hl[0], hl[3] / 2.0, hl[1]), M("hill"), 3)
	add(w, box(22, 9, 12, -85, 4.5, -30), M("hill"), 3)
	add(w, Geo.sphere(250, 8, 6), M("sky", {"unlit": true}), 0, true)   # seen from inside

## The cook: a Meshy model (about 2,600 triangles, 256 px texture at 5 bits), drawn by the same
## shader, its texture sampled raw. Facing +z, feet at the origin, 1.95 m to the top of the cap.
func build_cook() -> Node3D:
	var g := Node3D.new(); world.add_child(g)
	var m: Node3D = (load("res://assets/cook.glb") as PackedScene).instantiate()
	var mi: MeshInstance3D = m.find_children("*", "MeshInstance3D")[0]
	if not tex.has("cook"):
		tex["cook"] = (mi.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture
	mi.material_override = M("cook")
	var b := mi.mesh.get_aabb()
	var k := 1.95 / b.size.y
	m.scale = Vector3.ONE * k
	var c := b.get_center()
	m.position = Vector3(-c.x * k, -b.position.y * k, -c.z * k)
	g.add_child(m)
	return g

## The jukebox (facing +z, base at the origin): the one usable thing, so it gets the accent pulse.
func build_jukebox() -> Node3D:
	var g := Node3D.new(); world.add_child(g)
	var o := {"hi": "juke"}
	add(g, box(0.94, 0.08, 0.64, 0, 0.04, 0), M("chrome", o), 0.5)
	add(g, box(0.9, 1.15, 0.6, 0, 0.655, 0), M("wood", o), 0.5)
	decal(g, 0.78, 1.05, M("jukefront", {"emit": "juke", "hi": "juke"}), 0, 0.66, 0.315)
	var a := Geo.cylinder(0.45, 0.45, 0.6, 8, 1, false, PI / 2, PI).rotate_x(PI / 2).translate(0, 1.23, 0)
	add(g, a, M("jukearch", {"emit": "juke", "hi": "juke"}), 0.25)
	for s in [-1, 1]: add(g, box(0.05, 1.05, 0.05, s * 0.43, 0.66, 0.31), M("neon", {"emit": "juke", "hi": "juke"}), 1)
	return g

# ------------------------------------------------------------------ light, fog and animated values
func apply_light(low: Vector2, win: Vector2) -> void:
	var L := LIGHT
	var key := v3("key")
	var pts := [
		[Vector3(-4.5, 3.0, 0), key * L.tubes * 0.9, 0.12], [Vector3(0, 3.0, 0), key * L.tubes * 0.9, 0.12],
		[Vector3(4.5, 3.0, 0), key * L.tubes * 0.9, 0.12], [Vector3(-14.4, 2.6, -2.2), v3("glow-sign", L.sign * 1.6), 0.08],
		[Vector3(-5.9, 1.2, -2.9), v3("glow-jukebox", L.juke * 0.8), 0.9], [Vector3(0, 2.3, -4.8), key * L.kitchen, 0.3]]
	var pp := PackedVector3Array(); var pc := PackedVector3Array(); var pk := PackedFloat32Array()
	for p in pts: pp.append(p[0]); pc.append(p[1]); pk.append(p[2])
	# animated values, posed at T (in a game: update emit.sign and hi.juke every frame)
	emit = {"": 0.0, "tube": L.tubes * 0.9 + 0.1, "juke": L.juke, "head": L.head,
		"sign": L.sign * (0.92 + 0.05 * sin(T * 13) + 0.03 * sin(T * 31))}   # flicker
	hi = {"": 0.0, "juke": 0.25 + 0.2 * sin(T * 6)}                        # the accent's one job
	for m: ShaderMaterial in mats.values():
		m.set_shader_parameter("low_res", low)
		m.set_shader_parameter("aspect_fix", (low.x / low.y) / (win.x / win.y))
		m.set_shader_parameter("ambient", v3("ambient", L.amb))
		m.set_shader_parameter("sun_col", v3("key", L.sun))
		m.set_shader_parameter("sun_dir", (L.sun_dir as Vector3).normalized())
		m.set_shader_parameter("pt_pos", pp)
		m.set_shader_parameter("pt_col", pc)
		m.set_shader_parameter("pt_k", pk)
		m.set_shader_parameter("fog_col", v3("fog"))
		m.set_shader_parameter("fog_range", Vector2(L.fog_near, L.fog_far))
		m.set_shader_parameter("accent", v3("accent"))
		m.set_shader_parameter("emit", emit[m.get_meta("emit")])
		m.set_shader_parameter("hi", hi[m.get_meta("hi")])
