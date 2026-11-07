shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
// Accent ring, markers and contact blobs: unlit, fogged by hand with the same curve.
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 fog_color : source_color = vec4(0.97, 0.87, 0.79, 1.0);
uniform vec2 fog_range = vec2(43.0, 66.0);
uniform bool blob = false;           // radial contact blob: alpha 1 inside 1/8 radius to 0 at the edge
uniform float blob_opacity = 0.45;
varying float view_depth;

void vertex() {
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	ALBEDO = mix(color.rgb, fog_color.rgb, smoothstep(fog_range.x, fog_range.y, view_depth));
	if (blob) {
		float d = length(UV * 2.0 - 1.0);
		ALPHA = blob_opacity * clamp((1.0 - d) / 0.875, 0.0, 1.0);
	}
}
