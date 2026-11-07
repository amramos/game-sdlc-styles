shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Contact blob: outline colour at 45%, alpha 1 inside 15% of the radius falling to 0 at the edge.
#include "res://shaders/fog.gdshaderinc"
#include "res://shaders/space.gdshaderinc"
uniform vec4 color : source_color = vec4(1.0);
uniform float opacity = 0.45;
varying float view_depth;
void vertex() { view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	ALBEDO = out_albedo(mix(in_linear(color.rgb), in_linear(fog_color.rgb), fog_factor(view_depth)));
	ALPHA = out_alpha(opacity * clamp(1.0 - (d - 0.15) / 0.85, 0.0, 1.0));
}
