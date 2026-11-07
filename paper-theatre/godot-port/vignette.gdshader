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
