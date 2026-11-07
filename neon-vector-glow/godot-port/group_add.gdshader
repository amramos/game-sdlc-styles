shader_type canvas_item;
// CanvasGroup material for bloom-source strokes: the group's children (one path, opaque, normal
// blend) are a union like one canvas stroke; add that union with the group's alpha (self_modulate.a).
render_mode blend_add, unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);   // premultiplied
	COLOR = vec4(c.rgb * COLOR.a, 1.0);
}
