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
