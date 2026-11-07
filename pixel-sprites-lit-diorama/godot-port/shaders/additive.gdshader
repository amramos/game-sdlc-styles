shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The selection ring: accent added over the floor, fogged. Added on sRGB values in Compatibility,
// on linear ones in Forward+ (the web adds in linear).
#include "res://shaders/fog.gdshaderinc"
#include "res://shaders/space.gdshaderinc"
uniform vec4 color : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform bool use_fog = true;
varying float view_depth;
void vertex() { view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	vec3 c = in_linear(color.rgb);
	if (use_fog) c = mix(c, in_linear(fog_color.rgb), fog_factor(view_depth));
	ALBEDO = out_added(c * opacity);
}
