// Compatibility (tested in 4.7.1) runs an UNSHADED spatial shader in sRGB: source_color uniforms and
// textures arrive un-linearised, ALBEDO goes to the screen as it is, and blending happens on sRGB
// values. Forward+ runs the same shader in linear. These helpers make the maths linear in both.
vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
vec3 in_linear(vec3 c) {   // a source_color input, as linear
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return to_linear(c);
#else
	return c;
#endif
}
vec3 out_albedo(vec3 c) {  // a linear result, as ALBEDO
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return to_srgb(max(c, vec3(0.0)));
#else
	return c;
#endif
}
float out_alpha(float a) { // blending a dark colour over the scene: the sRGB-space alpha that darkens like a linear one
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return 1.0 - pow(1.0 - a, 1.0 / 2.2);
#else
	return a;
#endif
}
vec3 out_added(vec3 c) {   // a linear amount ADDED to the scene: in sRGB, scale by the curve's slope at mid-tones
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c * 0.7;
#else
	return c;
#endif
}
