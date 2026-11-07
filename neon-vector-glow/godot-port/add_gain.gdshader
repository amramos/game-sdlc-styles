shader_type canvas_item;
// Adds a blurred (premultiplied) layer onto the frame with a gain: the web's 'lighter' copies.
render_mode blend_add, unshaded;

uniform float gain = 1.0;

void fragment() {
	COLOR = vec4(texture(TEXTURE, UV).rgb * gain, 1.0);
}
