# Godot 4 snippets

<!-- matched-web-frame: bf28a40d479f -->

**Test-rendered** in Godot 4.7.1. `frames/godot-key-scene.png` rebuilds `demo.html?frame=key-scene`
in the **Compatibility** renderer (OpenGL 3.3, the one web exports use). Every mesh is generated in
code, and every value comes from this page. **Forward+** gives the same frame (0.5% of pixels
differ, on edges). Both match the web frame within about 3/255 on ground, paths, caps, stems, cloth
and sky. A lit top face measures 1.7× its shadowed value, as the recipe asks. The one visible
difference is a slightly softer penumbra.

The whole project that rendered the frame, including the code that rebuilds the web demo exactly, is
in this entry's `godot-port/` on the catalog site. This file keeps what a game needs to draw the look.

## Putting it together

```
Node3D (main.gd)
├─ board: Node3D           every part a MeshInstance3D with flat faces and baked shading,
│                          flat.gdshader per role (ghost.gdshader for the placement ghost),
│                          contact blobs and markers with unlit.gdshader
├─ DirectionalLight3D      the sun, soft orthogonal shadows
├─ CanvasLayer -1          full-rect ColorRect with skybg.gdshader: the sky, behind the 3D
├─ WorldEnvironment        background = canvas, ambient black, reflections off, tonemap Linear
├─ Camera3D                orthographic isometric
└─ CanvasLayer             tilt-shift: ColorRect (h) → BackBufferCopy → ColorRect (v)
```

Project settings: `rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality = 2`
(Soft Medium), `directional_shadow/size = 2048`, `anti_aliasing/quality/msaa_3d = 2` (4×). Nothing
banded in Compatibility.

**Renderer:** Compatibility for web exports and the safe default. Forward+ draws the same frame with
these shaders. If Forward+ adds SSAO, keep it light (radius 0.3–0.5, intensity ≤ 0.5) and raise the
vertex shading's minimum from 0.72 to 0.85 so the two don't stack.

## Why there is no `StandardMaterial3D` here

In Compatibility (4.7.1), an Environment ambient colour plus a shadow-casting sun brightens lit
faces, and Environment fog is applied in both passes. Godot's ambient also has no ground colour.
One small shader does it all instead: flat faces, baked ground shading, a hemisphere fill and the
fog are all mixed inside `light()` for the sun, and the Environment's ambient stays black. Colours
that `light()` reads are plain `vec3` uniforms with linear values set from a `Vector3`:
Compatibility doesn't linearise `source_color` uniforms read in `light()`, and Forward+ converts a
`Color` passed to a `vec3`.

`flat.gdshaderinc`:

```glsl
// Flat-lit toy material. Meshes carry flat face normals (no shared vertices) and the baked ground
// shading in the vertex colour. The hemisphere fill and the fog are applied inside light() for the
// sun, with the Environment's ambient black: one pass writes the whole colour, so Forward+ and
// Compatibility agree (see godot.md). Colours read in light() are linear Vector3 uniforms.

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 sky_linear = vec3(0.6, 0.7, 0.8);     // sky-top mixed 45% toward white
uniform vec3 ground_linear = vec3(0.12, 0.11, 0.24); // shadow
uniform float hemi_ratio = 0.70;
uniform float sun_ratio = 0.51;
uniform vec3 fog_linear = vec3(0.93, 0.73, 0.59);   // sky-low
uniform vec2 fog_range = vec2(43.0, 66.0);          // view depth, smoothstep
uniform vec3 emission_linear = vec3(0.0);           // ghost: accent x 0.25
uniform float alpha = 1.0;

varying vec3 up_view;
varying float view_depth;

void vertex() {
	up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void fragment() {
	vec3 shade = COLOR.rgb;   // baked ground shading, a plain multiplier
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	shade = to_srgb(shade);   // Compatibility hands vertex colours over linearised; undo it
#endif
	ALBEDO = albedo.rgb * shade;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
#ifdef GHOST
	ALPHA = alpha;   // only the ghost is transparent: writing ALPHA moves a material to the transparent pass
#endif
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	vec3 sun = LIGHT_COLOR / PI * sun_ratio * ndl * ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 hemi = mix(ground_linear, sky_linear, 0.5 * dot(NORMAL, normalize(up_view)) + 0.5) * hemi_ratio;
		vec3 a = max(ALBEDO, vec3(1e-4));
		vec3 c = hemi + sun + emission_linear / a;
		float f = smoothstep(fog_range.x, fog_range.y, view_depth);
		DIFFUSE_LIGHT += mix(c, fog_linear / a, f);
	} else {
		DIFFUSE_LIGHT += sun;
	}
}
```

`flat.gdshader` (every role) and `ghost.gdshader` (the placement ghost):

```glsl
shader_type spatial;
render_mode specular_disabled;
#include "res://flat.gdshaderinc"
```

```glsl
shader_type spatial;
render_mode specular_disabled, depth_draw_never, shadows_disabled;
#define GHOST
#include "res://flat.gdshaderinc"
```

A shader that writes `ALPHA` anywhere sends **every** material using it to the transparent pass,
which has no depth write. In the test, the ground slab then drew over the whole village. Only the
ghost variant may write it. The ghost is `paper` at alpha 0.7 with `render_priority = 2`, and it
casts no shadow.

The materials, one per role, from the palette (`P` holds the roles as `"role": "#RRGGBB"`):

```gdscript
func c(role: String) -> Color: return Color(P[role])

func lin3(col: Color) -> Vector3:
	var l := col.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)

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
```

## Flat facets and baked shading from code

Emit each triangle with its own three vertices and the face normal, so no vertex is shared. Put the
baked ground shading in `ARRAY_COLOR`: 0.72 at height 0, rising with a smoothstep to 1.0 at 0.55
(the slab: 0.8 at its underside to 1.0 at its top). Godot's front faces wind clockwise, so reverse
counter-clockwise triangles. Bake the part's transform into the vertices, so the height used for
the shading is the height above the ground.

```gdscript
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
```

The chamfered box, the toy's basic block, is a rectangle extruded with one 45° bevel on its top and
bottom edges; its vertical edges stay sharp. The port builds it and every other part (cylinders,
spheres, capsules, polyhedra) as triangle lists cloned from the web demo's three.js generators so
each facet matches; a game can feed `build_mesh()` any triangle list, or use meshes from Blender
(Shade Flat, export glTF, paint the vertex colour).

## Contact blobs, accent ring and markers

`unlit.gdshader`, fogged by hand with the same curve. Blobs are `PlaneMesh` quads 0.006 above the
ground with `render_priority = 1`, in the `shadow` colour. No z-fighting showed with the
orthographic camera. A `Decal` also works in Forward+.

```glsl
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
// Accent ring, markers and contact blobs: unlit, fogged by hand with the same curve.
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 fog_color : source_color = vec4(0.97, 0.87, 0.79, 1.0);
uniform vec2 fog_range = vec2(43.0, 66.0);
uniform bool blob = false;           // radial contact blob: alpha 1 inside 1/8 radius to 0 at the edge
uniform float blob_opacity = 0.45;
varying float view_depth;

void vertex() {
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	ALBEDO = mix(color.rgb, fog_color.rgb, smoothstep(fog_range.x, fog_range.y, view_depth));
	if (blob) {
		float d = length(UV * 2.0 - 1.0);
		ALPHA = blob_opacity * clamp((1.0 - d) / 0.875, 0.0, 1.0);
	}
}
```

```gdscript
var blob_mat: ShaderMaterial

func blob(g: Node3D, r: float, y := 0.006) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(r * 2, r * 2)
	mi.mesh = pm; mi.position.y = y
	mi.material_override = blob_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
```

**Raised tiles:** path slabs' tops 0.04 above the ground, never coplanar.

## Sun, sky, environment, camera and tilt-shift

The `TOY_*` environment variables were switches for the test runs; unset, they give the values
shown (shadows on, max distance 30, blur 0.5, tilt-shift on). `shadow_blur` 1.5 washes the house
shadows out. The sun sits at elevation about 55°, about 70° off the camera's yaw.

```gdscript
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
```

`skybg.gdshader`. `SCREEN_UV` in a sky shader does nothing in Compatibility, and a 2D gradient
blends in sRGB like the web demo's:

```glsl
shader_type canvas_item;
// Screen-space sky: sky-top at the top to sky-low at 75% height, flat below. A 2D gradient blends in
// sRGB, like the web demo's canvas gradient; drawn as the Environment's canvas background.
uniform vec4 top : source_color;
uniform vec4 low : source_color;
void fragment() {
	COLOR = vec4(mix(top.rgb, low.rgb, clamp(UV.y / 0.75, 0.0, 1.0)), 1.0);
}
```

`tilt.gdshader`, run twice. Blurring in linear light matches the web demo's float buffer. Uniform
defaults must be literals: `2.5 / 1280.0` does not compile.

```glsl
shader_type canvas_item;
// One pass of the separable tilt-shift (run twice: horizontal, then vertical after a
// BackBufferCopy). Blur grows with distance from the focus line; weights as three.js'
// HorizontalTiltShiftShader. Blurred in linear light.
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform vec2 step_uv = vec2(0.001953125, 0.0);    // 2.5 / 1280: 2.5 px per unit of distance at 720p
uniform float focus = 0.48;                        // focus line, from the bottom

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

const float w[5] = { 0.1633, 0.1531, 0.12245, 0.0918, 0.051 };

void fragment() {
	vec2 d = step_uv * abs(focus - (1.0 - SCREEN_UV.y));
	vec3 s = to_linear(texture(screen, SCREEN_UV).rgb) * w[0];
	for (int i = 1; i < 5; i++) {
		s += to_linear(texture(screen, SCREEN_UV - d * float(i)).rgb) * w[i];
		s += to_linear(texture(screen, SCREEN_UV + d * float(i)).rgb) * w[i];
	}
	COLOR = vec4(to_srgb(s), 1.0);
}
```

The test checked the tilt-shift's look in both renderers, not its cost: 18 screen-texture reads
per pixel. Measure it on the weakest target before keeping it.

## Not in the test

**Placement bounce** (the static key scene doesn't exercise it):

```gdscript
func drop_in(node: Node3D) -> void:
	node.scale = Vector3.ONE * 0.6
	node.position.y = 0.6
	var t := node.create_tween().set_parallel()
	t.tween_property(node, "position:y", 0.0, 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(node, "scale", Vector3.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```
