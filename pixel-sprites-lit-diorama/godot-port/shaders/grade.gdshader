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
