# Godot 4 port

**Test-rendered** in Godot 4.7.1 (Compatibility). `frames/godot-key-scene.*` rebuilds
`demo.html?frame=key-scene`. Against the web frame: mean difference 3.4 / 2.8 / 2.9 per 255 (R, G,
B); 1.2% of pixels differ by more than 24, and nearly all of those are caption glyph edges.
Composition, camera, cast, props, signs, awnings, bunting, town, valley, sky, shadows, tilt-shift,
grade and the three captions sit where the web frame has them. What still differs, and why:

- **Caption text** (the worst tiles, about 19/255 averaged over a tile). Both draw the same bundled
  Alegreya files, but FreeType draws the glyphs thinner than Chrome's DirectWrite and a little
  differently. The boxes, line breaks and positions match. The names are emboldened by 0.2 and the
  text moved up 1 px to close most of the gap.
- **1 px edges** on tile grout, box edges and sprite outlines: different multisample patterns.

<!-- matched-web-frame: 0beb17ff9b07 -->

> **The `assets/` paths below load this entry's example art**, which is how the port was tested against the web demo. A game never ships it: load the game's own models, sprites and textures, made the same way, in their place.

The whole project that rendered the frame, including the code that rebuilds the web demo exactly, is
in this entry's `godot-port/` on the catalog site. This file keeps what a game needs to draw the look.

**Forward+** renders the same frame with mean 5.2 / 4.7 / 4.2 against the web frame. Surfaces that
wear the grey value maps come out about 10 levels brighter there, probably because the
single-channel PNGs aren't sRGB-decoded the same way. If you ship on Forward+, save the maps as RGB.
All the shader code below runs unchanged in both renderers, with `#if CURRENT_RENDERER` where they
differ.

**Not covered by this test.** Bloom: the web's UnrealBloom (threshold 0.88 linear) finds nothing
above threshold in the day key scene, so there is no bloom pass here. A night scheme with lit lamp
cores needs Environment glow and the lamp's `OmniLight3D`, and neither has been tested in Godot.
Palette switching and the close-up camera aren't ported either.

## Project and import settings

- Renderer **Compatibility**, viewport 1280 × 720, `anti_aliasing/quality/msaa_3d = 4×`
  (the web renders into a 4× multisampled target), directional shadow atlas 4096,
  `soft_shadow_filter_quality = 3`.
- **Sprites and signs** (pixel-art PNGs): import with `compress/mode = Lossless`,
  `mipmaps/generate = false`, and **`detect_3d/compress_to = Disabled`**. With the default, Godot
  switches a texture to VRAM compression the first time it sees it used in 3D, which smears pixel
  art. The shaders sample them `filter_nearest`.
- **Value maps** (128² and 256² grey maps): `Lossless`, `mipmaps/generate = false`,
  `detect_3d/compress_to = Disabled`, sampled `filter_nearest, repeat_enable`: point-sampled at
  every distance, so a surface keeps hard steps between its four values, as three.js'
  `NearestFilter` for both filters with `generateMipmaps = false` does.
- **Textures drawn in code** (the brushy grain, the painted sky) are `Image`s built at start-up and
  turned into `ImageTexture`s with mipmaps. The port's `sky_image()` repeats the demo's canvas
  painting step by step (gradient, halo round the key, 70 cloud strokes, two hill layers, fog below
  the horizon); a game paints its own backdrop to recipe.md's numbers, in code or with an image
  model, and passes it to `backdrop.gdshader` the same way.
- **Font:** the demo bundles Alegreya (OFL) in `assets/fonts/`: a variable upright file (weights
  400–700) and an italic. The port loads the same `.woff` files from `res://fonts/` as `FontFile`s.
  Names are weight 600 (`variation_opentype`) with OpenType small caps (`smcp`) and 1 px letter
  spacing; the description line is the italic.

## Putting it together

One script on a `Node3D` builds the scene in code:

```
Node3D (main.gd)
├─ world: Node3D            the set: boxes and primitives with toon materials, contact blobs,
│                           sprite quads for the cast, the additive selection ring
├─ valley: MeshInstance3D   PlaneMesh 320 × 180, 200 × 110 segments, valley.gdshader
├─ backdrop                 open cylinder arc (radius ≥ 10× the set, 2.5 rad), backdrop.gdshader
├─ shafts, mist             planes with shaft.gdshader and mist.gdshader, behind the set
├─ DirectionalLight3D       the key: shadowed, orthogonal, max distance 40
├─ WorldEnvironment         background = fog, ambient black, reflections off, tonemap Linear, fog off
├─ Camera3D                 fov 46°, near 0.3, far 600, pitched 18–22° down
├─ CanvasLayer 1 (post)     ColorRect tilt (h) → BackBufferCopy → ColorRect tilt (v)
│                           → BackBufferCopy → ColorRect grade
└─ CanvasLayer 2            a Control that draws the captions above the post, so they stay sharp
```

Which material goes where:

- **Set pieces:** `toon.gdshader` (via `paint()`, `M()` for grain, `MT()` for a tiling value map).
  `toon_double.gdshader` for thin two-sided pieces (cloth, flags); `toon_cutout.gdshader` for
  pixel-art boards with transparent edges. Thin flags with no UVs set `grain_corner = true`.
- **The cast:** `sprite.gdshader` on a quad turned to the camera on Y only, mirrored with
  `scale.x = -1` when facing left, standing on a `blob.gdshader` contact disc.
- **Lamp cores and lines:** `unlit.gdshader`; an unlit lamp core is drawn at
  `srgb(lin(col("glow-lamp")) * 0.8)`.
- **The selection ring:** `additive.gdshader` on a flat ring, inner radius 0.5, outer 0.64, 48
  segments, 0.02 above the floor (the port clones three.js' `RingGeometry`; any flat ring mesh works).
- **Atmosphere:** `valley.gdshader`, `backdrop.gdshader`, `shaft.gdshader`, `mist.gdshader`.
- The rim light, the hemisphere fill and the fog are not nodes: the toon shader's `light()` adds
  them for the key (see the traps).

The port builds every box and cylinder the way three.js does, so the toon bands and the world-unit
texel grid land where the web frame has them. A game needs the same thing for a different reason:
Godot's `BoxMesh` lays its UVs out as an atlas, which breaks per-face grain and world-unit UVs, so
use `box_geo()` + `world_uv()` below (or your own meshes with per-face UVs). The port also clones
three.js' `IcosahedronGeometry` for foliage and goods; a game can use a flat-shaded icosahedron
(an icosphere with no subdivision) from any modelling tool.

## Compatibility traps (4.7.1)

From `godot-compatibility.md` (copied beside this file): **3, 8, 9** as every 3D entry, and as they show here:

1. **Unshaded spatial shaders run in sRGB** (trap 1): lighting the valley, mixing fog and tinting
   sprites happen in the wrong space, and a 45% dark blob comes out much darker. Fix:
   `space.gdshaderinc` (`in_linear()`, `out_albedo()`), plus `out_alpha()` for dark overlays:
   `1 - (1 - a)^(1/2.2)` blends in sRGB about as dark as `a` does in linear.
2. **Additive light** (trap 11): the shafts mix toward white at 2.56 × their opacity in
   Compatibility (`shaft.gdshader`) and add in Forward+; the accent ring is scaled by 0.7.
3. **Neutral Environment adjustments or glow don't help.** They don't switch Compatibility to a
   linear 3D buffer for these cases.

Engine-independent points:

- **three.js' shadow camera is a ±13 m box** around the key target; outside it nothing is shadowed.
  Godot's directional shadow reaches as far as `max_distance` from the camera. The toon shader masks
  the shadow to the same box, using the world position against the shadow camera's axes
  (`shadow_half`); set it to cover your set plus 30%.
- **Caption text:** the port sizes captions like CSS (shrink to the unwrapped text width, capped at
  240 px) and nudges FreeType toward Chrome (`EMBOLDEN`, `BASELINE_SHIFT`). Glyph rasterisation
  can't be matched exactly; expect about 19/255 on text pixels against the web.

## Shaders

`fog.gdshaderinc`, three.js `FogExp2` on view depth:

```glsl
// three.js FogExp2 on view depth, mixed in linear light. Environment fog stays off: in Compatibility
// it is applied in every light pass. Read in fragment(), so a source_color uniform (set as an sRGB Color).
uniform vec4 fog_color : source_color = vec4(0.79, 0.86, 0.9, 1.0);
uniform float fog_density = 0.0085;
float fog_factor(float depth) { float d = fog_density * depth; return 1.0 - exp(-d * d); }
```

`space.gdshaderinc`, linear maths in unshaded shaders on both renderers:

```glsl
// Compatibility (tested in 4.7.1) runs an UNSHADED spatial shader in sRGB: source_color uniforms and
// textures arrive un-linearised, ALBEDO goes to the screen as it is, and blending happens on sRGB
// values. Forward+ runs the same shader in linear. These helpers make the maths linear in both.
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
vec3 in_linear(vec3 c) {   // a source_color input, as linear
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return to_linear(c);
#else
	return c;
#endif
}
vec3 out_albedo(vec3 c) {  // a linear result, as ALBEDO
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return to_srgb(max(c, vec3(0.0)));
#else
	return c;
#endif
}
float out_alpha(float a) { // blending a dark colour over the scene: the sRGB-space alpha that darkens like a linear one
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return 1.0 - pow(1.0 - a, 1.0 / 2.2);
#else
	return a;
#endif
}
vec3 out_added(vec3 c) {   // a linear amount ADDED to the scene: in sRGB, scale by the curve's slope at mid-tones
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c * 0.7;
#else
	return c;
#endif
}
```

`toon.gdshaderinc`, the set's paint: role colour × map, a 4-step ramp for key and rim, the hemisphere
fill, the shadow box and fog. The three variants are `toon.gdshader` (`render_mode
specular_disabled;`), `toon_double.gdshader` (adds `cull_disabled`, for awnings and flags) and
`toon_cutout.gdshader` (adds `#define CUTOUT` before the include, for the sign boards):

```glsl
// Toon paint (three.js MeshToonMaterial with a 4-step gradient map) plus the hemisphere fill, the rim
// light and fog, all written in light() for the one shadowed key light. The Environment's ambient is
// black, so Forward+ and Compatibility agree. Colours read in light() are plain vec3 uniforms set from a
// Vector3 of linear values; colours read in fragment() are source_color uniforms set from an sRGB Color.
#include "res://shaders/fog.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);   // read in fragment(): source_color
uniform int map_kind = 0;   // 0 brushy grain (UV 0-1 per face), 1 value map (world UVs, tiling), 2 pixel art
uniform sampler2D grain_map : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D value_map : source_color, filter_nearest, repeat_enable;
uniform sampler2D pixel_map : source_color, filter_nearest_mipmap, repeat_disable;
uniform bool grain_corner = false;   // flags: three.js draws them without UVs, so every pixel reads one texel

uniform vec3 fog_linear = vec3(0.58, 0.72, 0.79);   // fog colour again, linear, for light()
uniform vec3 key_linear = vec3(1.0);     // key colour x intensity / PI
uniform vec3 rim_linear = vec3(0.0);     // rim colour x intensity / PI
uniform vec3 rim_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sky_linear = vec3(0.5);     // hemisphere: fill-sky x intensity / PI
uniform vec3 ground_linear = vec3(0.2);  // hemisphere: fill-ground x intensity / PI
// three.js' shadow camera is an ortho box (+-13 m around the key target); outside it nothing is shadowed.
uniform vec3 shadow_center = vec3(0.0, 0.0, -1.0);
uniform vec3 shadow_x = vec3(1.0, 0.0, 0.0);
uniform vec3 shadow_y = vec3(0.0, 1.0, 0.0);
uniform float shadow_half = 13.0;

varying vec3 up_view;
varying vec3 rim_view;
varying vec3 world_pos;
varying float view_depth;

void vertex() {
	up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	rim_view = (VIEW_MATRIX * vec4(rim_dir, 0.0)).xyz;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec4 t;
	if (map_kind == 1) t = texture(value_map, UV);
	else if (map_kind == 2) t = texture(pixel_map, UV);
	else if (grain_corner) t = textureLod(grain_map, vec2(0.0, 1.0), 0.0);
	else t = texture(grain_map, UV);
#ifdef CUTOUT
	if (t.a < 0.5) discard;   // alphaTest 0.5: discard keeps the material in the opaque pass
#endif
	ALBEDO = albedo.rgb * t.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

// the gradient map: 4 texels (70, 140, 205, 255), point-sampled at N.L * 0.5 + 0.5
float ramp(float ndl) {
	float i = clamp(floor((ndl * 0.5 + 0.5) * 4.0), 0.0, 3.0);
	return i < 0.5 ? 70.0 / 255.0 : (i < 1.5 ? 140.0 / 255.0 : (i < 2.5 ? 205.0 / 255.0 : 1.0));
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 rel = world_pos - shadow_center;
		bool in_box = abs(dot(rel, shadow_x)) <= shadow_half && abs(dot(rel, shadow_y)) <= shadow_half;
		float shadow = in_box ? ATTENUATION : 1.0;
		vec3 c = key_linear * ramp(dot(NORMAL, LIGHT)) * shadow;
		c += rim_linear * ramp(dot(NORMAL, normalize(rim_view)));
		c += mix(ground_linear, sky_linear, 0.5 * dot(NORMAL, normalize(up_view)) + 0.5);
		DIFFUSE_LIGHT += mix(c, fog_linear / max(ALBEDO, vec3(1e-4)), fog_factor(view_depth));
	}
}
```

`sprite.gdshader`, a pixel sprite lit by tint:

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// A pixel sprite lit by tint: nearest texels, no mipmaps, alpha cut at 0.5, fogged like the set.
#include "res://shaders/fog.gdshaderinc"
#include "res://shaders/space.gdshaderinc"
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
varying float view_depth;
void vertex() { view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.5) discard;   // alphaTest 0.5: discard keeps the sprite in the opaque pass
	vec3 c = in_linear(t.rgb) * in_linear(tint.rgb);
	ALBEDO = out_albedo(mix(c, in_linear(fog_color.rgb), fog_factor(view_depth)));
}
```

`blob.gdshader`, `unlit.gdshader` (lamp cores, lines), `additive.gdshader` (the selection
ring), `shaft.gdshader`, `mist.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Contact blob: outline colour at 45%, alpha 1 inside 15% of the radius falling to 0 at the edge.
#include "res://shaders/fog.gdshaderinc"
#include "res://shaders/space.gdshaderinc"
uniform vec4 color : source_color = vec4(1.0);
uniform float opacity = 0.45;
varying float view_depth;
void vertex() { view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	ALBEDO = out_albedo(mix(in_linear(color.rgb), in_linear(fog_color.rgb), fog_factor(view_depth)));
	ALPHA = out_alpha(opacity * clamp(1.0 - (d - 0.15) / 0.85, 0.0, 1.0));
}
```

```glsl
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;
// Lamp cores and bunting lines: a flat colour, fogged.
#include "res://shaders/fog.gdshaderinc"
#include "res://shaders/space.gdshaderinc"
uniform vec4 color : source_color = vec4(1.0);
varying float view_depth;
void vertex() { view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() { ALBEDO = out_albedo(mix(in_linear(color.rgb), in_linear(fog_color.rgb), fog_factor(view_depth))); }
```

```glsl
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The selection ring: accent added over the floor, fogged. Added on sRGB values in Compatibility,
// on linear ones in Forward+ (the web adds in linear).
#include "res://shaders/fog.gdshaderinc"
#include "res://shaders/space.gdshaderinc"
uniform vec4 color : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform bool use_fog = true;
varying float view_depth;
void vertex() { view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	vec3 c = in_linear(color.rgb);
	if (use_fog) c = mix(c, in_linear(fog_color.rgb), fog_factor(view_depth));
	ALBEDO = out_added(c * opacity);
}
```

```glsl
shader_type spatial;
// Light shafts: the key colour added at 2.5% (no fog). Forward+ adds it in linear, like the web.
// Compatibility blends on sRGB values and drops small additive amounts, so there the same lift is
// a mix toward white with alpha 2.56 x opacity (matched on the sky behind the shafts).
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#else
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#endif
uniform vec4 color : source_color = vec4(1.0);
uniform float opacity = 0.025;
void fragment() {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = vec3(1.0);
	ALPHA = opacity * 2.56;
#else
	ALBEDO = color.rgb * opacity;
#endif
}
```

```glsl
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Drifting mist: a screen-facing soft disc in the fog colour at 5% (a three.js Sprite).
uniform vec4 color : source_color = vec4(1.0);
uniform float opacity = 0.05;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	ALBEDO = color.rgb;
	ALPHA = opacity * clamp(1.0 - d, 0.0, 1.0);
}
```

`valley.gdshader`, the animated banded surface, and `backdrop.gdshader`, the painted sky:

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// The animated banded ground surface: wind waves in vertex(), flat facet normals from derivatives,
// N.L floored to 4 bands, brush streaks, pale crests, fog on distance. Colours are source_color
// uniforms (key and fill already scaled by intensity / PI, then encoded to sRGB), mixed in linear.
#include "res://shaders/space.gdshaderinc"
uniform float time = 2.0;
uniform vec4 base_color : source_color;
uniform vec4 crest_color : source_color;
uniform vec3 key_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 key_color : source_color;    // key x intensity / PI
uniform vec4 fill_color : source_color;   // fill-sky x hemisphere intensity / PI
uniform vec4 fog_color : source_color;
uniform float density = 0.0085;
varying vec3 w_pos;
varying float w_h;
float hgt(vec2 p, float t) {
	return 0.9 * sin(p.x * 0.11 + t * 0.6) + 0.6 * sin(p.y * 0.17 - t * 0.45 + p.x * 0.04)
		+ 0.25 * sin((p.x + p.y) * 0.37 + t * 1.1);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = hgt(w.xz, time);
	VERTEX.y += h;
	w_h = h;
	w_pos = w + vec3(0.0, h, 0.0);
}
void fragment() {
	vec3 n = normalize(cross(dFdx(w_pos), dFdy(w_pos)));
	if (n.y < 0.0) n = -n;
	float l = floor(max(dot(n, normalize(key_dir)), 0.0) * 4.0) / 4.0;
	vec3 col = in_linear(base_color.rgb) * (in_linear(fill_color.rgb) + in_linear(key_color.rgb) * l);
	col *= 0.9 + 0.1 * hash(floor(w_pos.xz * vec2(0.8, 3.0)));
	col = mix(col, in_linear(crest_color.rgb), smoothstep(1.1, 1.6, w_h) * 0.5);
	float d = length(w_pos - CAMERA_POSITION_WORLD);
	ALBEDO = out_albedo(mix(col, in_linear(fog_color.rgb), 1.0 - exp(-density * density * d * d)));
}
```

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// The painted sky on a far open cylinder: no light, no fog.
uniform sampler2D sky : source_color, filter_linear_mipmap, repeat_disable;
void fragment() { ALBEDO = texture(sky, UV).rgb; }
```

`tilt.gdshader` (run twice) and `grade.gdshader`, the post chain in linear light:

```glsl
shader_type canvas_item;
// One pass of three.js' Horizontal/VerticalTiltShiftShader (run twice, a BackBufferCopy between):
// 9 taps whose spacing grows with distance from the focus line. Blurred in linear light, as the web
// demo blurs its linear render target.
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform vec2 step_uv = vec2(0.001875, 0.0);   // 2.4 / 1280; vertical pass (0, 2.4 / 720)
uniform float focus = 0.40;                    // focus line, from the bottom
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

```glsl
shader_type canvas_item;
// The grade, in linear light: shadows lean toward the fill colour (highlights spared), vignette, grain.
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec3 tint = vec3(1.0);    // fill-ground (linear) / its largest channel
uniform float amount = 0.15;
uniform float vignette = 0.35;
uniform float grain = 0.012;
uniform float time = 0.0;
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y);   // three.js vUv: y from the bottom
	vec3 c = to_linear(texture(screen, SCREEN_UV).rgb);
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(c, c * tint, (1.0 - smoothstep(0.02, 0.35, lum)) * amount);
	vec2 d = uv - 0.5;
	c *= mix(1.0, 1.0 - smoothstep(0.25, 0.85, length(d * vec2(1.1, 1.3))), vignette);
	c += (h(floor(uv * vec2(1280.0, 720.0)) + time) - 0.5) * grain;
	COLOR = vec4(to_srgb(max(c, vec3(0.0))), 1.0);
}
```

## The scene script

Pieces of `main.gd`, verbatim. Positions, names and caption text are the game's.

Constants: the palette, the lighting scheme that belongs to it, the camera and the sprite size:

```gdscript
extends Node3D

const W := 1280.0
const H := 720.0
const T := 2.0
const P := {   # every colour role in style.md, from your palette, for example:
	"fog": "#C9DCE6", "key": "#FFF1D8", "fill-sky": "#CFE2F2", "fill-ground": "#8A7A66", "rim": "#FFFFFF",
	# ... sky, glow-*, ground, material-*, outline, tint, accent, ink, plate, white
}
## The lighting scheme belongs to the palette (demo.html's "light" block).
const L := {"key": 2.8, "key_pos": Vector3(-9, 14, 7), "hemi": 1.25, "rim": 0.4, "rim_pos": Vector3(7, 9, -12),
	"fog": 0.0085, "grade": 0.15, "vignette": 0.35, "shafts": 0.025, "mist": 0.05}
const KEY_TARGET := Vector3(0, 0, -1)
const HOME_POS := Vector3(-1.4, 6.0, 12.8)
const HOME_LOOK := Vector3(0.4, 0.2, -3.0)
# sprites: 32 x 48, feet on row 46, 1.8 m tall
const CW := 32
const CH := 48
const FEET := 46
const PX := 1.8 / CH
const TILE := {"floor": 4.0, "roof": 2.4, "plaster": 8.0, "wood": 2.0}   # world units one value map covers

var S_TOON := preload("res://shaders/toon.gdshader")
var S_TOON2 := preload("res://shaders/toon_double.gdshader")
var S_CUT := preload("res://shaders/toon_cutout.gdshader")
var S_SPRITE := preload("res://shaders/sprite.gdshader")
var S_UNLIT := preload("res://shaders/unlit.gdshader")
var S_BLOB := preload("res://shaders/blob.gdshader")
var S_ADD := preload("res://shaders/additive.gdshader")
var S_MIST := preload("res://shaders/mist.gdshader")
```

`rnd` and `Rng.new(seed)` below are a seeded random with `next()` in [0, 1). The port uses a copy of
the demo's mulberry32 so its draws match; a game can wrap Godot's `RandomNumberGenerator` (`seed`,
`randf()`).

Colour helpers and a three.js-style geometry record turned into an `ArrayMesh`:

```gdscript
class Geo:   # three.js-style geometry: CCW triangles, UV v up
	var v := []
	var n := []
	var uv := []
	var i := []

func col(role: String) -> Color: return Color(P[role])

func lin(c: Color) -> Vector3:
	var l := c.srgb_to_linear()
	return Vector3(l.r, l.g, l.b)

## three.js Color(a).lerp(Color(b), t).getHexString(): mixed in linear, stored as 8-bit sRGB
func srgb(v: Vector3) -> Color: return Color(v.x, v.y, v.z).linear_to_srgb()   # for source_color uniforms

func hex_mix(a: Color, b: Color, t: float) -> Color:
	var m := a.srgb_to_linear().lerp(b.srgb_to_linear(), t).linear_to_srgb()
	return Color8(roundi(m.r * 255), roundi(m.g * 255), roundi(m.b * 255))

func to_mesh(g: Geo, lines := false) -> ArrayMesh:
	var a := []; a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array(g.v)
	if not lines:
		a[Mesh.ARRAY_NORMAL] = PackedVector3Array(g.n)
		var uv := PackedVector2Array()
		for t in g.uv: uv.append(Vector2(t.x, 1.0 - t.y))   # three.js v runs up, Godot's down
		a[Mesh.ARRAY_TEX_UV] = uv
		var idx := PackedInt32Array()
		for k in range(0, g.i.size(), 3): idx.append_array([g.i[k], g.i[k + 2], g.i[k + 1]])   # CCW -> Godot's CW
		a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP if lines else Mesh.PRIMITIVE_TRIANGLES, a)
	return m
```

Boxes with per-face UVs (0–1 per face for grain, or world units for the value maps), planes, the
open cylinder (backdrop arcs, 4-sided roofs, trunks):

```gdscript
func _plane(g: Geo, u: int, v: int, w: int, udir: float, vdir: float, width: float, height: float, depth: float) -> void:
	var s := g.v.size()
	for iy in 2:
		for ix in 2:
			var p := Vector3(); p[u] = (ix * width - width / 2) * udir; p[v] = (iy * height - height / 2) * vdir; p[w] = depth / 2
			var nn := Vector3(); nn[w] = 1.0 if depth > 0 else -1.0
			g.v.append(p); g.n.append(nn); g.uv.append(Vector2(ix, 1 - iy))
	g.i.append_array([s, s + 2, s + 1, s + 2, s + 3, s + 1])

func box_geo(w: float, h: float, d: float) -> Geo:
	var g := Geo.new()
	_plane(g, 2, 1, 0, -1, -1, d, h, w); _plane(g, 2, 1, 0, 1, -1, d, h, -w)
	_plane(g, 0, 2, 1, 1, 1, w, d, h); _plane(g, 0, 2, 1, 1, -1, w, d, -h)
	_plane(g, 0, 1, 2, 1, -1, w, h, d); _plane(g, 0, 1, 2, -1, -1, w, h, -d)
	return g

## box UVs in world units, so every face shows the map at one texel size whatever the box's size
func world_uv(g: Geo, tile: float, o: Vector3) -> void:
	for k in g.v.size():
		var p: Vector3 = g.v[k] + o; var nn: Vector3 = g.n[k]
		if absf(nn.x) > 0.5: g.uv[k] = Vector2(p.z, p.y) / tile
		elif absf(nn.y) > 0.5: g.uv[k] = Vector2(p.x, p.z) / tile
		else: g.uv[k] = Vector2(p.x, p.y) / tile

func plane_geo(w: float, h: float, dy := 0.0) -> Geo:
	var g := Geo.new()
	for iy in 2:
		for ix in 2:
			g.v.append(Vector3(ix * w - w / 2, -(iy * h - h / 2) + dy, 0)); g.n.append(Vector3(0, 0, 1)); g.uv.append(Vector2(ix, 1 - iy))
	g.i.append_array([0, 2, 1, 2, 3, 1])
	return g

func cyl_geo(rt: float, rb: float, h: float, rs: int, open_ended := false, ts := 0.0, tl := TAU) -> Geo:
	var g := Geo.new(); var hh := h / 2; var slope := (rb - rt) / h
	var rows := []
	for y in 2:
		var row := []; var r := y * (rb - rt) + rt
		for x in rs + 1:
			var u := float(x) / rs; var th := u * tl + ts
			row.append(g.v.size())
			g.v.append(Vector3(r * sin(th), -y * h + hh, r * cos(th)))
			g.n.append(Vector3(sin(th), slope, cos(th)).normalized()); g.uv.append(Vector2(u, 1 - y))
		rows.append(row)
	for x in rs:
		var a: int = rows[0][x]; var b: int = rows[1][x]; var c: int = rows[1][x + 1]; var d: int = rows[0][x + 1]
		if rt > 0: g.i.append_array([a, b, d])
		if rb > 0: g.i.append_array([b, c, d])
	if not open_ended:
		for top in [true, false]:
			var r := rt if top else rb
			if r <= 0: continue
			var sg := 1.0 if top else -1.0; var c0 := g.v.size()
			for x in rs:
				g.v.append(Vector3(0, hh * sg, 0)); g.n.append(Vector3(0, sg, 0)); g.uv.append(Vector2(0.5, 0.5))
			var c1 := g.v.size()
			for x in rs + 1:
				var th := float(x) / rs * tl + ts
				g.v.append(Vector3(r * sin(th), hh * sg, r * cos(th))); g.n.append(Vector3(0, sg, 0))
				g.uv.append(Vector2(cos(th) * 0.5 + 0.5, sin(th) * 0.5 * sg + 0.5))
			for x in rs:
				if top: g.i.append_array([c1 + x, c1 + x + 1, c0 + x])
				else: g.i.append_array([c1 + x + 1, c1 + x, c0 + x])
	return g

## a 4-sided roof whose UVs run in world units: tiles across, rows up the slope
func roof_cone(r: float, h: float) -> Geo:
	var g := cyl_geo(0, r, h, 4)
	var around := 4 * r * sqrt(2.0); var up := Vector2(h, r * 0.71).length()
	for k in g.uv.size(): g.uv[k] = Vector2(g.uv[k].x * around / TILE.roof, g.uv[k].y * up / TILE.roof)
	return g
```

The brushy grain (900 short pale strokes on white, each blended at 35% over what is there):

```gdscript
## brushy grain: short pale strokes on white (canvas fillRect at 35% over the last result)
func grain_image(seed_value: int, w := 128, h := 128, n := 900) -> Image:
	var r := Rng.new(seed_value)
	var buf := PackedFloat32Array(); buf.resize(w * h); buf.fill(255.0)
	for k in n:
		var g := 196 + int(r.next() * 59)
		var x0 := int(r.next() * w); var y0 := int(r.next() * h); var rw := 4 + int(r.next() * 18); var rh := 1 + int(r.next() * 2)
		for y in range(y0, mini(y0 + rh, h)):
			for x in range(x0, mini(x0 + rw, w)):
				buf[y * w + x] = roundf(buf[y * w + x] * 0.65 + g * 0.35)
	var bytes := PackedByteArray(); bytes.resize(w * h * 3)
	for k in w * h:
		var b := int(buf[k]); bytes[k * 3] = b; bytes[k * 3 + 1] = b; bytes[k * 3 + 2] = b
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, bytes)

func tex_from(img: Image, mipmaps := true) -> ImageTexture:
	if mipmaps: img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
```

Materials: one toon `ShaderMaterial` per role and map, cached:

```gdscript
var grain_tex: ImageTexture
var TEX := {}
var mats := {}

func light_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("key_linear", lin(col("key")) * L.key / PI)
	m.set_shader_parameter("rim_linear", lin(col("rim")) * L.rim / PI)
	m.set_shader_parameter("rim_dir", (L.rim_pos - KEY_TARGET).normalized())
	m.set_shader_parameter("sky_linear", lin(col("fill-sky")) * L.hemi / PI)
	m.set_shader_parameter("ground_linear", lin(col("fill-ground")) * L.hemi / PI)
	var z: Vector3 = (L.key_pos).normalized()   # the shadow camera looks from key_pos + target at the target
	var x := Vector3.UP.cross(z).normalized(); var y := z.cross(x)
	m.set_shader_parameter("shadow_center", KEY_TARGET); m.set_shader_parameter("shadow_x", x); m.set_shader_parameter("shadow_y", y)
	m.set_shader_parameter("fog_linear", lin(col("fog")))
	fog_params(m)

func fog_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("fog_color", col("fog")); m.set_shader_parameter("fog_density", L.fog)

## toon paint: role colour x a map (grain, a tiling value map, or pixel art), 4-step light
func paint(role: String, map = null, key := "", shader: Shader = null) -> ShaderMaterial:
	if key == "": key = role
	if mats.has(key): return mats[key]
	var m := ShaderMaterial.new(); m.shader = shader if shader else S_TOON
	m.set_shader_parameter("albedo", col(role))
	if map == null:
		m.set_shader_parameter("grain_map", grain_tex)
	elif map is String:   # a value map by name
		m.set_shader_parameter("map_kind", 1); m.set_shader_parameter("value_map", TEX[map]); m.set_meta("tile", TILE[map])
	else:
		m.set_shader_parameter("map_kind", 2); m.set_shader_parameter("pixel_map", map)
	light_params(m)
	mats[key] = m
	return m

func M(r: String) -> ShaderMaterial: return paint("material-" + r)
const SURF := {"plaster": "plaster", "stone": "plaster", "wood": "wood", "roof": "roof"}
func MT(r: String) -> ShaderMaterial: return paint("material-" + r, SURF[r], "tex-" + r)

func flat(shader: Shader, c: Color, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = shader
	m.set_shader_parameter("color", c); fog_params(m)
	for k in extra: m.set_shader_parameter(k, extra[k])
	return m
```

Placing pieces, and the contact blob:

```gdscript
var world: Node3D

func mesh(g: Geo, m: Material, x: float, y: float, z: float, parent: Node3D = null, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = to_mesh(g); mi.material_override = m
	mi.position = Vector3(x, y, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else world).add_child(mi)
	return mi

func box(w: float, h: float, d: float, m: ShaderMaterial, x: float, y: float, z: float, parent: Node3D = null) -> MeshInstance3D:
	var g := box_geo(w, h, d)
	if m.has_meta("tile"): world_uv(g, m.get_meta("tile"), Vector3(x, y + h / 2, z))
	return mesh(g, m, x, y + h / 2, z, parent)

var blob_quad: ArrayMesh

func blob(x: float, z: float, r: float, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = blob_quad
	mi.material_override = flat(S_BLOB, col("outline"))
	mi.position = Vector3(x, 0.012, z); mi.scale = Vector3(r, 1, r)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else world).add_child(mi)
	return mi
```

The cast: pixel sprites on yaw-only billboards:

```gdscript
var people := {}
var cam: Camera3D

func first_row(img: Image) -> int:
	for y in CH:
		for x in CW:
			if img.get_pixel(x, y).a > 0.5: return y
	return 0

func person(id: String, x: float, z: float, face := 1.0) -> void:
	var tex: Texture2D = load("res://assets/sprites/%s.png" % id)
	var m := ShaderMaterial.new(); m.shader = S_SPRITE
	m.set_shader_parameter("tex", tex); m.set_shader_parameter("tint", col("tint")); fog_params(m)
	var g := plane_geo(CW * PX, CH * PX, (CH / 2.0 - (CH - FEET - 1)) * PX)   # the feet row stands on the floor
	var mi := mesh(g, m, x, 0, z, null, false)
	mi.scale.x = face
	mi.rotation.y = atan2(HOME_POS.x - x, HOME_POS.z - z)   # yaw-only billboard (fixed stage camera)
	blob(x, z, 0.42)
	var top := first_row(tex.get_image())
	people[id] = {"id": id, "x": x, "z": z, "mi": mi, "top": top, "anchor": Vector3(x, (FEET + 1 - top) * PX, z)}
```

Start-up: the shared textures and the blob quad, then your set, then the atmosphere:

```gdscript
func _ready() -> void:
	grain_tex = tex_from(grain_image(7))
	for k in [["floor", "floor-tiles"], ["roof", "roof-tiles"], ["plaster", "plaster"], ["wood", "wood-planks"]]:
		TEX[k[0]] = load("res://assets/textures/%s.png" % k[1])
	var bq := Geo.new()   # unit disc as a quad on the floor; the shader cuts the radial falloff
	for iz in 2:
		for ix in 2:
			bq.v.append(Vector3(ix * 2 - 1, 0, iz * 2 - 1)); bq.n.append(Vector3.UP); bq.uv.append(Vector2(ix, 1 - iz))
	bq.i = [0, 2, 1, 2, 3, 1]
	blob_quad = to_mesh(bq)
	world = Node3D.new(); add_child(world)
	# ... your set: box(), mesh(), blob() and person() calls

	# the animated banded valley surface
	var valley := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(320, 180)
	pm.subdivide_width = 199; pm.subdivide_depth = 109; valley.mesh = pm
	var vm := ShaderMaterial.new(); vm.shader = preload("res://shaders/valley.gdshader")
	var leaf := col("material-leaf").srgb_to_linear().lerp(col("ground").srgb_to_linear(), 0.25)
	vm.set_shader_parameter("time", T)
	vm.set_shader_parameter("base_color", leaf.linear_to_srgb())
	vm.set_shader_parameter("crest_color", hex_mix(col("material-leaf"), col("fog"), 0.55))
	vm.set_shader_parameter("key_dir", (L.key_pos as Vector3).normalized())
	vm.set_shader_parameter("key_color", srgb(lin(col("key")) * L.key / PI))
	vm.set_shader_parameter("fill_color", srgb(lin(col("fill-sky")) * L.hemi / PI))
	vm.set_shader_parameter("fog_color", col("fog")); vm.set_shader_parameter("density", L.fog)
	valley.material_override = vm; valley.position = Vector3(0, -20, -80)
	valley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(valley)

	# painted backdrop on a far open cylinder
	var bm := ShaderMaterial.new(); bm.shader = preload("res://shaders/backdrop.gdshader")
	bm.set_shader_parameter("sky", tex_from(sky_image()))
	var backdrop := MeshInstance3D.new(); backdrop.mesh = to_mesh(cyl_geo(190, 190, 160, 48, true, PI - 1.25, 2.5))
	backdrop.material_override = bm; backdrop.position = Vector3(0, 20, 0)
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(backdrop)

	# light shafts and drifting mist
	for i in 4:
		var s := mesh(plane_geo(2.2 + i * 0.6, 40), flat(preload("res://shaders/shaft.gdshader"), col("key"), {"opacity": L.shafts}),
			-9 + i * 5.5, 4, -14 - i * 2, self, false)
		s.rotation.z = 0.42
	var mist_geo := plane_geo(1, 1)
	for i in 18:
		var x := -24 + rnd.next() * 48; var y := -6 + rnd.next() * 5; var z := -8 - rnd.next() * 30
		var sc := 9 + rnd.next() * 7; var ph := rnd.next() * 6
		var s := mesh(mist_geo, flat(S_MIST, col("fog"), {"opacity": L.mist}), x + sin(T * 0.05 + ph) * 2, y, z, self, false)
		s.scale = Vector3(sc, sc, sc)
	# ... then the selection ring, build_env(), build_post(), build_captions() and select()
```

`sky_image()` is your painted backdrop (see the import settings). The key light, the environment
and the camera, then the post chain:

```gdscript
func build_env() -> void:
	var key := DirectionalLight3D.new()
	key.light_color = col("key")
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 40.0
	key.shadow_bias = 0.02; key.shadow_normal_bias = 1.0; key.shadow_blur = 1.0
	add_child(key)
	key.look_at_from_position(L.key_pos + KEY_TARGET, KEY_TARGET)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = col("fog")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR   # black: the toon shader adds the fill
	env.ambient_light_color = Color.BLACK; env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR             # palette colours land as authored
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)

	cam = Camera3D.new(); cam.fov = 46; cam.near = 0.3; cam.far = 600
	add_child(cam); cam.look_at_from_position(HOME_POS, HOME_LOOK); cam.current = true

## post: tilt-shift (horizontal, vertical), then the grade, each reading the screen
func build_post() -> void:
	var layer := CanvasLayer.new(); layer.layer = 1; add_child(layer)
	var passes := [["tilt", {"step_uv": Vector2(2.4 / W, 0), "focus": 0.40}], ["tilt", {"step_uv": Vector2(0, 2.4 / H), "focus": 0.40}],
		["grade", {"tint": grade_tint(), "amount": L.grade, "vignette": L.vignette, "time": 0.0}]]
	for k in passes.size():
		if k > 0:
			var bb := BackBufferCopy.new(); bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT; layer.add_child(bb)
		var rect := ColorRect.new(); rect.set_anchors_preset(Control.PRESET_FULL_RECT); rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new(); m.shader = load("res://shaders/%s.gdshader" % passes[k][0])
		for p in passes[k][1]: m.set_shader_parameter(p, passes[k][1][p])
		rect.material = m; layer.add_child(rect)

func grade_tint() -> Vector3:
	var f := lin(col("fill-ground")); return f / maxf(f.x, maxf(f.y, f.z))
```

Captions. The fonts: names in 17 px bold small capitals with 1 px letter spacing, the status line
in 16 px italic, both drawn on a `Control` in their own `CanvasLayer` above the post (`EMBOLDEN` was
tuned to match Chrome's heavier light-on-dark names; keep it if your captions look thin):

```gdscript
var f_name: FontVariation
var f_line: FontVariation
const EMBOLDEN := 0.2         # Chrome on Windows draws the light-on-dark names a little heavier than FreeType
const BASELINE_SHIFT := -1.0  # Chrome places the baseline 1 px higher than the hhea-centred line box
var cap_layer: Control

func build_captions() -> void:
	# the font files the web demo bundles (assets/fonts): Alegreya, variable upright and italic
	var ts := TextServerManager.get_primary_interface()
	f_name = FontVariation.new(); f_name.base_font = load("res://fonts/Alegreya-Variable.woff")
	f_name.variation_opentype = {ts.name_to_tag("wght"): 600}                     # font-weight 600
	f_name.opentype_features = {ts.name_to_tag("smcp"): 1}                       # small caps
	f_name.spacing_glyph = 1                                                     # .06em
	f_name.variation_embolden = EMBOLDEN
	f_line = FontVariation.new(); f_line.base_font = load("res://fonts/Alegreya-Italic.woff")
	var layer := CanvasLayer.new(); layer.layer = 2; add_child(layer)
	cap_layer = Control.new(); cap_layer.set_anchors_preset(Control.PRESET_FULL_RECT); cap_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cap_layer)
	cap_layer.draw.connect(draw_captions)
```

The layout, each time the selection or the camera changes, follows recipe.md's Interface steps:
obstacles are every sprite's drawn rectangle (head top to feet, 0.6 of its height wide, projected
with `cam.unproject_position`) and every captioned prop's projected bounding box (soft); captions
are placed in priority order (selected person, prop in focus, the rest), the first `MAX_FULL = 4`
full and the rest as a short name, each at most 240 px wide with 3 × 9 px padding and line height
1.2. The search for a free spot:

```gdscript
func hits(a: Rect2, b: Rect2, gap: float) -> bool:
	return a.position.x < b.end.x + gap and b.position.x < a.end.x + gap and a.position.y < b.end.y + gap and b.position.y < a.end.y + gap

func find_spot(anc: Vector2, own: Rect2, w: float, h: float, B: Rect2, placed: Array, hard: Array, soft: Array) -> Variant:
	var ok := func(r: Rect2) -> bool:
		if r.position.x < B.position.x or r.position.y < B.position.y or r.end.x > B.end.x or r.end.y > B.end.y: return false
		for p in placed:
			if hits(r, p, 4): return false
		for p in hard + soft:
			if hits(r, p, 2): return false
		return true
	var cx := own.position.x + own.size.x / 2; var top := own.position.y
	var tries := []
	for dy in [0, -14, -28, -42, -56, -70, -84]:
		for dx in [0, -50, 50, -100, 100, -150, 150]: tries.append(Vector2(cx - w / 2 + dx, top - h - 4 + dy))   # above, sliding out
	for dy in [0, 16, -16, 32, 48]:
		tries.append(Vector2(own.end.x + 6, own.position.y + dy)); tries.append(Vector2(own.position.x - w - 6, own.position.y + dy))   # beside
	for dx in [0, -60, 60]: tries.append(Vector2(cx - w / 2 + dx, own.end.y + 4))   # below
	for t in tries:
		var r := Rect2(t, Vector2(w, h))
		if ok.call(r): return r
	return null
```

Each caption is drawn with `draw_style_box`: a `StyleBoxFlat` in `plate` at 85% with 4 px corners,
and around it the soft glow (`plate` at 60%, about 10 px) as 14 one-pixel border rings at
expand margins 1 to 14, fading out. Names are `accent` on the selected person and `ink` otherwise;
lines are centred in the box.

Selection: a left click casts a ray from the camera (`project_ray_origin`, `project_ray_normal`)
against an invisible sphere of radius 0.75 at chest height (0.9 up) on each person, never against
the caption text; the nearest hit is selected, the ring moves under them and the captions are laid
out again.
