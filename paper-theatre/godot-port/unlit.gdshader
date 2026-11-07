// three's MeshBasicMaterial: the colour as authored, no light, no shadow.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0);
void fragment() {
	ALBEDO = color.rgb;
}
