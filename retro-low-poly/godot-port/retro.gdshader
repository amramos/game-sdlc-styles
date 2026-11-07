// One shader for every mesh: vertex snap, affine UVs, per-vertex light, linear fog.
// Colours are computed in gamma space as authored (palette hexes and light ratios land as written).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : filter_nearest, repeat_enable;   // no source_color: texels as authored
uniform bool clamp_uv = false;                  // clamp-to-edge for atlas textures (the model)
uniform vec2 low_res = vec2(427.0, 240.0);      // the SubViewport size
uniform float aspect_fix = 1.0;                 // (low_res aspect) / (window aspect)
uniform float snap = 1.0;                       // 1 = one low-res pixel, 2 = coarser, 0 = off
uniform vec3 ambient;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);     // normalised
uniform vec3 sun_col;
uniform vec3 pt_pos[6];
uniform vec3 pt_col[6];
uniform float pt_k[6];
uniform vec3 fog_col;
uniform vec2 fog_range = vec2(6.0, 55.0);
uniform float fog_on = 1.0;
uniform float unlit = 0.0;
uniform float emit = 0.0;
uniform float hi = 0.0;                         // 0.25 + 0.2 sin(6t) on what the player can use
uniform vec3 accent;

varying vec3 aff;
varying vec3 v_light;
varying float v_fog;

vec3 light_at(vec3 p, vec3 n) {
	vec3 c = ambient + sun_col * max(dot(n, sun_dir), 0.0);
	for (int i = 0; i < 6; i++) {
		vec3 l = pt_pos[i] - p;
		float d = length(l);
		float wrap = max(dot(n, l / max(d, 1e-4)), 0.0) * 0.8 + 0.2;   // back faces keep 20%
		c += pt_col[i] * wrap / (1.0 + pt_k[i] * d * d);
	}
	return c;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// Compatibility writes ALBEDO of an unshaded material into the SubViewport without the sRGB
// encode, so gamma-space values go out as they are; Forward+ encodes, so linearise first.
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define TO_OUTPUT(c) (c)
#else
#define TO_OUTPUT(c) to_linear(c)
#endif

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);   // uniform scale only
	vec4 vp = VIEW_MATRIX * vec4(wp, 1.0);
	vec4 p = PROJECTION_MATRIX * vp;
	p.x *= aspect_fix;
	if (snap > 0.0) {                                    // snap to the low-res pixel grid
		vec2 grid = low_res * 0.5 / snap;
		p.xy = floor(p.xy / p.w * grid + 0.5) / grid * p.w;
	}
	POSITION = p;
	aff = vec3(UV * p.w, p.w);                           // affine: divided back per fragment
	v_light = mix(light_at(wp, wn), vec3(1.0), unlit);   // Gouraud: light per vertex
	v_fog = clamp((-vp.z - fog_range.x) / (fog_range.y - fog_range.x), 0.0, 1.0) * fog_on;
}

void fragment() {
	vec2 uv = aff.xy / aff.z;
	if (clamp_uv) {
		uv = clamp(uv, 0.0, 1.0);
	}
	vec3 t = texture(albedo_tex, uv).rgb;
	float bright = smoothstep(0.55, 0.85, max(t.r, max(t.g, t.b)));   // only bright texels glow
	vec3 c = t * v_light + t * emit * bright + accent * hi;
	c = mix(c, fog_col, v_fog);
	ALBEDO = TO_OUTPUT(clamp(c, 0.0, 1.0));
}
