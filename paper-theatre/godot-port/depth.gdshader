// A shadow caster as the light's camera sees it: alpha-tested on the print, both faces, writing
// its packed depth. Lives on render layer 2, which only the shadow cameras draw.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
#include "res://stage.gdshaderinc"

void fragment() {
	if (alpha_test && print_sample(UV).a < 0.5) discard;
	vec3 code = pack_depth(shadow_depth(VERTEX.z));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = code;            // Compatibility writes the 3D colour through as it is
#else
	ALBEDO = to_lin(code);    // Forward+ encodes linear to sRGB on the way out
#endif
}
