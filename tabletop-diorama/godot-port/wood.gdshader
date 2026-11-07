// Painted wood, table and street: three.js MeshStandardMaterial (r160) rebuilt in light().
// Diffuse = colour x map, matte GGX specular (F0 0.04), a hemisphere fill and linear-space fog, all
// in the directional light's pass with the Environment's ambient black (see godot.md).
// The result is written scaled by out_scale so HDR values up to 1/out_scale survive the 8-bit
// viewport; the lens pass (lens.gdshader) undoes the scale, then tone-maps with three's ACES.
shader_type spatial;
render_mode specular_disabled;

uniform vec3 color_lin = vec3(1.0);            // palette role, linear (set as Vector3 from GDScript)
uniform sampler2D map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;   // linear bytes (see lin_img)
uniform vec2 repeat = vec2(1.0);
uniform bool flip_y = true;                    // three CanvasTexture / TextureLoader default
uniform float rough = 0.8;
uniform bool use_normal = false;               // only flat horizontal planes (table, street)
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 normal_scale = vec2(1.0);
uniform vec3 key_lin = vec3(3.0);              // key colour x intensity
uniform vec3 sky_lin = vec3(2.0);              // hemisphere sky colour x intensity
uniform vec3 ground_lin = vec3(0.0);           // hemisphere ground colour x intensity
uniform vec3 fog_lin = vec3(0.7);
uniform vec2 fog_range = vec2(15.0, 28.0);     // view depth, smoothstep (three.js Fog)
uniform float out_scale = 0.5;

vec3 to_linear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 to_srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

varying float view_depth;
varying vec3 up_view;

void vertex() {
	up_view = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec2 uv = UV * repeat;
	if (flip_y) uv.y = 1.0 - uv.y;
	vec3 albedo = color_lin * texture(map, uv).rgb;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = to_srgb(albedo);   // Compatibility linearises ALBEDO after fragment(); hand it sRGB
#else
	ALBEDO = albedo;
#endif
	if (use_normal) {
		vec3 n = texture(normal_tex, uv).rgb * 2.0 - 1.0;
		n.xy *= normal_scale;
		// plane lies in world XZ: tangent +x, bitangent (three's +v) -z, normal +y
		vec3 wn = normalize(vec3(n.x, n.z, -n.y));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
}

void light() {
	vec3 N = NORMAL;
	vec3 V = VIEW;
	vec3 L = LIGHT;
	float ndl = clamp(dot(N, L), 0.0, 1.0);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	vec3 H = normalize(L + V);
	float ndh = clamp(dot(N, H), 0.0, 1.0);
	float vdh = clamp(dot(V, H), 0.0, 1.0);
	float a = rough * rough;
	float a2 = a * a;
	float fr = exp2((-5.55473 * vdh - 6.98316) * vdh);
	float F = 0.04 * (1.0 - fr) + fr;
	float gv = ndl * sqrt(a2 + (1.0 - a2) * ndv * ndv);
	float gl = ndv * sqrt(a2 + (1.0 - a2) * ndl * ndl);
	float vis = 0.5 / max(gv + gl, 1e-6);
	float den = ndh * ndh * (a2 - 1.0) + 1.0;
	float D = a2 / (PI * den * den);
	vec3 direct = key_lin * ndl * ATTENUATION;
	vec3 hemi = mix(ground_lin, sky_lin, 0.5 * dot(N, normalize(up_view)) + 0.5);
	vec3 col = ALBEDO / PI * (direct + hemi) + direct * F * vis * D;
	col = mix(col, fog_lin, smoothstep(fog_range.x, fog_range.y, view_depth));
	DIFFUSE_LIGHT += col * out_scale / max(ALBEDO, vec3(1e-4));
}
