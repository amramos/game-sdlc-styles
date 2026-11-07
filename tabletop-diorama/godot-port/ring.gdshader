// The accent ring: unlit, fogged, 95% opaque, drawn over the street without writing depth.
// Its own shader, because writing ALPHA moves every material using a shader to the transparent pass.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 color_lin = vec3(1.0, 0.0, 0.5);
uniform vec3 fog_lin = vec3(0.7);
uniform vec2 fog_range = vec2(15.0, 28.0);
uniform float out_scale = 0.5;
varying float view_depth;
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
void vertex() { view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	vec3 col = mix(color_lin, fog_lin, smoothstep(fog_range.x, fog_range.y, view_depth)) * out_scale;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	col = to_srgb(col);   // Compatibility linearises ALBEDO after fragment(), unshaded too
#endif
	ALBEDO = col;
	ALPHA = 0.95;
}
