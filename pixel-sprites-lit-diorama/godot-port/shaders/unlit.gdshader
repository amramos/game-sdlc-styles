shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;
// Lamp cores and bunting lines: a flat colour, fogged.
#include "res://shaders/fog.gdshaderinc"
#include "res://shaders/space.gdshaderinc"
uniform vec4 color : source_color = vec4(1.0);
varying float view_depth;
void vertex() { view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z; }
void fragment() { ALBEDO = out_albedo(mix(in_linear(color.rgb), in_linear(fog_color.rgb), fog_factor(view_depth))); }
