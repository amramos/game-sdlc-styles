# Godot 4 snippets

<!-- matched-web-frame: 4bc202de41fd -->

> **The `assets/` paths below load this entry's example art**, which is how the port was tested against the web demo. A game never ships it: load the game's own models, sprites and textures, made the same way, in their place.

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.jpg` rebuilds
`demo.html?frame=key-scene`: mean difference 2.1 / 1.6 / 2.4 per 255 (R/G/B) between the Godot
render and the web frame; 10% of pixels differ by more than 8 and 2.2% by more than 24. Composition,
camera, cast, props, generated models, sky bands, clouds, fog and palette are the same. What is left
is edges: Godot's 4× MSAA against the browser's antialiasing on the ink outlines (a few pixels along
every silhouette, most visible on the route rings and the character), JPEG ringing in the web frame,
and one-pixel shifts where a band edge meets a texel edge on the generated models. **Forward+**
gives the same frame (0.8 / 0.6 / 0.4 per 255 from the Compatibility render, 1.9% of pixels over 8,
mostly on antialiased edges) with the same code.

The scene: one directional key light with hard shadows, the toon shader on every surface (flat colour
per palette role on primitives, a palette-slot texture on generated models), an inverted-hull
outline child on each outlined mesh, a banded sky shader, fog mixed inside the toon shader. No
post-processing.

## What Compatibility needs

Measured against Forward+ in 4.7.1. Each one changed the frame visibly; the code below avoids them.

1. An **Environment ambient colour plus a shadow-casting directional light** brightens every lit
   face in Compatibility, even with `StandardMaterial3D`. The flat ambient lives in the toon
   shader's `light()`, and the Environment's ambient is black.
2. **`source_color` uniforms read inside `light()` are not linearised** in Compatibility, while
   Forward+ linearises a `Color` passed to a plain `vec3`. Colours used in `light()` are plain
   `vec3` uniforms holding linear values, set from GDScript as a `Vector3` (`lin3()` below).
3. **Environment fog is applied in both of Compatibility's passes**, so distant objects wash out.
   Fog is mixed in `light()`, and the Environment's fog stays off.
4. **Sky shaders run in sRGB in Compatibility**, so colours blend in sRGB there and in linear in
   Forward+. The sky shader branches on `CURRENT_RENDERER`.
5. **Albedo must come from a `source_color` uniform.** With `ALBEDO` set from a plain `vec3`/`vec4`
   uniform (or a literal), the shadow-lit model came out about albedo squared in Compatibility (a
   red roof at 153, 8, 3 instead of 188, 60, 52) while Forward+ was right. The slot colours are
   therefore a `source_color` array, filled with sRGB `Color`s.
6. **Imported textures that hold data** (the slot map) must not be VRAM-compressed: set the GLB's
   embedded image handling to *Embed as Uncompressed* and sample with `filter_nearest`, no
   `source_color`.

```gdscript
## A linear colour as a Vector3: a Color would be converted again by Forward+ but not by Compatibility.
static func lin3(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)
```

## Toon light (shared include)

`toon_light.gdshaderinc`, included by both surface shaders below. Ratios are the recipe's: ambient
0.45 of `shadow-tint`, key 0.60, highlight +0.15 above N·L 0.75, rim 0.35 of `sky-horizon`.

```glsl
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
		// The whole colour is written here, in one pass, so Compatibility and Forward+ agree.
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

- The scene has exactly one directional light (the key): ambient, rim and fog ride on it.
- Fog: three.js `Fog` takes `smoothstep(near, far, view depth)` and mixes it into the
  sRGB-encoded colour, so the include does the same and the haze matches with no fudge factor.
  Set the range from the game's view distance (the demo: 30–210 m).

## Surface shaders

**Primitives and hand-built meshes** (`toon.gdshader`, one `ShaderMaterial` per palette role,
`base_color` = the role's hex):

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

**Generated models** (`toon_slots.gdshader`). Their texture stores a palette slot per texel
(`slot × 16` in the red channel); the shader looks the colour up, so albedo stays flat, follows a
palette swap, and only the light makes bands. Both sides are drawn: thin generated parts (cloth,
sails, a scarf) are single sheets.

```glsl
shader_type spatial;
render_mode specular_disabled, cull_disabled;

uniform sampler2D slot_map : filter_nearest, repeat_enable;   // data: no source_color
uniform vec4 slot_col[16] : source_color;   // colour per slot: palette role x multiplier (in linear)
uniform int face_slot = -1;                 // texels of this slot use the face ramp
#include "res://toon_light.gdshaderinc"

void fragment() {
	int slot = int(floor(texture(slot_map, UV).r * 15.9375 + 0.5));
	ALBEDO = slot_col[slot].rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	face_shift = slot == face_slot ? 0.5 : 0.0;
}
```

```gdscript
## slots: [[palette role, multiplier], ...]; a multiplier below 1 is the material's one darker tone.
func slot_material(tex: Texture2D, slots: Array, rim: bool, face_slot: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://toon_slots.gdshader")
	m.set_shader_parameter("slot_map", tex)
	var cols := PackedColorArray(); cols.resize(16)
	for i in slots.size():   # the multiplier scales the linear colour
		var l := Color(palette[slots[i][0]]).srgb_to_linear() * float(slots[i][1])
		cols[i] = Color(l.r, l.g, l.b).linear_to_srgb()
	m.set_shader_parameter("slot_col", cols)
	m.set_shader_parameter("face_slot", face_slot)
	set_light_params(m, rim, false)   # generated models don't receive shadows
	return m

func set_light_params(m: ShaderMaterial, rim: bool, receive: bool) -> void:
	m.set_shader_parameter("rim_amount", 0.35 if rim else 0.0)
	m.set_shader_parameter("rim_linear", lin3(Color(palette["sky-horizon"])))
	m.set_shader_parameter("ambient_linear", lin3(Color(palette["shadow-tint"])))
	var h := Color(palette["sky-horizon"])
	m.set_shader_parameter("fog_srgb", Vector3(h.r, h.g, h.b))
	m.set_shader_parameter("fog_range", Vector2(30.0, 210.0))
	m.set_shader_parameter("receive_shadow", receive)
```

## Importing the generated models

Decode each `assets/<name>.glb.js` (base64 after `MODELS['<name>'] =`) to a `.glb` and import it
with these options (Import dock, or the `.import` file):

| Option | Value | Why |
|---|---|---|
| `gltf/embedded_image_handling` | Embed as Uncompressed (3) | the slot map is data; VRAM compression would change slot values |
| `meshes/force_disable_compression` | on | keeps UVs exact at slot-chart edges |
| `meshes/generate_lods`, `meshes/create_shadow_meshes` | off | the hull and the shading use the mesh as authored |
| `meshes/ensure_tangents` | off | nothing uses them |

The imported material is replaced: take its `albedo_texture` as the slot map. Then, per mesh,
average the normals of all vertices at the same position and use that as the shading normal too
(as the web demo does): image-to-3D meshes split normals at every UV seam, which would leave band
patches along them. Keep each node's transform; a part that turns (the demo's sails) is its own node
with its origin on the hub, and the GLB stores its axis in the node's `extras.spinAxis`; rotate
that node about the axis (0.2 turns per second in the demo). The key scene poses it at angle 0.

```gdscript
## Copies a mesh's arrays and adds the position-averaged normal as vertex colour (n * 0.5 + 0.5)
## for the outline; replace_normals also makes it the shading normal.
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
		var n: Vector3 = acc["%.4f,%.4f,%.4f" % [pos[i].x, pos[i].y, pos[i].z]].normalized()
		smooth[i] = n
		cols[i] = Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0)
	arrays[Mesh.ARRAY_COLOR] = cols
	if replace_normals:
		arrays[Mesh.ARRAY_NORMAL] = smooth
		arrays[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

## An imported generated model: slot material, smoothed normals, outline hull, scaled to `height`
## with its feet on y = 0 and centred.
func place_model(scene: PackedScene, slots: Array, height: float, line_px: float,
		rim := false, face_slot := -1) -> Node3D:
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
		mi.name = src_mi.name            # keeps the turning node addressable by name
		mi.mesh = with_smooth(src_mi.mesh.surface_get_arrays(0), true)
		mi.material_override = slot_material(tex, slots, rim, face_slot)
		mi.transform = xf
		add_hull(mi, line_px)
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

The demo's settings: character 1.75 m tall, outline 3 px, rim on, face slot = the skin slot (0);
building 6.4 m, outline 2.5 px, no rim, no face slot. Both cast shadows; neither receives them.

## Outline: inverted hull in screen pixels

A second `MeshInstance3D` child with the same mesh, this material and shadow casting off:

```gdscript
func add_hull(mi: MeshInstance3D, line_px: float) -> void:
	if line_px <= 0.0: return
	var hull := MeshInstance3D.new()
	hull.mesh = mi.mesh
	hull.material_override = outline_material(line_px)   # one per width; ink, fog colour, fog range set
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(hull)
```

```glsl
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.14, 0.13, 0.23, 1.0);
uniform vec4 fog_color : source_color = vec4(0.81, 0.94, 1.0, 1.0);  // sky-horizon
uniform float width_px = 3.0;               // 3 characters, 2.5 props and buildings, 2 terrain
uniform vec2 fade = vec2(12.0, 60.0);       // full width until x, 1 px at y (metres)
uniform vec2 fog_range = vec2(30.0, 210.0);
varying float depth;

void vertex() {
	vec3 n = COLOR.rgb * 2.0 - 1.0;          // smoothed normal in the vertex colour (raw in vertex())
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n_view = normalize(MODELVIEW_NORMAL_MATRIX * n);   // not MODELVIEW_MATRIX: scaled parts
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

Primitives get the same smoothed normal in their vertex colour (`with_smooth(arrays)` on
`get_mesh_arrays()`), so cubes and cylinder caps don't tear the hull. Use the vertex colour only in
`vertex()`: Compatibility linearises vertex colours on their way into `fragment()`.

## Sky

A `Sky` with this `ShaderMaterial`: four flat steps from `sky-horizon` to `sky-top` packed between
the horizon and about 20° up (where a level game camera sees sky), two steps back toward `sky-top`
below the horizon, a 3° sun disc in `key` with one ring.

```glsl
shader_type sky;

uniform vec4 top : source_color;
uniform vec4 horizon : source_color;
uniform vec4 sun : source_color;
uniform vec3 sun_dir = vec3(-0.51, 0.77, 0.38);   // toward the key light

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void sky() {
	vec3 t = top.rgb, h = horizon.rgb, s = sun.rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	t = to_linear(t); h = to_linear(h); s = to_linear(s);   // Compatibility runs sky shaders in sRGB
#endif
	vec3 d = normalize(EYEDIR);
	float up = floor(clamp(d.y / 0.34, 0.0, 1.0) * 4.0) / 4.0;            // 0, .25, .5, .75, 1
	float down = floor(clamp(-d.y / 0.5, 0.0, 1.0) * 3.0) / 3.0 * 0.35;  // 0, .12, .23, .35
	vec3 c = mix(h, t, max(up, down));
	float a = dot(d, normalize(sun_dir));
	c = mix(c, s, step(cos(radians(1.5)), a));
	c = mix(c, s, 0.3 * step(cos(radians(2.6)), a) * (1.0 - step(cos(radians(2.4)), a)));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c = to_srgb(c);
#endif
	COLOR = c;
}
```

## Environment, light and project settings

```gdscript
var env := Environment.new()
env.background_mode = Environment.BG_SKY          # sky shader above
env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
env.ambient_light_color = Color.BLACK             # the toon shader adds the ambient
env.ambient_light_energy = 0.0
env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
env.tonemap_exposure = 1.0
env.fog_enabled = false                           # mixed in the toon shader
# no SSAO, SSIL, glow or adjustments

var sun := DirectionalLight3D.new()
sun.light_color = key_colour                       # energy 1.0; the shader applies 0.60
sun.shadow_enabled = true
sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
sun.directional_shadow_max_distance = 40.0
sun.shadow_normal_bias = 1.5
sun.shadow_bias = 0.03
sun.shadow_blur = 0.0
```

Project settings: renderer `gl_compatibility`,
`rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality = 0` (Hard),
`directional_shadow/size = 4096`, `anti_aliasing/quality/msaa_3d = 2` (4×; outlines alias without
it). With these values no shadow acne appeared along the band edge. Camera: perspective, 50° vertical
FOV, near 0.1, far 1000.

## Matching the web demo's primitives

To rebuild a three.js scene exactly: build spheres and tori with three.js's own vertex layout
(Godot's `SphereMesh` uses `rings + 1` rows and another start meridian, which changes cloud
silhouettes; `TorusMesh` lies in XZ, three.js's torus in XY). `CylinderMesh` matches with
`rings = 0`. Use `rotation_order = EULER_ORDER_XYZ` when copying three.js rotations, and reverse the
index order of hand-built triangles (Godot's front faces wind clockwise). When a value feeds a hash
(the demo's cloud puffs), keep it a 64-bit `float`: a `Vector3` component is 32-bit, and the rounding
is enough to give every puff a different size.

## Interface

One Theme resource: `StyleBoxFlat` with `panel` fill, 3 px `ink` border, corner radius 10,
`shadow_color` `ink`, `shadow_size` 1 and `shadow_offset` (0, 4) for the hard offset. The key-scene
test doesn't cover the interface (the key scene has none).
