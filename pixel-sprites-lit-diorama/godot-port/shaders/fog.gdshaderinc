// three.js FogExp2 on view depth, mixed in linear light. Environment fog stays off: in Compatibility
// it is applied in every light pass. Read in fragment(), so a source_color uniform (set as an sRGB Color).
uniform vec4 fog_color : source_color = vec4(0.79, 0.86, 0.9, 1.0);
uniform float fog_density = 0.0085;
float fog_factor(float depth) { float d = fog_density * depth; return 1.0 - exp(-d * d); }
