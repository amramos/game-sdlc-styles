# Godot 4 port

<!-- matched-web-frame: 31a8ad2bca70 -->

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.*` rebuilds
`demo.html?frame=key-scene`: the same printed pieces (this entry's own images), camera, lighting
plot, card edges, shadows, flown placard, markers and pinned slip. Measured against
`frames/key-scene.jpg`: mean difference 3.1 / 3.0 / 2.9 per 255 (RGB) for the delivered JPEG,
4.3 / 3.6 / 4.0 for the lossless capture, and 1.5% of pixels differ by more than 24. What is left
is texture detail (Godot's anisotropic filtering keeps the hatching slightly crisper than WebGL's,
and the web frame's JPEG smears colour), glyph rasterisation on the slip and placard, and dark
tones that land one or two levels low in Compatibility (trap 6). Forward+ renders the same code to
within 2/255 of Compatibility.

One place where the web frame is off: below the frame at the far left and right edges (around
y 560), the floor box's front face z-fights with the house wall in three.js, a 60 × 12 px band of
stripes. The port sets that face 0.001 behind the wall, so only the stage lip shows it.

## How the look is built

- **The stage box.** Every printed piece is a textured quad: the back cloth (one sheet, mirrored
  at the sides), the floor (the plank print mirrored both ways), three ground rows (each strip
  repeated so it keeps its height), two pairs of wings, the cast and props, the drapes, the
  valance and the proscenium, scaled so its keyed opening is 7.8 wide. Sizes, depths and turns
  are the recipe's; `main.gd` below lays out the example key scene.
- **The paper edge.** Each cut-out is two planes: the print, alpha-tested at 0.5, and 0.018
  behind it a card-coloured plane that keeps only the print's alpha, offset 0.022 down and away
  from the key light and grown 0.015 a side. Both cast shadows; the drapes and valance don't.
- **The light.** No Godot lights at all. One unshaded shader (`paper.gdshader`) computes the plot
  the way three.js's `MeshStandardMaterial` does: Lambert plus GGX specular for each spot
  (smoothstep cone, no distance falloff) and a hemisphere fill (sky `light-fill`, ground
  `boards`), from linear uniforms. It reads two shadow maps the stage renders itself: for the key
  and the footlights, a 2048² `SubViewport` with a square perspective camera at the light (fov
  twice the cone, near 3, far 45) draws the casters, which sit on render layer 2, with
  `depth.gdshader`; the paper shader samples them with three.js's 9-tap PCF-soft filter, bias
  −0.0006, normal bias 0.02. This is what keeps Compatibility right (traps 1 and 2). It costs two
  depth renders a frame; in a game, update them only when something on stage moves.
- **The prints are linearised once at start-up.** Each texture is drawn into an HDR 2D
  `SubViewport` through `linearize.gdshader`, read back as half floats and mipmapped on the CPU,
  so the mips average in linear light as WebGL's do for sRGB textures. With the importer's
  mipmaps (averaged in sRGB) the finely hatched prints come out up to 10 levels darker at stage
  distance.
- **Post and interface.** A full-screen `ColorRect` on a `CanvasLayer` pulls the edges toward
  `house` in linear light (`vignette.gdshader`). The slip is a `Control` on the layer above: torn
  paper (mulberry32, seed 5, the page's clip-path), the hard card drop, an erf box shadow for the
  CSS blur, the tack, glyphs rasterised from the page's own SVG symbols with
  `Image.load_svg_from_string()`, live text and printed pips, laid out with the page's CSS box
  model. The placard is painted once into a 640×180 `SubViewport` (seed 9), linearised, and used
  as the placard quad's texture with emission 0.35. Slips are placed from the camera with
  `Camera3D.unproject_position()`.
- **Fonts.** The page asks for Iowan Old Style, then Palatino Linotype; the port uses a
  `SystemFont` with the same list. To ship, bundle a licensed copy or use TeX Gyre Pagella (free,
  the same design). Small caps and old-style figures are the font's `smcp` and `onum` features via
  `FontVariation.opentype_features`. Chrome lays out lines with the font's OS/2 win metrics, not
  the hhea ascent Godot reports, so `slip.gd` places baselines from the win values.

## Project and import settings

- Renderer `gl_compatibility`, viewport 1280×720, `anti_aliasing/quality/msaa_3d = 2` (4×, like
  the page's multisampled target), `textures/default_filters/anisotropic_filtering_level = 3` (8×).
- Every image: Lossless, `process/fix_alpha_border = false` (keeps the cream the keyed pixels
  carry, so alpha-tested edges filter as in the page), premultiply off, no VRAM compression. The
  importer's mipmaps are not used: `linearize()` rebuilds them.
- Environment: background `house`, ambient black, reflections off, linear tonemap.

## Compatibility traps found here

In addition to the earlier ports' list (ambient with a shadowed light, sky and vertex-colour
spaces, writing ALPHA):

1. **The base pass works in sRGB, untouched.** A `source_color` texture arrives in `fragment()`
   undecoded, and `ALBEDO` (unshaded) or `EMISSION` reaches the screen unencoded: an emission of
   0.214 shows as 54/255, not 128. Forward+ decodes and encodes both. Decode and encode yourself
   under `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY`.
2. **Each shadowed spot or omni light is an additive pass that adds sRGB-encoded light.** Two
   lights of 0.107 make 184/255 instead of 127, and the raw base pass plus a light pass mixes two
   spaces. No per-pass correction works with two shadowed lights: render the shadow maps yourself
   and light everything in one pass.
3. **`spot_angle_attenuation` sharpens toward the centre.** Large values give a hot spot, not a
   flat cone. (Moot once the lighting is in the shader.)
4. **Godot averages mipmaps in sRGB** (the importer and `Image.generate_mipmaps()` on 8-bit
   images), so hatched prints darken as they shrink, in both renderers. Mipmap half-float linear
   images instead.
5. **An HDR 2D `SubViewport` in Compatibility still samples textures undecoded**, where Forward+
   decodes them; `linearize.gdshader` decodes only under Compatibility.
6. **Dark tones lose a level or two** (`house` #241A1E lands at 34, 23, 28): the 3D image passes
   through an 8-bit linear buffer, whatever the HDR 2D and MSAA settings. Codes from 124 up come
   through exactly, which is why the shadow maps store depth as three 6-bit digits in codes
   176–239.
7. **`draw_colored_polygon()` fails on an outline that crosses itself**, which a jittered torn
   edge does at its corners; a canvas fill doesn't mind. Union it with an inner rectangle first.

## The code

`main.tscn` is one `Node3D` with `main.gd`; the images sit in `res://img/` under the page's names.
The slip's lines, the placard's title and the stand positions are the example key scene's.

`stage.gdshaderinc`

```glsl
// Shared by paper.gdshader (the lit prints) and depth.gdshader (the shadow-map casters).

uniform sampler2D tex : filter_linear_mipmap_anisotropic, repeat_disable;   // linear half-float, see main.gd linearize()
uniform bool use_tex = true;
uniform bool alpha_test = true;          // three's alphaTest 0.5
uniform vec2 uv_repeat = vec2(1.0);      // three texture.repeat / offset (v measured from the bottom)
uniform vec2 uv_offset = vec2(0.0);
uniform ivec2 wrap = ivec2(0);           // per axis: 0 clamp, 1 repeat, 2 mirrored repeat
uniform bool flip_u = false;             // a mirrored cut-out (three: group.scale.x = -1)

// Shadow maps hold three.js's perspective depth (near 3, far 45) packed into three 6-bit digits,
// stored as byte codes 176..239: codes that survive Compatibility's 8-bit colour path unchanged.
const float SHADOW_NEAR = 3.0;
const float SHADOW_FAR = 45.0;

vec3 to_lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

float wrap1(float c, int mode) {
	if (mode == 1) return fract(c);
	if (mode == 2) { float f = mod(c, 2.0); return f > 1.0 ? 2.0 - f : f; }
	return clamp(c, 0.0, 1.0);
}

// The print at this fragment, three.js-style uv transform and wrapping; mip level from the
// unwrapped coordinates so seams don't pick the smallest mip.
vec4 print_sample(vec2 uv_godot) {
	if (!use_tex) return vec4(1.0);
	vec2 uv = vec2(uv_godot.x, 1.0 - uv_godot.y);
	if (flip_u) uv.x = 1.0 - uv.x;
	uv = uv * uv_repeat + uv_offset;
	vec2 g = vec2(wrap1(uv.x, wrap.x), wrap1(uv.y, wrap.y));
	vec2 duv = uv * vec2(1.0, -1.0);
	return textureGrad(tex, vec2(g.x, 1.0 - g.y), dFdx(duv), dFdy(duv));
}

vec3 pack_depth(float d) {
	float v = min(floor(clamp(d, 0.0, 1.0) * 262144.0), 262143.0);
	float c0 = floor(v / 4096.0);
	float r = v - c0 * 4096.0;
	float c1 = floor(r / 64.0);
	return (vec3(c0, c1, r - c1 * 64.0) + 176.0) / 255.0;
}
float unpack_depth(vec3 c) {
	vec3 k = floor(c * 255.0 + 0.5) - 176.0;
	return ((k.x * 64.0 + k.y) * 64.0 + k.z) / 262144.0;
}
// gl_FragCoord.z of the shadow camera for a view-space z (negative in front)
float shadow_depth(float z_view) {
	float n = SHADOW_NEAR, f = SHADOW_FAR;
	return 0.5 * ((f + n) / (f - n) + 2.0 * f * n / ((f - n) * z_view)) + 0.5;
}
```

`paper.gdshader`

```glsl
// Printed paper under the stage's lighting plot, computed the way three.js's MeshStandardMaterial
// does it: Lambert + GGX for each spot (smoothstep cone, no distance falloff), a hemisphere fill,
// and PCF-soft shadows read from the two shadow maps the stage renders itself (key and foot).
// Everything happens in one unshaded pass, so Compatibility and Forward+ agree.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;
#include "res://stage.gdshaderinc"

uniform bool card_back = false;          // the card edge: only the print's alpha, in base_linear
uniform vec3 base_linear = vec3(1.0);    // colour multiplier (linear)
uniform float roughness = 0.92;
uniform float metalness = 0.0;
uniform float emissive = 0.0;            // emissive map = the print, x this (the placard: 0.35)
uniform bool receive_shadow = true;

// the lighting plot: linear colour x intensity; positions and spot axes (position - target) in world space
uniform vec3 hemi_sky = vec3(0.0);
uniform vec3 hemi_ground = vec3(0.0);
uniform vec3 fill_pos; uniform vec3 fill_axis; uniform vec2 fill_cos; uniform vec3 fill_col;
uniform vec3 key_pos;  uniform vec3 key_axis;  uniform vec2 key_cos;  uniform vec3 key_col;
uniform vec3 foot_pos; uniform vec3 foot_axis; uniform vec2 foot_cos; uniform vec3 foot_col;
// shadows: world -> [0,1] shadow-map coordinates (three's light.shadow.matrix) and the maps
uniform mat4 key_shadow_matrix;
uniform mat4 foot_shadow_matrix;
uniform sampler2D key_shadow_map : filter_nearest, repeat_disable;
uniform sampler2D foot_shadow_map : filter_nearest, repeat_disable;
uniform float shadow_map_size = 2048.0;
uniform float shadow_bias = -0.0006;
uniform float shadow_normal_bias = 0.02;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec3 F_Schlick(vec3 f0, float f90, float dotVH) {
	float fr = exp2((-5.55473 * dotVH - 6.98316) * dotVH);
	return f0 * (1.0 - fr) + f90 * fr;
}
vec3 brdf_ggx(vec3 L, vec3 V, vec3 N, vec3 f0, float rough) {
	float a = rough * rough; float a2 = a * a;
	vec3 H = normalize(L + V);
	float nl = clamp(dot(N, L), 0.0, 1.0);
	float nv = clamp(dot(N, V), 0.0, 1.0);
	float nh = clamp(dot(N, H), 0.0, 1.0);
	float vh = clamp(dot(V, H), 0.0, 1.0);
	float gv = nl * sqrt(a2 + (1.0 - a2) * nv * nv);
	float gl = nv * sqrt(a2 + (1.0 - a2) * nl * nl);
	float vis = 0.5 / max(gv + gl, 1e-6);
	float dn = nh * nh * (a2 - 1.0) + 1.0;
	return F_Schlick(f0, 1.0, vh) * vis * a2 / (PI * dn * dn);
}
// one three.js SpotLight with decay 0 and distance 0, in world space
vec3 spot(vec3 pos, vec3 axis, vec2 cs, vec3 col, vec3 P, vec3 N, vec3 V, vec3 diff, vec3 f0, float rough) {
	vec3 L = normalize(pos - P);
	float sa = smoothstep(cs.x, cs.y, dot(L, axis));
	float nl = clamp(dot(N, L), 0.0, 1.0);
	return col * sa * nl * (diff / PI + brdf_ggx(L, V, N, f0, rough));
}

// three.js PCFSoftShadowMap: nine bilinearly weighted depth comparisons around the texel
float cmp(sampler2D m, vec2 uv, float z) {
	return step(z, unpack_depth(texture(m, vec2(uv.x, 1.0 - uv.y)).rgb));   // map rows run top-down
}
float pcf_soft(sampler2D m, vec3 c) {
	vec2 ts = vec2(1.0 / shadow_map_size);
	float dx = ts.x;
	float dy = ts.y;
	vec2 f = fract(c.xy * shadow_map_size + 0.5);
	vec2 uv = c.xy - f * ts;
	float z = c.z;
	return (cmp(m, uv, z) + cmp(m, uv + vec2(dx, 0.0), z) + cmp(m, uv + vec2(0.0, dy), z) + cmp(m, uv + ts, z)
		+ mix(cmp(m, uv + vec2(-dx, 0.0), z), cmp(m, uv + vec2(2.0 * dx, 0.0), z), f.x)
		+ mix(cmp(m, uv + vec2(-dx, dy), z), cmp(m, uv + vec2(2.0 * dx, dy), z), f.x)
		+ mix(cmp(m, uv + vec2(0.0, -dy), z), cmp(m, uv + vec2(0.0, 2.0 * dy), z), f.y)
		+ mix(cmp(m, uv + vec2(dx, -dy), z), cmp(m, uv + vec2(dx, 2.0 * dy), z), f.y)
		+ mix(mix(cmp(m, uv + vec2(-dx, -dy), z), cmp(m, uv + vec2(2.0 * dx, -dy), z), f.x),
			mix(cmp(m, uv + vec2(-dx, 2.0 * dy), z), cmp(m, uv + vec2(2.0 * dx, 2.0 * dy), z), f.x), f.y)
		) * (1.0 / 9.0);
}
float shadow(sampler2D m, mat4 sm, vec3 P, vec3 Nw) {
	vec4 h = sm * vec4(P + Nw * shadow_normal_bias, 1.0);
	vec3 c = h.xyz / h.w;
	if (c.x < 0.0 || c.x > 1.0 || c.y < 0.0 || c.y > 1.0 || c.z > 1.0) return 1.0;
	c.z += shadow_bias;
	return pcf_soft(m, c);
}

void fragment() {
	vec4 t = print_sample(UV);
	if (alpha_test && t.a < 0.5) discard;
	vec3 albedo = card_back ? base_linear : base_linear * t.rgb;
	vec3 diff = albedo * (1.0 - metalness);
	vec3 f0 = mix(vec3(0.04), albedo, metalness);

	vec3 P = world_pos;
	vec3 N = normalize(world_normal);
	vec3 V = normalize(INV_VIEW_MATRIX[3].xyz - P);
	vec3 c = mix(hemi_ground, hemi_sky, 0.5 * N.y + 0.5) * diff / PI;
	c += spot(fill_pos, fill_axis, fill_cos, fill_col, P, N, V, diff, f0, roughness);
	float sk = 1.0;
	float sf = 1.0;
	if (receive_shadow) {
		sk = shadow(key_shadow_map, key_shadow_matrix, P, N);
		sf = shadow(foot_shadow_map, foot_shadow_matrix, P, N);
	}
	c += sk * spot(key_pos, key_axis, key_cos, key_col, P, N, V, diff, f0, roughness);
	c += sf * spot(foot_pos, foot_axis, foot_cos, foot_col, P, N, V, diff, f0, roughness);
	c += emissive * t.rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = to_srgb(c);       // ... and writes the 3D colour through without encoding it
#else
	ALBEDO = c;
#endif
}
```

`depth.gdshader`

```glsl
// A shadow caster as the light's camera sees it: alpha-tested on the print, both faces, writing
// its packed depth. Lives on render layer 2, which only the shadow cameras draw.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
#include "res://stage.gdshaderinc"

void fragment() {
	if (alpha_test && print_sample(UV).a < 0.5) discard;
	vec3 code = pack_depth(shadow_depth(VERTEX.z));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = code;            // Compatibility writes the 3D colour through as it is
#else
	ALBEDO = to_lin(code);    // Forward+ encodes linear to sRGB on the way out
#endif
}
```

`linearize.gdshader`

```glsl
// Copies a print into a half-float (HDR 2D) viewport as linear values, alpha untouched, so its
// mipmaps can be averaged in linear light like WebGL does for sRGB textures.
shader_type canvas_item;
render_mode blend_disabled, unshaded;
vec3 to_lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c.rgb = to_lin(c.rgb);   // Compatibility samples the print undecoded even in an HDR 2D viewport
#endif
	COLOR = c;               // Forward+ has already decoded it (HDR 2D canvases work in linear)
}
```

`unlit.gdshader`

```glsl
// three's MeshBasicMaterial: the colour as authored, no light, no shadow.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
void fragment() {
	ALBEDO = color.rgb;
}
```

`vignette.gdshader`

```glsl
// Vignette toward the house colour, mixed in linear light as three's post pass does. The screen
// texture holds sRGB values (no HDR 2D), so linearise, mix, encode.
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec3 house_linear = vec3(0.0);
uniform float amount = 0.22;
vec3 to_lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
void fragment() {
	vec3 c = to_lin(texture(screen, SCREEN_UV).rgb);
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(0.35, 0.95, length(d));
	COLOR = vec4(to_srgb(mix(c, house_linear, v * amount)), 1.0);
}
```

`boxshadow.gdshader`

```glsl
// CSS drop-shadow blur of a rectangle: a Gaussian (sigma = blur radius / 2) of a box is a product
// of two erf differences, so the soft shadow under a paper slip needs no render target.
shader_type canvas_item;
uniform vec4 box = vec4(0.0, 0.0, 100.0, 100.0);   // x0, y0, x1, y1 in this rect's local pixels
uniform float sigma = 3.0;
uniform vec4 shadow : source_color = vec4(0.0, 0.0, 0.0, 0.35);
varying vec2 local;
void vertex() { local = VERTEX; }
float erf_(float x) {   // Abramowitz-Stegun 7.1.26
	float s = sign(x); x = abs(x);
	float t = 1.0 / (1.0 + 0.3275911 * x);
	float y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x);
	return s * y;
}
void fragment() {
	float k = 1.0 / (sigma * sqrt(2.0));
	float ax = 0.5 * (erf_((local.x - box.x) * k) - erf_((local.x - box.z) * k));
	float ay = 0.5 * (erf_((local.y - box.y) * k) - erf_((local.y - box.w) * k));
	COLOR = vec4(shadow.rgb, shadow.a * ax * ay);
}
```

`main.gd`

```gdscript
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
	slip.regular = pala(400, false)
	slip.bold_onum = pala(700, false, {"onum": 1})
	slip.bold_smcp = pala(700, false, {"smcp": 1})
	var lx := camera.unproject_position(Vector3(-3.9 - 0.95, 0, 5)).x
	slip.position = Vector2(roundf(lx - Slip.W * 0.5), 150)
	hud.add_child(slip)

func pala(weight: int, italic: bool, features := {}) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Palatino Linotype", "Palatino", "Book Antiqua", "TeX Gyre Pagella", "serif"])
	f.font_weight = weight
	f.font_italic = italic
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
	p.font = pala(700, true)
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
```

`slip.gd`

```gdscript
extends Control
## A paper slip pinned to the frame: torn edge, dark card edge as a hard drop, a soft shadow,
## a tack, then its lines. This one is the basket (an inventory and two meters of printed pips).
## Layout follows the demo's CSS box model at 720p: 172 wide, padding 9/12/11, 16 px text at
## line-height 1.3, 22 px glyphs, rows 26 tall.

const Rng := preload("res://mulberry32.gd")
const W := 172.0
const H := 241.0
var ink := Color("#2B2118")
var paper := Color("#F3EAD2")
var card := Color("#5A3E2B")
var tear_seed := 5

var regular: Font
var bold_onum: Font      # counts: bold, old-style figures
var bold_smcp: Font      # heading: bold small caps
var icons := {}          # name -> Texture2D, rasterised from the same SVG symbols as the page

const ITEMS := [["loaf", "Rye loaf", "2"], ["honey", "Honey", "1"], ["specs", "Spectacles", "1"],
	["oil", "Lamp oil", "½"], ["wool", "Grey wool", "1"]]
const HEART := 7    # of 10
const SUN := 3      # of 5

const SVG := {
	"loaf": '<path d="M3 15c0-6 4-9 9-9s9 3 9 9v3H3z" fill="#DDBE68" stroke="currentColor" stroke-width="1.6"/><path d="M8 9l-1 5M12 8v6M16 9l1 5" stroke="currentColor" stroke-width="1.4" fill="none"/>',
	"honey": '<path d="M6 9h12l-1 11H7z" fill="#DDBE68" stroke="currentColor" stroke-width="1.6"/><path d="M5 5h14v4H5z" fill="#C8574A" stroke="currentColor" stroke-width="1.6"/>',
	"specs": '<circle cx="7" cy="14" r="4" fill="none" stroke="currentColor" stroke-width="1.8"/><circle cx="17" cy="14" r="4" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M11 14h2M3 13l-1-4M21 13l1-4" stroke="currentColor" stroke-width="1.6" fill="none"/>',
	"oil": '<path d="M9 3h6v4l3 3v11H6V10l3-3z" fill="#A9B2B8" stroke="currentColor" stroke-width="1.6"/><path d="M6 15h12v6H6z" fill="#B08355" stroke="currentColor" stroke-width="1.6"/>',
	"wool": '<circle cx="12" cy="12" r="8" fill="#9A968F" stroke="currentColor" stroke-width="1.6"/><path d="M6 8c4 2 8 6 9 11M9 5c3 3 8 5 10 10M5 14c3 0 6 3 7 6" stroke="currentColor" stroke-width="1.2" fill="none"/>',
	"heart": '<path d="M12 21C5 15 2 12 2 8a5 5 0 0 1 10-1 5 5 0 0 1 10 1c0 4-3 7-10 13z" fill="#C8574A" stroke="currentColor" stroke-width="1.6"/>',
	"sun": '<circle cx="12" cy="12" r="5" fill="#DDBE68" stroke="currentColor" stroke-width="1.6"/><path d="M12 1v4M12 19v4M1 12h4M19 12h4M4 4l3 3M17 17l3 3M20 4l-3 3M7 17l-3 3" stroke="currentColor" stroke-width="1.6"/>',
}

var outline := PackedVector2Array()

func _ready() -> void:
	size = Vector2(W, H)
	for k in SVG:
		var src: String = '<svg width="24" height="24" viewBox="0 0 24 24">%s</svg>' % SVG[k].replace("currentColor", "#" + ink.to_html(false))
		var img := Image.new()
		img.load_svg_from_string(src, 22.0 / 24.0)
		icons[k] = ImageTexture.create_from_image(img)
	# the torn edge: the CSS clip-path polygon, jitter 0..2.4 px rounded to 0.1, every 12 px
	var r := Rng.new(tear_seed)
	var j := func() -> float: return snappedf(r.next() * 2.4, 0.1)
	var x := 0.0
	while x < W: outline.append(Vector2(x, j.call())); x += 12.0
	var y := 0.0
	while y < H: outline.append(Vector2(W - j.call(), y)); y += 12.0
	x = W
	while x > 0.0: outline.append(Vector2(x, H - j.call())); x -= 12.0
	y = H
	while y > 0.0: outline.append(Vector2(j.call(), y)); y -= 12.0
	# the soft shadow (drop-shadow 5px 8px 6px, 35% black) of the slip plus its 2,3 card drop
	var sh := ColorRect.new()
	sh.position = Vector2(-20, -20); sh.size = Vector2(W + 50, H + 55)
	sh.show_behind_parent = true
	var m := ShaderMaterial.new(); m.shader = preload("res://boxshadow.gdshader")
	m.set_shader_parameter("box", Vector4(5 + 20, 8 + 20, W + 2 + 5 + 20, H + 3 + 8 + 20))
	m.set_shader_parameter("sigma", 3.0)
	sh.material = m
	add_child(sh)
	queue_redraw()

## CSS line box: half-leading above the ascent. Chrome on Windows takes ascent and descent from
## the font's OS/2 win metrics (Palatino Linotype: 2150 and 613 per 2048 em); Godot's own
## get_ascent() uses the smaller hhea values and would set every line about 3 px high.
const WIN_ASCENT := 2150.0 / 2048.0
const WIN_DESCENT := 613.0 / 2048.0
func _baseline(_f: Font, px: int, top: float, line_h: float) -> float:
	var a := WIN_ASCENT * px; var d := WIN_DESCENT * px
	return top + (line_h - (a + d)) * 0.5 + a

func _draw() -> void:
	var tack := Vector2(86, 4)
	# hard card-coloured drop of the whole pinned slip, tack included
	for poly in _solid(_moved(outline, Vector2(2, 3))): draw_colored_polygon(poly, card)
	draw_circle(tack + Vector2(2, 3), 8.0, card, true, -1.0, true)
	# the paper
	for poly in _solid(outline):
		draw_colored_polygon(poly, paper)
		poly.append(poly[0])
		draw_polyline(poly, paper, 1.0, true)
	# heading
	draw_string(bold_smcp, Vector2(12, _baseline(bold_smcp, 20, 9, 22)), "Basket", HORIZONTAL_ALIGNMENT_CENTER, 148, 20, ink)
	# inventory rows
	for i in ITEMS.size():
		var top := 37.0 + 26.0 * i + 2.0
		draw_texture(icons[ITEMS[i][0]], Vector2(12, top))
		draw_string(regular, Vector2(42, _baseline(regular, 16, top + 0.6, 20.8)), ITEMS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
		draw_string(bold_onum, Vector2(12, _baseline(bold_onum, 16, top + 0.6, 20.8)), ITEMS[i][2], HORIZONTAL_ALIGNMENT_RIGHT, 148, 16, ink)
	# rule
	draw_rect(Rect2(12, 174, 148, 1), ink)
	# meters: courage as bars, daylight as suns
	draw_texture(icons["heart"], Vector2(12, 182))
	for i in 10:
		var rc := Rect2(41 + 12 * i, 185, 9, 16)
		draw_rect(rc, ink)
		if i >= HEART: draw_rect(rc.grow(-1), paper)
	draw_texture(icons["sun"], Vector2(12, 208))
	for i in 5:
		var c := Vector2(41 + 18 * i + 7.5, 208 + 11)
		draw_circle(c, 7.5, ink, true, -1.0, true)
		draw_circle(c, 6.5, Color("#DDBE68") if i < SUN else paper, true, -1.0, true)
	# tack
	draw_circle(tack, 8.0, ink, true, -1.0, true)
	draw_circle(tack, 6.0, card, true, -1.0, true)

func _moved(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var o := PackedVector2Array()
	for v in p: o.append(v + d)
	return o

## The jittered outline can cross itself at a corner; a canvas fill shrugs that off, Godot's
## triangulator does not. Union it with a rectangle well inside to get a clean outline.
func _solid(p: PackedVector2Array) -> Array:
	var r := Rect2(p[0], Vector2.ZERO)
	for v in p: r = r.expand(v)
	r = r.grow(-8.0)
	var inner := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var out := []
	for poly in Geometry2D.merge_polygons(p, inner):
		if not Geometry2D.is_polygon_clockwise(poly): out.append(poly)
	return out
```

`placard.gd`

```gdscript
extends Node2D
## The flown title placard, painted once into a 640x180 SubViewport: card back, torn paper,
## double ruled frame and the scene's name in italic bold. The image becomes the placard's texture.

const Rng := preload("res://mulberry32.gd")
var title := "The Birch Wood"
var paper := Color("#F3EAD2")
var card := Color("#5A3E2B")
var ink := Color("#2B2118")
var font: Font

func _draw() -> void:
	draw_rect(Rect2(6, 10, 628, 164), card)
	var r := Rng.new(9)
	var pts := PackedVector2Array()
	for x in range(0, 621, 20): pts.append(Vector2(x, r.next() * 5.0))
	for y in range(0, 161, 20): pts.append(Vector2(620.0 - r.next() * 5.0, y))
	for x in range(620, -1, -20): pts.append(Vector2(x, 160.0 - r.next() * 5.0))
	for y in range(160, -1, -20): pts.append(Vector2(r.next() * 5.0, y))
	# the jittered outline crosses itself at the corners: let Clipper resolve it, as a canvas fill does
	for poly in _solid(pts):
		draw_colored_polygon(poly, paper)
		poly.append(poly[0])
		draw_polyline(poly, paper, 1.0, true)             # antialiased cut edge
	_stroke_rect(Rect2(22, 20, 576, 120), 3.0)
	_stroke_rect(Rect2(30, 28, 560, 104), 1.2)
	# canvas textAlign center, textBaseline middle at (310, 84)
	var size := 72
	var base := 84.0 + (font.get_ascent(size) - font.get_descent(size)) * 0.5
	draw_string(font, Vector2(310 - 400, base), title, HORIZONTAL_ALIGNMENT_CENTER, 800, size, ink)

func _stroke_rect(r: Rect2, w: float) -> void:
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	draw_polyline(p, ink, w, true)

## The jittered outline can cross itself at a corner; a canvas fill shrugs that off, Godot's
## triangulator does not. Union it with a rectangle well inside to get a clean outline.
func _solid(p: PackedVector2Array) -> Array:
	var r := Rect2(p[0], Vector2.ZERO)
	for v in p: r = r.expand(v)
	r = r.grow(-8.0)
	var inner := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var out := []
	for poly in Geometry2D.merge_polygons(p, inner):
		if not Geometry2D.is_polygon_clockwise(poly): out.append(poly)
	return out
```

`mulberry32.gd`

```gdscript
extends RefCounted
## mulberry32, bit for bit as the web demo's: the same seed tears the same paper edges.

var _a := 0

func _init(seed: int) -> void:
	_a = seed & 0xFFFFFFFF

static func _imul(x: int, y: int) -> int:
	return ((x & 0xFFFF) * y + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF

func next() -> float:
	_a = (_a + 0x6D2B79F5) & 0xFFFFFFFF
	var t := _imul(_a ^ (_a >> 15), 1 | _a)
	t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
```
