// Flat-lit toy material. Meshes carry flat face normals (no shared vertices) and the baked ground
// shading in the vertex colour. The hemisphere fill and the fog are applied inside light() for the
// sun, with the Environment's ambient black: one pass writes the whole colour, so Forward+ and
// Compatibility agree (see godot.md). Colours read in light() are linear Vector3 uniforms.

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 sky_linear = vec3(0.6, 0.7, 0.8);     // sky-top mixed 45% toward white
uniform vec3 ground_linear = vec3(0.12, 0.11, 0.24); // shadow
uniform float hemi_ratio = 0.70;
uniform float sun_ratio = 0.51;
uniform vec3 fog_linear = vec3(0.93, 0.73, 0.59);   // sky-low
uniform vec2 fog_range = vec2(43.0, 66.0);          // view depth, smoothstep
uniform vec3 emission_linear = vec3(0.0);           // ghost: accent x 0.25
uniform float alpha = 1.0;

varying vec3 up_view;
varying float view_depth;

void vertex() {
	up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void fragment() {
	vec3 shade = COLOR.rgb;   // baked ground shading, a plain multiplier
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	shade = to_srgb(shade);   // Compatibility hands vertex colours over linearised; undo it
#endif
	ALBEDO = albedo.rgb * shade;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
#ifdef GHOST
	ALPHA = alpha;   // only the ghost is transparent: writing ALPHA moves a material to the transparent pass
#endif
}

void light() {
	float ndl = max(dot(NORMAL, LIGHT), 0.0);
	vec3 sun = LIGHT_COLOR / PI * sun_ratio * ndl * ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 hemi = mix(ground_linear, sky_linear, 0.5 * dot(NORMAL, normalize(up_view)) + 0.5) * hemi_ratio;
		vec3 a = max(ALBEDO, vec3(1e-4));
		vec3 c = hemi + sun + emission_linear / a;
		float f = smoothstep(fog_range.x, fog_range.y, view_depth);
		DIFFUSE_LIGHT += mix(c, fog_linear / a, f);
	} else {
		DIFFUSE_LIGHT += sun;
	}
}
