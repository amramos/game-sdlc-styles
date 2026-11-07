shader_type spatial;
// Light shafts: the key colour added at 2.5% (no fog). Forward+ adds it in linear, like the web.
// Compatibility blends on sRGB values and drops small additive amounts, so there the same lift is
// a mix toward white with alpha 2.56 x opacity (matched on the sky behind the shafts).
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#else
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#endif
uniform vec4 color : source_color = vec4(1.0);
uniform float opacity = 0.025;
void fragment() {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = vec3(1.0);
	ALPHA = opacity * 2.56;
#else
	ALBEDO = color.rgb * opacity;
#endif
}
