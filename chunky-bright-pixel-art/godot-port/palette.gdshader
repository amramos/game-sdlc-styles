shader_type canvas_item;

// 16x1 texture, one role per pixel, in .gpl order
uniform sampler2D palette : filter_nearest;

void fragment() {
	// COLOR is already vertex colour x texture, so this works for sprites (index in the texture)
	// and for draw_rect()/polygons (index in the vertex colour) alike.
	vec4 src = COLOR;
	float index = floor(src.r * 15.0 + 0.5);
	COLOR = vec4(texture(palette, vec2((index + 0.5) / 16.0, 0.5)).rgb, src.a);
}
