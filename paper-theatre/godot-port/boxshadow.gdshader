// CSS drop-shadow blur of a rectangle: a Gaussian (sigma = blur radius / 2) of a box is a product
// of two erf differences, so the soft shadow under a paper slip needs no render target.
shader_type canvas_item;
uniform vec4 box = vec4(0.0, 0.0, 100.0, 100.0);   // x0, y0, x1, y1 in this rect's local pixels
uniform float sigma = 3.0;
uniform vec4 shadow : source_color = vec4(0.0, 0.0, 0.0, 0.35);
varying vec2 local;
void vertex() { local = VERTEX; }
float erf_(float x) {   // Abramowitz-Stegun 7.1.26
	float s = sign(x); x = abs(x);
	float t = 1.0 / (1.0 + 0.3275911 * x);
	float y = 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x);
	return s * y;
}
void fragment() {
	float k = 1.0 / (sigma * sqrt(2.0));
	float ax = 0.5 * (erf_((local.x - box.x) * k) - erf_((local.x - box.z) * k));
	float ay = 0.5 * (erf_((local.y - box.y) * k) - erf_((local.y - box.w) * k));
	COLOR = vec4(shadow.rgb, shadow.a * ax * ay);
}
