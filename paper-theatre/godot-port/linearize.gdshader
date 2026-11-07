// Copies a print into a half-float (HDR 2D) viewport as linear values, alpha untouched, so its
// mipmaps can be averaged in linear light like WebGL does for sRGB textures.
shader_type canvas_item;
render_mode blend_disabled, unshaded;
vec3 to_lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c.rgb = to_lin(c.rgb);   // Compatibility samples the print undecoded even in an HDR 2D viewport
#endif
	COLOR = c;               // Forward+ has already decoded it (HDR 2D canvases work in linear)
}
