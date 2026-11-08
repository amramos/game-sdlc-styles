extends Node3D
## Paper theatre: printed cut-outs standing in a lit 3D box, matinee lighting, the key scene.
## Every printed piece is its own image; each cut-out is a print plane plus a card-coloured plane
## just behind it, and both cast alpha-tested shadows on the layers behind.

const Slip := preload("res://slip.gd")
const Placard := preload("res://placard.gd")

const C := {   # matinee scheme
	"ink": "#2B2118", "paper": "#F3EAD2", "card": "#5A3E2B", "house": "#241A1E", "boards": "#7A5A40",
	"accent": "#0FA3D6", "light-key": "#FFF1D8", "light-fill": "#DDE9F2", "light-foot": "#FFD9A0",
}
const LIGHT := {"hemi": 1.05, "key": 2.0, "fill": 0.9, "foot": 0.55, "vignette": 0.22}
const T := 0.4                 # the key scene's pose time, seconds
const FLOOR := -1.6
const BORDER := 0.06           # paper border baked into each cut-out, world units
# the stage opening inside proscenium.png, in its pixels
const OPENING := {"w": 1024.0, "h": 585.0, "x0": 217.7, "x1": 815.4, "y0": 158.9, "y1": 472.0}
var OPEN_H := 7.8 * (OPENING.y1 - OPENING.y0) / (OPENING.x1 - OPENING.x0)
var TOP := FLOOR + OPEN_H

const FILES := {
	"backcloth": "backcloth.jpg", "floor": "floor.jpg", "proscenium": "proscenium.png", "valance": "valance.png",
	"drape": "drape.png", "rowFar": "row-far.png", "rowMid": "row-mid.png", "rowNear": "row-near.png",
	"birch": "wing-birch.png", "oak": "wing-oak.png", "girl": "girl.png", "wolf": "wolf.png", "cart": "cart.png",
}
var TEX := {}
var paper_shader := preload("res://paper.gdshader")
var depth_shader := preload("res://depth.gdshader")
var shadow_maps := {}     # light name -> ViewportTexture holding its packed depth
var shadow_matrices := {} # light name -> Projection, world -> shadow-map [0,1] coordinates
var unlit_shader := preload("res://unlit.gdshader")
var mats: Array[ShaderMaterial] = []
var camera: Camera3D

# lights as three.js spots: position, target, cone (rad), penumbra
const SPOTS := {
	"key": [Vector3(-5, 9, 12), Vector3(-0.3, -0.4, -1), 0.5, 0.55],
	"fill": [Vector3(6, 7, 11), Vector3(0.5, 0, -1), 0.6, 0.7],
	"foot": [Vector3(0, FLOOR + 0.15, 4.6), Vector3(0, 1.2, -6), 1.0, 0.8],
}
const SHADOW_SIZE := 2048
const CASTER_LAYER := 2          # render layer only the shadow cameras draw

func col(role: String) -> Color: return Color(C[role])
func lin3(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)
func aspect(t: Texture2D) -> float: return float(t.get_width()) / t.get_height()

# ------------------------------------------------------------------ materials
func paper_mat(tex: Texture2D, opts := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = paper_shader
	if tex: m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("use_tex", tex != null)
	for k in opts: m.set_shader_parameter(k, opts[k])
	var s := LIGHT["hemi"] as float
	m.set_shader_parameter("hemi_sky", lin3(col("light-fill")) * s)
	m.set_shader_parameter("hemi_ground", lin3(col("boards")) * s)
	for name in SPOTS:
		var sp: Array = SPOTS[name]
		var role := "light-key" if name == "key" else ("light-fill" if name == "fill" else "light-foot")
		m.set_shader_parameter(name + "_pos", sp[0])
		m.set_shader_parameter(name + "_axis", (sp[0] - sp[1]).normalized())
		m.set_shader_parameter(name + "_cos", Vector2(cos(sp[2]), cos(sp[2] * (1.0 - sp[3]))))
		m.set_shader_parameter(name + "_col", lin3(col(role)) * float(LIGHT[name]))
	for name in shadow_maps:
		m.set_shader_parameter(name + "_shadow_map", shadow_maps[name])
		m.set_shader_parameter(name + "_shadow_matrix", shadow_matrices[name])
	m.set_shader_parameter("shadow_map_size", float(SHADOW_SIZE))
	mats.append(m)
	return m

func unlit(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = unlit_shader
	m.set_shader_parameter("color", c)
	return m

func mesh_node(parent: Node, mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # the stage renders its own shadow maps
	parent.add_child(mi)
	return mi

## A plane w x h whose bottom edge sits BORDER below the origin (three: PlaneGeometry translated).
func card_quad(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	q.center_offset = Vector3(0, h / 2 - BORDER, 0)
	return q

## A cut-out: the print (alpha-tested) and the card edge, a second plane 0.018 behind, offset
## 0.022 down and away from the key and grown 0.015 a side, that keeps only the print's alpha.
func stand(key: String, o: Dictionary) -> Node3D:
	var tex: Texture2D = TEX[key]
	var h: float = o.h
	var w: float = o.get("w", h * aspect(tex))
	var flip: bool = o.get("flip", false)
	var casts: bool = o.get("shadow", true)
	var rep: float = o.get("repeat", 1.0)
	var g := Node3D.new()
	g.basis = Basis(Vector3.UP, o.get("yaw", 0.0)) * Basis(Vector3.BACK, o.get("roll", 0.0))
	g.position = Vector3(o.x, o.get("y", FLOOR), o.z)
	add_child(g)
	var uv := {"uv_repeat": Vector2(rep, 1), "wrap": Vector2i(1 if rep != 1.0 else 0, 0), "flip_u": flip}
	var front := paper_mat(tex, uv.merged({"roughness": 0.92}))
	mesh_node(g, card_quad(w, h), front)
	if casts: caster(g, card_quad(w, h), tex, uv, Vector3.ZERO, Vector3.ONE)
	if o.get("edge", true):
		var back := paper_mat(tex, uv.merged({"card_back": true, "base_linear": lin3(col("card")), "roughness": 0.95}))
		var bpos := Vector3(-0.022 if flip else 0.022, -0.022, -0.018)
		var bscale := Vector3(1 + 0.03 / w, 1 + 0.03 / h, 1)
		var b := mesh_node(g, card_quad(w, h), back, bpos)
		b.scale = bscale
		if casts: caster(g, card_quad(w, h), tex, uv, bpos, bscale)
	return g

## The same plane on the casters' layer, drawn by the shadow cameras with the depth shader.
func caster(parent: Node3D, mesh: Mesh, tex: Texture2D, uv: Dictionary, pos: Vector3, scl: Vector3) -> void:
	var m := ShaderMaterial.new()
	m.shader = depth_shader
	m.set_shader_parameter("tex", tex)
	for k in uv: m.set_shader_parameter(k, uv[k])
	var mi := mesh_node(parent, mesh, m, pos)
	mi.scale = scl
	mi.layers = 1 << (CASTER_LAYER - 1)

## A shadow map like three's SpotLightShadow: a square perspective camera at the light, fov twice
## the cone, near 3, far 45, drawing only the casters, into a 2048 texture.
func shadow_rig(name: String) -> void:
	var sp: Array = SPOTS[name]
	var sv := SubViewport.new()
	sv.size = Vector2i(SHADOW_SIZE, SHADOW_SIZE)
	sv.msaa_3d = Viewport.MSAA_DISABLED
	sv.positional_shadow_atlas_size = 0
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var cam := Camera3D.new()
	cam.fov = rad_to_deg(sp[2]) * 2.0
	cam.near = 3.0; cam.far = 45.0
	cam.cull_mask = 1 << (CASTER_LAYER - 1)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.WHITE            # cleared to "far"
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = e
	var xf := Transform3D(Basis.looking_at(sp[1] - sp[0], Vector3.UP), sp[0])
	cam.transform = xf
	sv.add_child(cam)
	cam.current = true
	shadow_maps[name] = sv.get_texture()
	var f := 1.0 / tan(sp[2])
	var n := 3.0; var fa := 45.0
	var proj := Projection(Vector4(f, 0, 0, 0), Vector4(0, f, 0, 0), Vector4(0, 0, (fa + n) / (n - fa), -1), Vector4(0, 0, 2 * fa * n / (n - fa), 0))
	var bias := Projection(Vector4(0.5, 0, 0, 0), Vector4(0, 0.5, 0, 0), Vector4(0, 0, 0.5, 0), Vector4(0.5, 0.5, 0.5, 1))
	shadow_matrices[name] = bias * proj * Projection(xf.affine_inverse())

func wire_mat() -> ShaderMaterial:
	return paper_mat(null, {"base_linear": lin3(Color("#222222")), "roughness": 0.5, "metalness": 0.4, "alpha_test": false, "receive_shadow": false})

func rod(radius: float, length: float, seg: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius; m.bottom_radius = radius; m.height = length
	m.radial_segments = seg; m.rings = 0
	return m

func wire(x: float, y0: float, y1: float, z: float) -> MeshInstance3D:
	return mesh_node(self, rod(0.008, y1 - y0, 5), wire_mat(), Vector3(x, (y0 + y1) / 2, z))

func slide(x0: float, x1: float, z: float) -> void:
	var m := mesh_node(self, rod(0.012, absf(x1 - x0), 6), wire_mat(), Vector3((x0 + x1) / 2, FLOOR + 0.03, z))
	m.rotation.z = PI / 2

func flat_quad(x0: float, y0: float, x1: float, y1: float, z: float, mat: Material) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(x1 - x0, y1 - y0)
	mesh_node(self, q, mat, Vector3((x0 + x1) / 2, (y0 + y1) / 2, z))

func diamond(s: float) -> ArrayMesh:
	var v := PackedVector3Array([Vector3(0, 0.14, 0), Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0),
		Vector3(0.1, 0, 0), Vector3(-0.1, 0, 0), Vector3(0, -0.14, 0)])
	for i in v.size(): v[i] *= s
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## Accent marker: an unlit diamond with an ink rim, bobbing on a wire from the fly.
func marker(x: float, y: float, z: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, y + sin(T * PI) * 0.04, z)
	add_child(g)
	mesh_node(g, diamond(1.35), unlit(col("ink")), Vector3(0, 0, -0.005))
	mesh_node(g, diamond(1.0), unlit(col("accent")))
	wire(x, y + 0.19, 4.5, z)

# ------------------------------------------------------------------ build
func _ready() -> void:
	var src := {}
	for k in FILES: src[k] = load("res://img/" + FILES[k])
	TEX = await linearize(src)
	shadow_rig("key")
	shadow_rig("foot")
	var house := col("house")

	# house wall around the arch (unlit), with the opening cut
	var hm := unlit(house)
	flat_quad(-30, -20, -3.95, 20, 4.9, hm)
	flat_quad(3.95, -20, 30, 20, 4.9, hm)
	flat_quad(-3.95, TOP + 0.05, 3.95, 20, 4.9, hm)
	flat_quad(-3.95, -20, 3.95, -1.65, 4.9, hm)

	# stage floor: the plank print, mirrored so it tiles without a seam (top face of a 20 x 0.3 x 15 box)
	var fl := PlaneMesh.new(); fl.size = Vector2(20, 15)
	var fmat := paper_mat(TEX.floor, {"uv_repeat": Vector2(20 / 2.6, 15 / 2.6), "wrap": Vector2i(2, 2),
		"alpha_test": false, "roughness": 0.9})
	mesh_node(self, fl, fmat, Vector3(0, FLOOR, -2.6))
	var ff := QuadMesh.new(); ff.size = Vector2(20, 0.3)   # its front face shows as a sliver at the lip
	mesh_node(self, ff, fmat, Vector3(0, FLOOR - 0.15, 4.9 - 0.001))

	# back cloth: 26 wide, the print at its own scale in the middle, mirrored out at the sides
	var ba := aspect(TEX.backcloth)
	var bq := QuadMesh.new(); bq.size = Vector2(26, 20 / ba)
	mesh_node(self, bq, paper_mat(TEX.backcloth, {"uv_repeat": Vector2(1.3, 1), "uv_offset": Vector2(-0.15, 0),
		"wrap": Vector2i(2, 0), "alpha_test": false, "roughness": 1.0}), Vector3(0, FLOOR - 0.2 + 10 / ba, -9.5))

	# ground rows, each repeated along the width so it keeps the height the recipe gives it
	for r in [["rowFar", 2.6, -8.0], ["rowMid", 1.9, -6.0], ["rowNear", 1.1, -4.0]]:
		var a := aspect(TEX[r[0]])
		var n := maxi(1, roundi(20.0 / (r[1] * a)))
		stand(r[0], {"w": 20.0, "h": 20.0 / n / a, "x": 0.0, "z": r[2], "repeat": float(n)})

	# wings: two pairs of tree flats, turned toward the centre
	stand("birch", {"h": 5.6, "x": -4.5, "z": 2.5, "yaw": 0.22})
	stand("oak", {"h": 5.6, "x": 4.6, "z": 2.5, "yaw": -0.22, "flip": true})
	stand("oak", {"h": 5.0, "x": -5.0, "z": -1.5, "yaw": 0.2})
	stand("birch", {"h": 5.2, "x": 5.0, "z": -1.5, "yaw": -0.2, "flip": true})

	# the cast, posed at t = 0.4 s
	stand("girl", {"h": 2.05, "x": -1.2, "z": 0.5, "yaw": 0.12, "y": FLOOR + absf(sin(T * 1.3)) * 0.015})
	stand("wolf", {"h": 1.55, "x": 1.9, "z": 0.2, "yaw": -0.15, "roll": sin(T * 0.9) * 0.008})
	stand("cart", {"h": 1.75, "x": -3.0, "z": -1.3, "yaw": 0.2})
	slide(-8, -1.2, 0.48)
	slide(1.9, 8, 0.18)

	# proscenium: the generated frame, scaled so its keyed opening matches the 7.8-wide stage opening
	var sx := 7.8 / (OPENING.x1 - OPENING.x0)
	var PW: float = OPENING.w * sx
	var PH: float = OPENING.h * sx
	var cx: float = (OPENING.x0 + OPENING.x1) / 2 * sx
	var cy: float = (OPENING.y0 + OPENING.y1) / 2 * sx
	var pq := QuadMesh.new(); pq.size = Vector2(PW, PH)
	mesh_node(self, pq, paper_mat(TEX.proscenium, {"roughness": 0.85}), Vector3(PW / 2 - cx, FLOOR + OPEN_H / 2 - (PH / 2 - cy), 5))

	# side drapes and the scalloped border, hung just inside the frame (they cast no shadow)
	var dh := OPEN_H + 0.35
	var dx := 4.6 - dh * aspect(TEX.drape) / 2
	stand("drape", {"h": dh, "x": -dx, "y": FLOOR + 0.02, "z": 4.3, "shadow": false})
	stand("drape", {"h": dh, "x": dx, "y": FLOOR + 0.02, "z": 4.3, "shadow": false, "flip": true})
	var vh := 8.4 / aspect(TEX.valance)
	stand("valance", {"w": 8.4, "h": vh, "x": 0.0, "y": TOP + 0.6 - vh + BORDER, "z": 4.4, "shadow": false})

	# footlight hoods along the stage lip
	var hood := paper_mat(null, {"base_linear": lin3(Color("#2a2420")), "roughness": 0.6, "metalness": 0.5, "alpha_test": false, "receive_shadow": false})
	for i in 9:
		var b := BoxMesh.new(); b.size = Vector3(0.42, 0.1, 0.16)
		mesh_node(self, b, hood, Vector3(-3.4 + i * 0.85, FLOOR + 0.05, 4.65))

	# the title placard, flown on two wires: live text painted into a texture
	var placard_mat := paper_mat(null, {"alpha_test": false, "roughness": 0.9, "emissive": 0.35, "receive_shadow": false})
	var plq := QuadMesh.new(); plq.size = Vector2(2.56, 0.72)
	mesh_node(self, plq, placard_mat, Vector3(0, TOP - 1.25, 3.6))
	wire(-1.0, TOP - 0.89, TOP + 1, 3.6)
	wire(1.0, TOP - 0.89, TOP + 1, 3.6)
	paint_placard(placard_mat)

	# accent markers over what the player can act on
	marker(1.9, 0.3, 0.2)
	marker(-3.0, 0.45, -1.3)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = house
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)

	camera = Camera3D.new()
	camera.fov = 38; camera.near = 0.1; camera.far = 100
	camera.cull_mask = 1
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 2.0, 16.5), Vector3(0, 0.15, 0))
	camera.current = true

	# post: vignette toward the house colour
	var vl := CanvasLayer.new(); vl.layer = 1; add_child(vl)
	var vr := ColorRect.new(); vr.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vm := ShaderMaterial.new(); vm.shader = preload("res://vignette.gdshader")
	vm.set_shader_parameter("house_linear", lin3(house)); vm.set_shader_parameter("amount", LIGHT.vignette)
	vr.material = vm; vl.add_child(vr)

	# interface: the basket slip pinned over the left pillar
	var hud := CanvasLayer.new(); hud.layer = 2; add_child(hud)
	var slip := Slip.new()
	slip.regular = garamond(400, false)
	slip.bold_onum = garamond(700, false, {"onum": 1})
	slip.bold_smcp = garamond(700, false, {"smcp": 1})
	var lx := camera.unproject_position(Vector3(-3.9 - 0.95, 0, 5)).x
	slip.position = Vector2(roundf(lx - Slip.W * 0.5), 150)
	hud.add_child(slip)

## The demo's own font files (assets/fonts/ on the web): EB Garamond in the weights the page uses.
func garamond(weight: int, italic: bool, features := {}) -> Font:
	var style := ("Bold" if weight >= 700 else "") + ("Italic" if italic else "")
	var f: FontFile = load("res://fonts/EBGaramond-%s.woff" % (style if style else "Regular"))
	if features.is_empty(): return f
	var v := FontVariation.new()
	v.base_font = f
	var ts := TextServerManager.get_primary_interface()
	var feats := {}
	for k in features: feats[ts.name_to_tag(k)] = features[k]
	v.opentype_features = feats
	return v

## Paints the placard once in a SubViewport and keeps the result as an ordinary mipmapped texture.
func paint_placard(mat: ShaderMaterial) -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(640, 180)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	var p := Placard.new()
	p.font = garamond(700, true)
	sv.add_child(p)
	add_child(sv)
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	var lin := await linearize({"placard": ImageTexture.create_from_image(img)})
	mat.set_shader_parameter("tex", lin.placard)
	mat.set_shader_parameter("use_tex", true)
	sv.queue_free()


## The prints as linear half-float textures with mipmaps averaged in linear light. WebGL filters
## sRGB textures after decoding them; Godot's importer averages the mips in sRGB, which darkens
## every finely hatched print as it shrinks. One frame: each print is drawn through a decoding
## shader into an HDR 2D SubViewport, read back, and mipmapped on the CPU.
func linearize(src: Dictionary) -> Dictionary:
	var views := {}
	var sh := preload("res://linearize.gdshader")
	for k in src:
		var t: Texture2D = src[k]
		var sv := SubViewport.new()
		sv.size = Vector2i(t.get_width(), t.get_height())
		sv.use_hdr_2d = true
		sv.transparent_bg = true
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE
		var r := TextureRect.new()
		r.texture = t
		r.size = Vector2(sv.size)
		var m := ShaderMaterial.new(); m.shader = sh
		r.material = m
		sv.add_child(r)
		add_child(sv)
		views[k] = sv
	await RenderingServer.frame_post_draw
	var out := {}
	for k in views:
		var img: Image = views[k].get_texture().get_image()
		img.generate_mipmaps()
		out[k] = ImageTexture.create_from_image(img)
		views[k].queue_free()
	return out
