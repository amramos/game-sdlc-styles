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
