// Shared by toon.gdshader (primitives) and toon_slots.gdshader (generated models).
// Colours read in light() are LINEAR vec3s set from a Vector3 (lin3() in GDScript): Compatibility does
// not linearise source_color uniforms read in light(), and Forward+ converts a Color passed to a vec3.
uniform vec3 ambient_linear = vec3(0.275, 0.352, 0.807); // lin3(shadow-tint)
uniform float ambient_ratio = 0.45;
uniform float key_ratio = 0.60;
uniform float lit_threshold = 0.0;        // N·L where shade turns to lit
uniform float highlight_threshold = 0.75; // N·L where the highlight starts
uniform float highlight_amount = 0.25;    // 0.25 x 0.60 = +0.15 key; 0 turns the third band off
uniform float edge = 0.01;                // half-width of the band edge
uniform float rim_amount = 0.0;           // 0.35 on characters
uniform vec3 rim_linear = vec3(0.624, 0.863, 1.0);  // lin3(sky-horizon)
uniform bool receive_shadow = true;
// Fog is mixed here (Environment fog off), in sRGB like three.js: smoothstep on view depth.
uniform vec3 fog_srgb = vec3(0.812, 0.937, 1.0);    // sky-horizon, sRGB values
uniform vec2 fog_range = vec2(30.0, 210.0);
varying float view_depth;
varying float face_shift;                 // + to N·L: 0.5 on face texels, which stay lit unless lit from behind

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void vertex() {
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;   // light() cannot read VERTEX
}

void light() {
	float ndl = dot(NORMAL, LIGHT) + face_shift;
	float band = smoothstep(lit_threshold - edge, lit_threshold + edge, ndl);
	if (receive_shadow) {
		band = min(band, step(0.5, ATTENUATION));   // the shadow map joins the same step
	}
	float hi = smoothstep(highlight_threshold - edge, highlight_threshold + edge, ndl) * band;
	vec3 key = LIGHT_COLOR / PI * key_ratio * (band + hi * highlight_amount);  // LIGHT_COLOR has x PI
	if (LIGHT_IS_DIRECTIONAL) {
		// The whole colour is written here, in one pass (Environment ambient and fog stay off), so
		// Compatibility and Forward+ agree.
		vec3 lit = ambient_linear * ambient_ratio + key;
		vec3 a = max(ALBEDO, vec3(1e-4));
		// hard rim on the lit side (N·L without the face shift), mixed in linear
		float k = rim_amount * step(0.70, 1.0 - dot(NORMAL, VIEW)) * step(0.0, dot(NORMAL, LIGHT));
		vec3 col = mix(a * lit, rim_linear, k);
		// fog: mixed in sRGB after encoding, as three.js does
		float f = smoothstep(fog_range.x, fog_range.y, view_depth);
		col = to_linear(mix(to_srgb(clamp(col, 0.0, 1.0)), fog_srgb, f));
		DIFFUSE_LIGHT += col / a;
	} else {
		DIFFUSE_LIGHT += key;   // point lights add to the lit band only
	}
}
