shader_type spatial;
// Generated models: thin parts (sails, scarf) need both sides.
render_mode specular_disabled, cull_disabled;

// The model's texture holds a palette slot per texel (R = slot x 16). Nearest, no colour space.
uniform sampler2D slot_map : filter_nearest, repeat_enable;
uniform vec4 slot_col[16] : source_color;   // colour per slot: palette role x multiplier (in linear)
uniform int face_slot = -1;    // texels of this slot use the face ramp
#include "res://toon_light.gdshaderinc"

void fragment() {
	int slot = int(floor(texture(slot_map, UV).r * 15.9375 + 0.5));
	ALBEDO = slot_col[slot].rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	face_shift = slot == face_slot ? 0.5 : 0.0;
}
