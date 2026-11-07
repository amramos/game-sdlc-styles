shader_type canvas_item;
// One axis of a Gaussian blur (sigma in target pixels). Run it twice (H then V) per bloom radius.
// The target is a transparent SubViewport, so write premultiplied colour unchanged.
render_mode blend_premul_alpha, unshaded;

uniform sampler2D src : filter_linear, repeat_disable;
uniform vec2 step_uv;            // one target pixel along the blur axis, in UV
uniform float sigma = 2.0;
uniform vec2 pre_uv = vec2(0.0); // H pass when shrinking: average 4 taps this far from each sample

vec4 tap(vec2 uv) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return vec4(0.0);        // outside the frame is empty, as on a canvas
	}
	if (pre_uv == vec2(0.0)) {
		return texture(src, uv);
	}
	return 0.25 * (texture(src, uv + pre_uv) + texture(src, uv - pre_uv)
		+ texture(src, uv + vec2(pre_uv.x, -pre_uv.y)) + texture(src, uv + vec2(-pre_uv.x, pre_uv.y)));
}

void fragment() {
	int n = int(ceil(sigma * 3.0));
	vec4 acc = vec4(0.0);
	float wsum = 0.0;
	for (int i = -n; i <= n; i++) {
		float w = exp(-0.5 * float(i * i) / (sigma * sigma));
		acc += tap(UV + step_uv * float(i)) * w;
		wsum += w;
	}
	COLOR = acc / wsum;
}
