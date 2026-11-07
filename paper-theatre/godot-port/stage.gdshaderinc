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
