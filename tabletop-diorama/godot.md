# Godot 4 snippets

<!-- matched-web-frame: 2a45adcaadb7 -->

> **The `assets/` paths below load this entry's example art**, which is how the port was tested against the web demo. A game never ships it: load the game's own models, sprites and textures, made the same way, in their place.

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.*` rebuilds
`demo.html?frame=key-scene` from the entry's own GLBs, painted maps and tiling materials, with the
code below. Measured against `frames/key-scene.jpg`: mean difference 3.6 / 2.9 / 4.0 per 255 (R, G,
B) for the raw render, 2.7 / 2.5 / 2.7 for the saved JPEG; 13% of pixels differ by more than 8 and
2% by more than 24, all on edges and text. **Forward+** renders the same frame (0.8/255 from
Compatibility). The whole project that rendered the frame, including the code that rebuilds the web
demo exactly, is in this entry's `godot-port/` on the catalog site.

What still differs from the web frame, and why:

- **Text.** Godot and Chrome rasterise glyphs differently, and the browser synthesises small caps
  and spaces letters by fractions of a pixel. The paper cards are the worst tiles, at about 14/255.
- **Shadow edges.** Compatibility ignores `shadow_blur`, so the edge is a little harder than the
  web's `PCFSoftShadowMap`.
- **Antialiased edges.** MSAA resolves after the sRGB encode here and before it on the web.
- **Bloom is left out.** In the sunny scheme nothing reaches the web's bloom threshold. The candlelit
  scheme needs it back (see the end).

## How the frame is built

- **Renderer:** Compatibility, 1280×720, MSAA 4×, anisotropic filtering 8×, directional shadow
  atlas 4096. `project.godot`:

  ```ini
  [rendering]
  renderer/rendering_method="gl_compatibility"
  anti_aliasing/quality/msaa_3d=2
  textures/default_filters/anisotropic_filtering_level=3
  lights_and_shadows/directional_shadow/size=4096
  ```

- **One light pass does everything.** A `DirectionalLight3D` (white, energy 1, shadows on) only
  supplies the direction and the shadow; `wood.gdshader` does the shading inside `light()`: Lambert
  diffuse plus a matte GGX specular (F0 0.04) for the key, a hemisphere fill (sky `fill`, ground
  `table` × 0.5, intensity 2), and linear fog (smoothstep on view depth, 15 to 28). The
  Environment's ambient stays black and its fog off.
- **HDR through an 8-bit viewport.** The scene writes half its linear value (`out_scale` 0.5), the
  Environment tone mapper is Linear, and one full-screen pass (`lens.gdshader`, a `CanvasLayer`
  above the 3D) doubles it back, then runs the post chain in order: tilt-shift (16 golden-angle
  taps, focus line at 0.46, 5 px at 720p), vignette 0.3, grade (1.03, 1.0, 0.95) at 60%, then an
  ACES filmic curve and the sRGB encode. The background colour is `room` scaled the same way, so it
  is tone-mapped with the rest.
- **Flat shading:** every mesh is rebuilt with one face normal per triangle (`to_mesh`), generated
  models included; their own normals are dropped.
- **Camera:** `fov` 36 (vertical), from (0, 7.0, 8.2) looking at (0, 0.35, −0.3), plus the idle
  sway. Units are the recipe's (1 ≈ 10 cm).
- **Interface:** `PanelContainer` paper cards in a `CanvasLayer` above the lens pass: `paper` fill,
  corner radius 2, shadow 8 px at (0, 4) and 30% black, rotated about their centre; text in `ink`.

## Import settings

- **GLBs:** `meshes/generate_lods=false`, `meshes/force_disable_compression=true`,
  `meshes/ensure_tangents=false`. Only positions, UVs and indices are used.
- **Colour maps** (table, street, painted model maps): lossless (`compress/mode=0`), mipmaps on. At
  load, `lin_tex()` converts each to linear bytes and builds the mipmaps from the linear values (see
  the traps). **Normal maps:** lossless, mipmaps on, `compress/normal_map=2` (no Godot conversion).
- **Font:** the demo bundles Gelasio (SIL Open Font License, metric-compatible with Georgia) as WOFF
  in `assets/fonts/`; the port loads the same file from `res://fonts/` in `_ready()`:

  ```gdscript
  font = load("res://fonts/Gelasio-Variable.woff")   # the demo's bundled face (variable; default instance is 400)
  ```

## Compatibility traps

From `godot-compatibility.md` (copied beside this file), as they show here:

- **2:** albedo is computed in linear and handed to Compatibility as `to_srgb(albedo)`.
- **15:** colour maps' mipmaps came out about 2/255 darker; `lin_tex()` converts once at load and
  builds the mipmaps from the linear values.
- **12:** with `shadow_blur` doing nothing, 4096 over 22 units is closest to the web's penumbra
  (2048, 8192, 16 or 40 units were all further off).
- **13:** `shadow_normal_bias` 1.0 darkened lit faces about 1.5%; 2.0 removes it.
- **3, 8, 9:** fill and fog are mixed inside `light()`; linear colours go in as `Vector3`.
- **14:** the accent ring has a shader of its own.

Also worth knowing: **three.js scales a normal map by the texture's stretch** (its tangent frame
comes from screen derivatives, scaled by the longer axis), so a tile stretched 2:1 gets half the
tilt on its long axis. The port does the same with `normal_scale` (0.5, 1.0) on the table; use it
whenever a tile is stretched unevenly.
## Shaders

`wood.gdshader` (every lit surface):

```glsl
// Painted wood, table and street: three.js MeshStandardMaterial (r160) rebuilt in light().
// Diffuse = colour x map, matte GGX specular (F0 0.04), a hemisphere fill and linear-space fog, all
// in the directional light's pass with the Environment's ambient black (see godot.md).
// The result is written scaled by out_scale so HDR values up to 1/out_scale survive the 8-bit
// viewport; the lens pass (lens.gdshader) undoes the scale, then tone-maps with three's ACES.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 color_lin = vec3(1.0);            // palette role, linear (set as Vector3 from GDScript)
uniform sampler2D map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;   // linear bytes (see lin_img)
uniform vec2 repeat = vec2(1.0);
uniform bool flip_y = true;                    // three CanvasTexture / TextureLoader default
uniform float rough = 0.8;
uniform bool use_normal = false;               // only flat horizontal planes (table, street)
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 normal_scale = vec2(1.0);
uniform vec3 key_lin = vec3(3.0);              // key colour x intensity
uniform vec3 sky_lin = vec3(2.0);              // hemisphere sky colour x intensity
uniform vec3 ground_lin = vec3(0.0);           // hemisphere ground colour x intensity
uniform vec3 fog_lin = vec3(0.7);
uniform vec2 fog_range = vec2(15.0, 28.0);     // view depth, smoothstep (three.js Fog)
uniform float out_scale = 0.5;

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

varying float view_depth;
varying vec3 up_view;

void vertex() {
	up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec2 uv = UV * repeat;
	if (flip_y) uv.y = 1.0 - uv.y;
	vec3 albedo = color_lin * texture(map, uv).rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = to_srgb(albedo);   // Compatibility linearises ALBEDO after fragment(); hand it sRGB
#else
	ALBEDO = albedo;
#endif
	if (use_normal) {
		vec3 n = texture(normal_tex, uv).rgb * 2.0 - 1.0;
		n.xy *= normal_scale;
		// plane lies in world XZ: tangent +x, bitangent (three's +v) -z, normal +y
		vec3 wn = normalize(vec3(n.x, n.z, -n.y));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
}

void light() {
	vec3 N = NORMAL;
	vec3 V = VIEW;
	vec3 L = LIGHT;
	float ndl = clamp(dot(N, L), 0.0, 1.0);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	vec3 H = normalize(L + V);
	float ndh = clamp(dot(N, H), 0.0, 1.0);
	float vdh = clamp(dot(V, H), 0.0, 1.0);
	float a = rough * rough;
	float a2 = a * a;
	float fr = exp2((-5.55473 * vdh - 6.98316) * vdh);
	float F = 0.04 * (1.0 - fr) + fr;
	float gv = ndl * sqrt(a2 + (1.0 - a2) * ndv * ndv);
	float gl = ndv * sqrt(a2 + (1.0 - a2) * ndl * ndl);
	float vis = 0.5 / max(gv + gl, 1e-6);
	float den = ndh * ndh * (a2 - 1.0) + 1.0;
	float D = a2 / (PI * den * den);
	vec3 direct = key_lin * ndl * ATTENUATION;
	vec3 hemi = mix(ground_lin, sky_lin, 0.5 * dot(N, normalize(up_view)) + 0.5);
	vec3 col = ALBEDO / PI * (direct + hemi) + direct * F * vis * D;
	col = mix(col, fog_lin, smoothstep(fog_range.x, fog_range.y, view_depth));
	DIFFUSE_LIGHT += col * out_scale / max(ALBEDO, vec3(1e-4));
}
```

`ring.gdshader` (the accent ring):

```glsl
// The accent ring: unlit, fogged, 95% opaque, drawn over the street without writing depth.
// Its own shader, because writing ALPHA moves every material using a shader to the transparent pass.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 color_lin = vec3(1.0, 0.0, 0.5);
uniform vec3 fog_lin = vec3(0.7);
uniform vec2 fog_range = vec2(15.0, 28.0);
uniform float out_scale = 0.5;
varying float view_depth;
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
void vertex() { view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	vec3 col = mix(color_lin, fog_lin, smoothstep(fog_range.x, fog_range.y, view_depth)) * out_scale;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	col = to_srgb(col);   // Compatibility linearises ALBEDO after fragment(), unshaded too
#endif
	ALBEDO = col;
	ALPHA = 0.95;
}
```

`lens.gdshader` (tilt-shift, vignette, grade, ACES, on a full-rect `ColorRect` in a `CanvasLayer`
at layer 1):

```glsl
// The miniature lens, one full-screen pass over the 3D: undo the scene's out_scale, tilt-shift
// (16 golden-angle taps, as demo.html), vignette and grade in linear light, then three.js r160's
// ACES filmic curve and the sRGB encode (three's OutputPass).
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float in_scale = 2.0;          // 1 / the scene's out_scale
uniform float focus = 0.46;            // focus line, from the bottom
uniform float amount_px = 5.0;         // full blur radius at 720p
uniform float vignette = 0.3;
uniform vec3 grade = vec3(1.03, 1.0, 0.95);
uniform float grade_amount = 0.6;
uniform float exposure = 1.0;

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

vec3 aces(vec3 c) {
	const mat3 IN = mat3(vec3(0.59719, 0.07600, 0.02840), vec3(0.35458, 0.90834, 0.13383), vec3(0.04823, 0.01566, 0.83777));
	const mat3 OUT = mat3(vec3(1.60475, -0.10208, -0.00327), vec3(-0.53108, 1.10813, -0.07276), vec3(-0.07367, -0.00605, 1.07602));
	c *= exposure / 0.6;
	c = IN * c;
	vec3 a = c * (c + 0.0245786) - 0.000090537;
	vec3 b = c * (0.983729 * c + 0.4329510) + 0.238081;
	c = OUT * (a / b);
	return clamp(c, 0.0, 1.0);
}

void fragment() {
	float y = 1.0 - SCREEN_UV.y;                    // three's vUv.y grows upward
	float d = y - focus;
	float b = d > 0.0 ? smoothstep(0.1, 0.5, d) : 0.3 * smoothstep(0.2, 0.55, -d);
	float r = b * amount_px * (1.0 / SCREEN_PIXEL_SIZE.y) / 720.0;
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		float a = fi * 2.39996;
		acc += to_linear(texture(screen, SCREEN_UV + vec2(cos(a), -sin(a)) * sqrt(fi / 16.0) * r * SCREEN_PIXEL_SIZE).rgb);
	}
	vec3 c = acc / 16.0 * in_scale;
	float v = smoothstep(1.05, 0.25, length((vec2(SCREEN_UV.x, y) - vec2(0.5, 0.52)) * vec2(1.1, 1.25)));
	c *= mix(1.0, v, vignette);
	c = mix(c, c * grade, grade_amount);
	COLOR = vec4(to_srgb(aces(c)), 1.0);
}
```

## Script helpers

These come from `main.gd` on the root `Node3D` of the main scene. Paths assume models in
`res://models/` and textures in `res://textures/`. Left out, and kept in `godot-port/`: a bit-exact
copy of the demo's random generator, clones of three.js's cylinder, sphere, icosahedron, capsule and
torus generators (so the seeded carve moved the same vertices as on the web), and the example scene
with its pieces and card text. Any primitive works with `carve()`: read a Godot `PrimitiveMesh`'s
arrays the way `model_tris()` reads a GLB (swap the second and third index of each triangle back to
counter-clockwise). `carve()` and `make_grain()` call `rnd()`, a seeded float in [0, 1); a
`RandomNumberGenerator` with a fixed seed does the job:

```gdscript
var rng := RandomNumberGenerator.new()   # set rng.seed once, so the facets are the same every run
func rnd() -> float: return rng.randf()
```

**Palette, materials and the grain.** `P` is the example palette; put the game's roles in it.
`lit()` hands every material the light, fill and fog:

```gdscript
extends Node3D

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
```

**Geometry, carve and flat shading.** `jkey()` keeps −0 and 0 apart only to match the web; any
rounding to 0.001 works as the carve's key:

```gdscript
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
```

**Generated models, flat-shaded.** `model()` loads a GLB's first mesh, centres it on x/z with its
base on y = 0 and scales it to a height (and optionally a width and depth factor). `ray_z()` finds
a model's blank sign board, so live text can sit on it:

```gdscript
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
```

**Live text on signs and cards in the world.** Drawn once in a `SubViewport`, then kept as a
linearised, mipmapped texture; call `bake_labels()` once after the scene is built:

```gdscript
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
```

**Light, room, camera and lens:**

```gdscript
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
```

**Paper cards on screen.** `card()` makes one rotated paper card; put `text()` labels (or a
`VBoxContainer` of them) inside it, in a `CanvasLayer` at layer 2. Its `nudge` moved the glyphs to
where Chrome puts them; leave it at 0. The demo's small caps are imitated with uppercase at 70% size
and letter spacing of 1 px on a `FontVariation`:

```gdscript
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
```

## Putting it together

```text
Main (Node3D, main.gd)
├── world (Node3D)            table plane, base, full-size objects beside it
│   └── board (Node3D)        the miniature: street, buildings, figurines, props, accent rings
├── DirectionalLight3D        direction and shadow only
├── WorldEnvironment          black ambient, Linear tone mapper, background = room × out_scale
├── Camera3D
├── CanvasLayer 1             ColorRect with lens.gdshader
├── CanvasLayer 2             paper cards
└── SubViewports              live text for signs, freed after bake_labels()
```

In `_ready()`: set the font, `grain = make_grain()`, build the table and the base, put the pieces on
the board, then `build_env()`, the cards, and `bake_labels()`.

- **Pieces built in code** use `paint(role)` (or `paint("wood-bare", 0.9)` for bare wood) and go
  through `carve()` with an amount of 2–4% of the piece's size, then `part()`.
- **Generated models** use `textured(lin_tex(<painted map>), 0.82)` through `model()`.
- **The figurine** is one body for every character, from code: a round base, legs, a coat, two arm
  capsules, an icosahedron head, two ink eyes, then one silhouette piece (a hat, an apron, a basket).
  Proportions are in `recipe.md`; repaint it per character.

**The table and the street** are `textured()` planes with a normal map, colour = the palette role.
The table, from the scene script (a 26 × 18 plane, one tile per 12 × 6 units):

```gdscript
	var tm := textured(lin_tex("res://textures/table_color.jpg"), 0.7, true, c("table"))
	tm.set_shader_parameter("repeat", Vector2(26.0 / 12.0, 18.0 / 6.0))
	tm.set_shader_parameter("use_normal", true)
	# three.js builds the tangent frame from screen derivatives and scales both axes by the longer one:
	# a tile stretched 12 x 6 units halves the x tilt of the normal map. Same here.
	tm.set_shader_parameter("normal_scale", Vector2(0.5, 1.0))
	tm.set_shader_parameter("normal_tex", load("res://textures/table_normal.jpg"))
	part(world, plane(26, 18), tm, Vector3.ZERO, Vector3(-PI / 2, 0, 0), Vector3.ONE, false)
```

**The accent ring** goes around what can be acted on now, unlit, pulsing ±6% at 1.2 Hz (`T` is the
time):

```gdscript
	var rm := ShaderMaterial.new(); rm.shader = ring_shader
	rm.set_shader_parameter("color_lin", lin3(c("accent"))); rm.set_shader_parameter("fog_lin", lin3(c("room")))
	rm.set_shader_parameter("fog_range", FOG); rm.set_shader_parameter("out_scale", OUT_SCALE)
	rm.render_priority = 1
	part(board, ring_geo(0.56, 0.6, 48), rm, Vector3(0.85, 0.012, 0.3), Vector3(-PI / 2, 0, 0), Vector3.ONE * (1 + 0.06 * sin(T * TAU * 1.2)), false)
```

## Other lighting schemes

`demo.html` holds the palettes and light values of the evening candlelight and the cool morning
window. In this port they change the constants at the top of `main.gd` and the lens uniforms; only
the sunny scheme has been rendered. The morning scheme is a sun at (−8, 4.5, −1), intensity 3.2,
fill 1.6, fog 15 to 26, vignette 0.35, grade (0.97, 1.0, 1.05). The candle scheme needs what this
port leaves out:

- a `SpotLight3D` key from (0.4, 8.4, 0.6) toward (0, 0, −0.5): intensity 95, cone 0.9 rad,
  penumbra 0.6, decay 1.6. Add a branch for `LIGHT_IS_DIRECTIONAL == false` in `wood.gdshader`
  with the spot's falloff, and keep the hemisphere and fog in one light's pass only;
- a candle `OmniLight3D` (`ffb070`, intensity 5, range 7, decay 1.6) with the flicker
  `0.97 + 0.03 × sin(7.3 t) × sin(2.1 t)` on both lights;
- bloom on the flame and lit windows (threshold 0.82, strength 0.55): a bright-pass and blur in
  the lens layer before the ACES curve, because Compatibility's glow can't run on this
  half-scaled, linear-tonemapped frame;
- fill 6.0, exposure 1.05, vignette 0.85, grade (1.06, 0.98, 0.86), fog 14 to 23.
