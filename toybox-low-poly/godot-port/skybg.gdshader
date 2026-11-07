shader_type canvas_item;
// Screen-space sky: sky-top at the top to sky-low at 75% height, flat below. A 2D gradient blends in
// sRGB, like the web demo's canvas gradient; drawn as the Environment's canvas background.
uniform vec4 top : source_color;
uniform vec4 low : source_color;
void fragment() {
	COLOR = vec4(mix(top.rgb, low.rgb, clamp(UV.y / 0.75, 0.0, 1.0)), 1.0);
}
