shader_type spatial;
render_mode specular_disabled;

uniform vec4 base_color : source_color = vec4(0.42, 0.80, 0.29, 1.0);
#include "res://toon_light.gdshaderinc"

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	face_shift = 0.0;
}
