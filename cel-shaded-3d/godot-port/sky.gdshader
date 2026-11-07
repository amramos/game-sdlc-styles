shader_type sky;

uniform vec4 top : source_color;
uniform vec4 horizon : source_color;
uniform vec4 sun : source_color;
uniform vec3 sun_dir = vec3(-0.51, 0.77, 0.38);

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void sky() {
	vec3 t = top.rgb, h = horizon.rgb, s = sun.rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// Compatibility runs sky shaders in sRGB: blend in linear by hand, as Forward+ does
	t = to_linear(t); h = to_linear(h); s = to_linear(s);
#endif
	vec3 d = normalize(EYEDIR);
	// four flat steps packed low (horizon to ~20 degrees up), two below the horizon
	float up = floor(clamp(d.y / 0.34, 0.0, 1.0) * 4.0) / 4.0;            // 0, .25, .5, .75, 1
	float down = floor(clamp(-d.y / 0.5, 0.0, 1.0) * 3.0) / 3.0 * 0.35;  // 0, .12, .23, .35
	vec3 c = mix(h, t, max(up, down));
	float a = dot(d, normalize(sun_dir));
	c = mix(c, s, step(cos(radians(1.5)), a));                        // 3 deg hard disc
	c = mix(c, s, 0.3 * step(cos(radians(2.6)), a) * (1.0 - step(cos(radians(2.4)), a)));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c = to_srgb(c);
#endif
	COLOR = c;
}
