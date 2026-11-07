shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.14, 0.13, 0.23, 1.0);
uniform vec4 fog_color : source_color = vec4(0.81, 0.94, 1.0, 1.0);
uniform float width_px = 3.0;
uniform vec2 fade = vec2(12.0, 60.0);       // full width until x, 1 px at y (metres)
uniform vec2 fog_range = vec2(30.0, 210.0);
varying float depth;

void vertex() {
	// smoothed normal baked into the vertex colour; use NORMAL on smooth meshes
	vec3 n = COLOR.rgb * 2.0 - 1.0;   // raw in vertex() in both renderers
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n_view = normalize(MODELVIEW_NORMAL_MATRIX * n);
	vec2 n_clip = normalize((PROJECTION_MATRIX * vec4(n_view, 0.0)).xy + 1e-6);
	float px = mix(width_px, 1.0, smoothstep(fade.x, fade.y, clip.w)) * VIEWPORT_SIZE.y / 1080.0;
	clip.xy += n_clip * px * 2.0 / VIEWPORT_SIZE * clip.w;
	depth = clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = mix(ink.rgb, fog_color.rgb, smoothstep(fog_range.x, fog_range.y, depth));
}
