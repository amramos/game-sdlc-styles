shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// The painted sky on a far open cylinder: no light, no fog.
uniform sampler2D sky : source_color, filter_linear_mipmap, repeat_disable;
void fragment() { ALBEDO = texture(sky, UV).rgb; }
