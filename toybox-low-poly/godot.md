# Godot 4 snippets

<!-- matched-web-frame: bf28a40d479f -->

**Test-rendered** in Godot 4.7.1. `frames/godot-key-scene.png` rebuilds `demo.html?frame=key-scene`
in the **Compatibility** renderer (OpenGL 3.3, the one web exports use). Every mesh is generated in
code, and every value comes from this page. **Forward+** gives the same frame (0.5% of pixels
differ, on edges). Both match the web frame within about 3/255 on ground, paths, caps, stems, cloth
and sky. A lit top face measures 1.7× its shadowed value, as the recipe asks. The one visible
difference is a slightly softer penumbra.

**Why there is no `StandardMaterial3D` here.** In Compatibility (4.7.1), an Environment ambient
colour plus a shadow-casting sun brightens lit faces, and Environment fog is applied in both
passes. Godot's ambient also has no ground colour. One small shader does it all instead: flat
faces, baked ground shading, a hemisphere fill and the fog are all mixed inside `light()` for the
sun, and the Environment's ambient stays black. Colours that `light()` reads are plain `vec3`
uniforms with linear values set from a `Vector3`: Compatibility doesn't linearise `source_color`
uniforms read in `light()`, and Forward+ converts a `Color` passed to a `vec3`.

```gdscript
static func lin3(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)
# sky_linear = lin3(sky-top) lerped 45% toward white (in linear); ground_linear = lin3(shadow);
# fog_linear = lin3(sky-low); ghost emission_linear = lin3(accent) × 0.25
```

`flat.gdshaderinc`:

```glsl
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 sky_linear = vec3(0.6, 0.7, 0.8);
uniform vec3 ground_linear = vec3(0.12, 0.11, 0.24);
uniform float hemi_ratio = 0.70;   // fill : sun ≈ 1.4 : 1 (three.js hemisphere 2.2 and sun 1.6, ÷ π)
uniform float sun_ratio = 0.51;
uniform vec3 fog_linear = vec3(0.93, 0.73, 0.59);
uniform vec2 fog_range = vec2(43.0, 66.0);   // view depth, smoothstep: only the back edge softens
uniform vec3 emission_linear = vec3(0.0);
uniform float alpha = 1.0;
varying vec3 up_view;
varying float view_depth;

void vertex() {
	up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;   // light() cannot read VERTEX
}

vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void fragment() {
	vec3 shade = COLOR.rgb;   // baked ground shading, a plain multiplier
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	shade = to_srgb(shade);   // Compatibility linearises vertex colours on the way into fragment()
#endif
	ALBEDO = albedo.rgb * shade;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
#ifdef GHOST
	ALPHA = alpha;            // see below: only the ghost variant writes ALPHA
#endif
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	vec3 sun = LIGHT_COLOR / PI * sun_ratio * ndl * ATTENUATION;   // LIGHT_COLOR has ×PI
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

**Flat facets and baked shading from code.** Emit each triangle with its own three vertices and the
face normal, so no vertex is shared. Put the baked ground shading in `ARRAY_COLOR`: 0.72 at
height 0, rising with a smoothstep to 1.0 at 0.55 (the slab: 0.8 at its underside to 1.0 at its
top). Godot's front faces wind clockwise, so reverse three.js-style counter-clockwise triangles:

```gdscript
func flat_mesh(tris: Array, xf: Transform3D, ao_lo := 0.0, ao_hi := 0.55, ao_min := 0.72) -> ArrayMesh:
	var v := PackedVector3Array(); var n := PackedVector3Array(); var col := PackedColorArray()
	for t in tris:   # t = [a, b, c], counter-clockwise seen from outside
		var p := [xf * t[0], xf * t[1], xf * t[2]]
		var fn: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
		for k in [0, 2, 1]:
			v.append(p[k]); n.append(fn)
			var s: float = ao_min + (1.0 - ao_min) * smoothstep(ao_lo, ao_hi, p[k].y)
			col.append(Color(s, s, s))
	var a := []; a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v; a[Mesh.ARRAY_NORMAL] = n; a[Mesh.ARRAY_COLOR] = col
	var m := ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m
```

Bake the part's transform into the vertices (as the web demo does), so the height used for the
shading is the height above the ground. Meshes from Blender work too: Shade Flat, export glTF,
paint the vertex colour. The chamfered box is a rectangle extruded with one 45° bevel on its top
and bottom edges; its vertical edges stay sharp.

**Sun with soft shadows:**

```gdscript
var sun := DirectionalLight3D.new()
sun.light_color = Color(1, 0.953, 0.878)            # warm white; energy 1.0, the shader applies 0.51
sun.shadow_enabled = true
sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
sun.directional_shadow_max_distance = 30.0
sun.shadow_blur = 0.5                               # 1.5 washes the house shadows out
sun.shadow_normal_bias = 1.0
# placed at (-7, 16, 9) looking at the board centre: elevation ~55°, ~70° off the camera's yaw
```

Project settings: `rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality = 2`
(Soft Medium), `directional_shadow/size = 2048`, `anti_aliasing/quality/msaa_3d = 2` (4×). Nothing
banded in Compatibility.

**Environment:**

```gdscript
var env := Environment.new()
env.background_mode = Environment.BG_CANVAS        # the sky gradient is a CanvasLayer behind 3D
env.background_canvas_max_layer = -1
env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
env.ambient_light_color = Color.BLACK              # the shader adds the fill
env.ambient_light_energy = 0.0
env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
env.tonemap_mode = Environment.TONE_MAPPER_LINEAR  # palette colours land as authored
# fog off (mixed in the shader); no SSAO: the vertex shading and contact blobs carry the occlusion
```

**Sky:** a `CanvasLayer` with `layer = -1` holding a full-rect `ColorRect` with this shader.
`SCREEN_UV` in a sky shader does nothing in Compatibility, and a 2D gradient blends in sRGB like
the web demo's:

```glsl
shader_type canvas_item;
uniform vec4 top : source_color;   // sky-top
uniform vec4 low : source_color;   // sky-low
void fragment() {
	COLOR = vec4(mix(top.rgb, low.rgb, clamp(UV.y / 0.75, 0.0, 1.0)), 1.0);
}
```

**Contact blobs, accent ring and markers:** an `unshaded` spatial shader (`fog_disabled`,
`shadows_disabled`) that fogs its colour by hand with the same `smoothstep(43, 66, view depth)`.
Blobs are `PlaneMesh` quads 0.006 above the ground with `render_priority = 1`. Their alpha is
`0.45 × clamp((1 − d) / 0.875, 0, 1)` in the `shadow` colour, where `d` is the distance from the
centre in UV (×2). No z-fighting showed with the orthographic camera. A `Decal` also works in
Forward+.

**Orthographic isometric camera** (as used in the test):

```gdscript
func setup_iso(cam: Camera3D, target: Vector3, view_height: float) -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = view_height                       # vertical size in world units (11.5 in the test)
	cam.near = 0.1
	cam.far = 200.0
	var pitch := atan(1.0 / sqrt(2.0))           # 35.264°
	var yaw := deg_to_rad(45.0)
	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	cam.look_at_from_position(target + dir * 40.0, target, Vector3.UP)
```

**Tilt-shift:** a `CanvasLayer` above the 3D. Add a full-rect `ColorRect` with this shader
(horizontal, `step_uv = (2.5 / 1280, 0)`), then a `BackBufferCopy` (copy mode Viewport), then a
second `ColorRect` (vertical, `step_uv = (0, 2.5 / 720)`). Blurring in linear light matches the web
demo's float buffer. Uniform defaults must be literals: `2.5 / 1280.0` does not compile.

```glsl
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform vec2 step_uv = vec2(0.001953125, 0.0);   // 2.5 px per unit of distance at 720p
uniform float focus = 0.48;                       // focus line, from the bottom

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

The test checked its look in both renderers, not its cost: 18 screen-texture reads per pixel.
Measure it on the weakest target before keeping it.

**Placement bounce** (the static key scene doesn't exercise it):

```gdscript
func drop_in(node: Node3D) -> void:
	node.scale = Vector3.ONE * 0.6
	node.position.y = 0.6
	var t := node.create_tween().set_parallel()
	t.tween_property(node, "position:y", 0.0, 0.19).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(node, "scale", Vector3.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

**Raised tiles:** path slabs' tops 0.04 above the ground, never coplanar.

**Renderer:** Compatibility for web exports and the safe default. Forward+ draws the same frame with
these shaders. If Forward+ adds SSAO, keep it light (radius 0.3–0.5, intensity ≤ 0.5) and raise the
vertex shading's minimum from 0.72 to 0.85 so the two don't stack.
