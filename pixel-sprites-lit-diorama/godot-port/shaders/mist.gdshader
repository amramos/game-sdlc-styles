shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Drifting mist: a screen-facing soft disc in the fog colour at 5% (a three.js Sprite).
uniform vec4 color : source_color = vec4(1.0);
uniform float opacity = 0.05;
void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	ALBEDO = color.rgb;
	ALPHA = opacity * clamp(1.0 - d, 0.0, 1.0);
}
