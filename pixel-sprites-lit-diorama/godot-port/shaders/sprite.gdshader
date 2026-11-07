shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// A pixel sprite lit by tint: nearest texels, no mipmaps, alpha cut at 0.5, fogged like the set.
#include "res://shaders/fog.gdshaderinc"
#include "res://shaders/space.gdshaderinc"
uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
varying float view_depth;
void vertex() { view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < 0.5) discard;   // alphaTest 0.5: discard keeps the sprite in the opaque pass
	vec3 c = in_linear(t.rgb) * in_linear(tint.rgb);
	ALBEDO = out_albedo(mix(c, in_linear(fog_color.rgb), fog_factor(view_depth)));
}
