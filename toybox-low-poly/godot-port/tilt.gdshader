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
