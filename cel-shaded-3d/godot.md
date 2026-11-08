# Godot 4 snippets

<!-- matched-web-frame: 4bc202de41fd -->

> **The `assets/` paths below load this entry's example art**, which is how the port was tested against the web demo. A game never ships it: load the game's own models, sprites and textures, made the same way, in their place.

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.jpg` rebuilds
`demo.html?frame=key-scene`: mean difference 2.1 / 1.6 / 2.4 per 255 (R/G/B) between the Godot
render and the web frame; 10% of pixels differ by more than 8 and 2.2% by more than 24. **Forward+**
gives the same frame (0.8 / 0.6 / 0.4 per 255 from the Compatibility render, 1.9% of pixels over 8,
mostly on antialiased edges) with the same code. The whole project that rendered the frame,
including the code that rebuilds the web demo exactly, is in this entry's `godot-port/` on the
catalog site.

What still differs is edges: Godot's 4× MSAA against the browser's antialiasing on the ink outlines
(a few pixels along every silhouette), JPEG ringing in the web frame, and one-pixel shifts where a
band edge meets a texel edge on the generated models.

The look: one directional key light with hard shadows, the toon shader on every surface (flat colour
per palette role on primitives, a palette-slot texture on generated models), an inverted-hull
outline child on each outlined mesh, a banded sky shader, fog mixed inside the toon shader. No
post-processing.

## What Compatibility needs

Measured against Forward+ in 4.7.1; each changed the frame visibly. The code below handles these
traps from `godot-compatibility.md` (copied beside this file):

- **8, 9:** the flat ambient and the fog live in the toon shader's `light()`; the Environment's
  ambient is black and its fog off.
- **3:** colours used in `light()` are plain `vec3` uniforms of linear values, set with `lin3()`.
  Albedo comes from a `source_color` array of sRGB `Color`s (the slot colours); from a plain
  uniform the shadow-lit model came out about albedo squared (153, 8, 3 instead of 188, 60, 52).
- **6:** the sky shader branches on `CURRENT_RENDERER`.
- **16:** the slot map is data: the GLB's images are *Embed as Uncompressed*, sampled
  `filter_nearest`, no `source_color`.
- **5:** the outline reads its smoothed normal from the vertex colour in `vertex()` only.

## Shaders

`toon_light.gdshaderinc`, included by both surface shaders. Ratios are the recipe's: ambient 0.45 of
`shadow-tint`, key 0.60, highlight +0.15 above N·L 0.75, rim 0.35 of `sky-horizon`. The scene has
exactly one directional light (the key): ambient, rim and fog ride on it. Fog follows three.js's
`Fog` (smoothstep on view depth, mixed into the sRGB-encoded colour); set its range from the game's
view distance (the demo: 30–210 m).

```glsl
// Shared by toon.gdshader (primitives) and toon_slots.gdshader (generated models).
// Colours read in light() are LINEAR vec3s set from a Vector3 (lin3() in GDScript): Compatibility does
// not linearise source_color uniforms read in light(), and Forward+ converts a Color passed to a vec3.
uniform vec3 ambient_linear = vec3(0.275, 0.352, 0.807); // lin3(shadow-tint)
uniform float ambient_ratio = 0.45;
uniform float key_ratio = 0.60;
uniform float lit_threshold = 0.0;        // N·L where shade turns to lit
uniform float highlight_threshold = 0.75; // N·L where the highlight starts
uniform float highlight_amount = 0.25;    // 0.25 x 0.60 = +0.15 key; 0 turns the third band off
uniform float edge = 0.01;                // half-width of the band edge
uniform float rim_amount = 0.0;           // 0.35 on characters
uniform vec3 rim_linear = vec3(0.624, 0.863, 1.0);  // lin3(sky-horizon)
uniform bool receive_shadow = true;
// Fog is mixed here (Environment fog off), in sRGB like three.js: smoothstep on view depth.
uniform vec3 fog_srgb = vec3(0.812, 0.937, 1.0);    // sky-horizon, sRGB values
uniform vec2 fog_range = vec2(30.0, 210.0);
varying float view_depth;
varying float face_shift;                 // + to N·L: 0.5 on face texels, which stay lit unless lit from behind

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void vertex() {
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;   // light() cannot read VERTEX
}

void light() {
	float ndl = dot(NORMAL, LIGHT) + face_shift;
	float band = smoothstep(lit_threshold - edge, lit_threshold + edge, ndl);
	if (receive_shadow) {
		band = min(band, step(0.5, ATTENUATION));   // the shadow map joins the same step
	}
	float hi = smoothstep(highlight_threshold - edge, highlight_threshold + edge, ndl) * band;
	vec3 key = LIGHT_COLOR / PI * key_ratio * (band + hi * highlight_amount);  // LIGHT_COLOR has x PI
	if (LIGHT_IS_DIRECTIONAL) {
		// The whole colour is written here, in one pass (Environment ambient and fog stay off), so
		// Compatibility and Forward+ agree.
		vec3 lit = ambient_linear * ambient_ratio + key;
		vec3 a = max(ALBEDO, vec3(1e-4));
		// hard rim on the lit side (N·L without the face shift), mixed in linear
		float k = rim_amount * step(0.70, 1.0 - dot(NORMAL, VIEW)) * step(0.0, dot(NORMAL, LIGHT));
		vec3 col = mix(a * lit, rim_linear, k);
		// fog: mixed in sRGB after encoding, as three.js does
		float f = smoothstep(fog_range.x, fog_range.y, view_depth);
		col = to_linear(mix(to_srgb(clamp(col, 0.0, 1.0)), fog_srgb, f));
		DIFFUSE_LIGHT += col / a;
	} else {
		DIFFUSE_LIGHT += key;   // point lights add to the lit band only
	}
}
```

`toon.gdshader`: primitives and hand-built meshes, one `ShaderMaterial` per palette role,
`base_color` = the role's hex.

```glsl
shader_type spatial;
render_mode specular_disabled;

uniform vec4 base_color : source_color = vec4(0.42, 0.80, 0.29, 1.0);
#include "res://toon_light.gdshaderinc"

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	face_shift = 0.0;
}
```

`toon_slots.gdshader`: generated models. Their texture stores a palette slot per texel (`slot × 16`
in the red channel); the shader looks the colour up, so albedo stays flat, follows a palette swap,
and only the light makes bands. Both sides are drawn: thin generated parts are single sheets.

```glsl
shader_type spatial;
// Generated models: thin parts (sails, scarf) need both sides.
render_mode specular_disabled, cull_disabled;

// The model's texture holds a palette slot per texel (R = slot x 16). Nearest, no colour space.
uniform sampler2D slot_map : filter_nearest, repeat_enable;
uniform vec4 slot_col[16] : source_color;   // colour per slot: palette role x multiplier (in linear)
uniform int face_slot = -1;    // texels of this slot use the face ramp
#include "res://toon_light.gdshaderinc"

void fragment() {
	int slot = int(floor(texture(slot_map, UV).r * 15.9375 + 0.5));
	ALBEDO = slot_col[slot].rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	face_shift = slot == face_slot ? 0.5 : 0.0;
}
```

`outline.gdshader`: the inverted hull, a second `MeshInstance3D` child with the same mesh, this
material and shadow casting off. Width in screen pixels at 1080p (3 characters, 2.5 props and
buildings, 2 terrain), fading to 1 px between 12 and 60 m and to the fog colour with the surface's
fog curve.

```glsl
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.14, 0.13, 0.23, 1.0);
uniform vec4 fog_color : source_color = vec4(0.81, 0.94, 1.0, 1.0);
uniform float width_px = 3.0;
uniform vec2 fade = vec2(12.0, 60.0);       // full width until x, 1 px at y (metres)
uniform vec2 fog_range = vec2(30.0, 210.0);
varying float depth;

void vertex() {
	// smoothed normal baked into the vertex colour; use NORMAL on smooth meshes
	vec3 n = COLOR.rgb * 2.0 - 1.0;   // raw in vertex() in both renderers
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n_view = normalize(MODELVIEW_NORMAL_MATRIX * n);
	vec2 n_clip = normalize((PROJECTION_MATRIX * vec4(n_view, 0.0)).xy + 1e-6);
	float px = mix(width_px, 1.0, smoothstep(fade.x, fade.y, clip.w)) * VIEWPORT_SIZE.y / 1080.0;
	clip.xy += n_clip * px * 2.0 / VIEWPORT_SIZE * clip.w;
	depth = clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = mix(ink.rgb, fog_color.rgb, smoothstep(fog_range.x, fog_range.y, depth));
}
```

`sky.gdshader`, on a `Sky`: four flat steps from `sky-horizon` to `sky-top` packed between the
horizon and about 20° up (where a level game camera sees sky), two steps back toward `sky-top` below
the horizon, a 3° sun disc in `key` with one ring.

```glsl
shader_type sky;

uniform vec4 top : source_color;
uniform vec4 horizon : source_color;
uniform vec4 sun : source_color;
uniform vec3 sun_dir = vec3(-0.51, 0.77, 0.38);

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void sky() {
	vec3 t = top.rgb, h = horizon.rgb, s = sun.rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Compatibility runs sky shaders in sRGB: blend in linear by hand, as Forward+ does
	t = to_linear(t); h = to_linear(h); s = to_linear(s);
#endif
	vec3 d = normalize(EYEDIR);
	// four flat steps packed low (horizon to ~20 degrees up), two below the horizon
	float up = floor(clamp(d.y / 0.34, 0.0, 1.0) * 4.0) / 4.0;            // 0, .25, .5, .75, 1
	float down = floor(clamp(-d.y / 0.5, 0.0, 1.0) * 3.0) / 3.0 * 0.35;  // 0, .12, .23, .35
	vec3 c = mix(h, t, max(up, down));
	float a = dot(d, normalize(sun_dir));
	c = mix(c, s, step(cos(radians(1.5)), a));                        // 3 deg hard disc
	c = mix(c, s, 0.3 * step(cos(radians(2.6)), a) * (1.0 - step(cos(radians(2.4)), a)));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c = to_srgb(c);
#endif
	COLOR = c;
}
```

## Script helpers

From `main.gd` on the root `Node3D`. `P` is the example palette; put the game's roles in it.

```gdscript
extends Node3D

const P := {
	"ink": "#24203A", "key": "#FFF3DA", "shadow-tint": "#8FA0E8", "sky-top": "#3A8EE6",
	"sky-horizon": "#CFEFFF", "cloud": "#FFFFFF", "base-grass": "#6CCB4A", "base-rock": "#D09A62",
	"base-wood": "#C27A42", "base-roof": "#D9483B", "base-cloth": "#2F72D6", "base-skin": "#FFCFAA",
	"base-hair": "#9B6BE0", "accent": "#FF3FA0",
}
const FOG := Vector2(30.0, 210.0)
## Slot tables of the generated models: [palette role, multiplier] (see the models' README).
const MODEL_SLOTS := [["base-skin", 1.0], ["base-cloth", 1.0], ["base-cloth", 0.62]]   # one table per model, in slot order
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

func cylinder(rt: float, rb: float, h: float, seg: int) -> ArrayMesh:
	var m := CylinderMesh.new(); m.top_radius = rt; m.bottom_radius = rb; m.height = h
	m.radial_segments = seg; m.rings = 0
	return prim("c%s,%s,%s,%s" % [rt, rb, h, seg], m)

func cone(r: float, h: float, seg: int) -> ArrayMesh:
	return cylinder(0.0, r, h, seg)

func box(x: float, y: float, z: float) -> ArrayMesh:
	var m := BoxMesh.new(); m.size = Vector3(x, y, z)
	return prim("b%s,%s,%s" % [x, y, z], m)

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
```

`mat(role)` is the toon material for a palette role; `part(mesh, role, {pos, rot, scale, line, rim,
cast, receive})` makes a mesh with its outline hull (`line` 0 for none). Primitives go through
`prim()`, which adds the smoothed normal as vertex colour so cubes and cylinder caps don't tear the
hull. Godot's own `SphereMesh`, `TorusMesh` and the rest work the same way through `prim()`.

Left out, and kept in `godot-port/`: clones of three.js's sphere and torus layouts (Godot's
`SphereMesh` has another row count and start meridian, which changed cloud silhouettes, and
`TorusMesh` lies in XZ, not XY), the demo's displaced-hemisphere rock and its JavaScript-style
hash, and the example scene. When copying a three.js scene, use `rotation_order = EULER_ORDER_XYZ`
(as `part()` and `group()` do) and reverse the index order of hand-built triangles (Godot's front
faces wind clockwise).

## Importing the generated models

Import each `.glb` with these options (Import dock, or the `.import` file):

| Option | Value | Why |
|---|---|---|
| `gltf/embedded_image_handling` | Embed as Uncompressed (3) | the slot map is data; VRAM compression would change slot values |
| `meshes/force_disable_compression` | on | keeps UVs exact at slot-chart edges |
| `meshes/generate_lods`, `meshes/create_shadow_meshes` | off | the hull and the shading use the mesh as authored |
| `meshes/ensure_tangents` | off | nothing uses them |

`place_model()` replaces the imported material: it takes its `albedo_texture` as the slot map,
averages the normals of all vertices at the same position and uses that as the shading normal too
(image-to-3D meshes split normals at every UV seam, which would leave band patches along them), adds
the hull, and scales the model to a height with its feet on y = 0, centred. It keeps each node's
transform and name: a part that turns (a wheel, a rotor) is its own node with its origin on the hub
and its axis in the node's `extras.spinAxis`; rotate that node about the axis.

```gdscript
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
```

Settings that worked: a character with outline 3 px, rim on, face slot = the skin slot; a building
or large prop with outline 2.5 px, no rim, no face slot. Both cast shadows; neither receives them.

## Environment, light and project settings

```gdscript
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
```

Project settings: renderer `gl_compatibility`,
`rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality = 0` (Hard),
`directional_shadow/size = 4096`, `anti_aliasing/quality/msaa_3d = 2` (4×; outlines alias without
it). With these values no shadow acne appeared along the band edge. Camera: perspective, 50°
vertical FOV, near 0.1, far 1000.

## Putting it together

```text
Main (Node3D, main.gd)
├── world (Node3D)
│   ├── MeshInstance3D        part(): toon.gdshader per palette role
│   │   └── MeshInstance3D    its hull: outline.gdshader, no shadow
│   └── Node3D                place_model(): one MeshInstance3D per model node,
│       └── …                 toon_slots.gdshader, each with its hull child
├── DirectionalLight3D        the key, the only directional light, hard shadows
├── WorldEnvironment          sky.gdshader, black ambient, fog off, linear tone mapper
└── Camera3D
```

In `_ready()`: build the world from `part()` and `group()` (terrain, props, clouds without
outlines), add generated models with `place_model()` and their slot tables, then `build_env()`.
Ground and props that others shadow receive shadows; convex pieces that would only shadow
themselves (posts, towers, heads) don't.

## Interface

One Theme resource: `StyleBoxFlat` with `panel` fill, 3 px `ink` border, corner radius 10,
`shadow_color` `ink`, `shadow_size` 1 and `shadow_offset` (0, 4) for the hard offset. The key-scene
test doesn't cover the interface (the key scene has none).
