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
