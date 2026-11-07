shader_type canvas_item;
// Halftone for engine-drawn shadows (never on the stage): round dots on a fixed grid, clear between.
// The grid starts at the rect's own top-left, like a CSS background tile.
uniform vec4 dot_color : source_color = vec4(0.071, 0.2, 0.227, 1.0);
uniform float cell = 6.0;     // grid size in px
uniform float radius = 2.0;   // dot radius in px (web: radial-gradient(c 1.9px, transparent 2.1px))
uniform vec2 rect_size = vec2(100.0, 100.0);

void fragment() {
	vec2 q = mod(UV * rect_size, cell) - cell * 0.5;
	float a = 1.0 - smoothstep(radius - 0.5, radius + 0.5, length(q));
	COLOR = vec4(dot_color.rgb, dot_color.a * a);
}
