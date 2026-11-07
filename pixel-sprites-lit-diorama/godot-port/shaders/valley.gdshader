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
