// Post pass on the TextureRect that shows the low-res SubViewport: nearest upscale,
// 4x4 ordered dither, 31 levels per channel.
shader_type canvas_item;

uniform vec2 low_res = vec2(427.0, 240.0);
const float B[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };

void fragment() {
	vec2 px = floor(UV * low_res);
	vec3 c = texture(TEXTURE, (px + 0.5) / low_res).rgb;
	float row = low_res.y - 1.0 - px.y;   // count rows from the bottom, as GL's gl_FragCoord does
	c += ((B[int(mod(row, 4.0)) * 4 + int(mod(px.x, 4.0))] + 0.5) / 16.0 - 0.5) * 1.2 / 31.0;
	COLOR = vec4(floor(clamp(c, 0.0, 1.0) * 31.0 + 0.5) / 31.0, 1.0);
}
