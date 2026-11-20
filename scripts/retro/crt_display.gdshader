shader_type canvas_item;
render_mode unshaded;

uniform float raster_lines = 300.0;
uniform float scanline_strength = 0.34;
uniform float grille_pitch = 3.0;
uniform float grille_strength = 0.0;
uniform float glow_strength = 0.42;
uniform float glow_radius = 2.6;
uniform float brightness = 0.0;
uniform float vignette = 0.14;

void fragment() {
	// The world has already been filtered and scaled into this output rectangle.
	vec2 output_pixel = fwidth(UV);
	vec2 spread = output_pixel * glow_radius;
	vec4 source = texture(TEXTURE, UV);
	vec3 left = texture(TEXTURE, UV - vec2(spread.x, 0.0)).rgb;
	vec3 right = texture(TEXTURE, UV + vec2(spread.x, 0.0)).rgb;
	vec3 above = texture(TEXTURE, UV - vec2(0.0, spread.y)).rgb;
	vec3 below = texture(TEXTURE, UV + vec2(0.0, spread.y)).rgb;
	vec3 surround = 0.35 * (left + right) + 0.15 * (above + below);
	vec3 light = mix(source.rgb, surround, 0.18 * glow_strength);
	// Let neighboring highlights spread into dark edges. Black stays black.
	vec3 halo = 0.35 * (left * left + right * right) + 0.15 * (above * above + below * below);
	light += glow_strength * (max(halo - source.rgb * source.rgb, vec3(0.0)) + 0.30 * halo);
	light = max(light + brightness, vec3(0.0));

	// First harmonic of a normalized Gaussian beam train. A brighter spot is
	// wider, so neighboring lines merge. Integrate across the output pixel
	// and fade near Nyquist to avoid moire when the playfield gets small.
	// A saturated blue phosphor can be bright even if the combined luma is low.
	vec3 sigma = mix(vec3(0.28), vec3(0.53), sqrt(clamp(light, vec3(0.0), vec3(1.0))));
	float row = UV.y * raster_lines;
	float footprint = max(fwidth(row), 0.0001);
	vec3 beam_response = 2.0 * exp(-2.0 * PI * PI * sigma * sigma);
	float pixel_response = sin(PI * footprint) / (PI * footprint);
	float resolved = 1.0 - smoothstep(0.30, 0.50, footprint);
	light *= 1.0 + scanline_strength * resolved * pixel_response * beam_response * cos(TAU * (row - 0.5));

	// Optional close-up aperture grille. One period is one RGB triad.
	float phase = TAU * FRAGCOORD.x / grille_pitch;
	vec3 stripes = cos(vec3(phase) + vec3(0.0, -TAU / 3.0, TAU / 3.0));
	light *= vec3(1.0) + grille_strength * smoothstep(2.0, 3.0, grille_pitch) * stripes;
	float edge = smoothstep(0.58, 1.0, length(UV * 2.0 - 1.0) * 0.707107);
	COLOR = vec4(light * (1.0 - vignette * edge), source.a);
}
