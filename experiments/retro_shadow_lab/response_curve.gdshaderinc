// Only the dither candidate varies threshold across a surface. For clean
// bands threshold is always 0.5, so every isocontour follows filtered visibility.
float lab_response(float visibility, float threshold, int count, bool native_range,
		float opacity, vec4 levels, float binary_dark) {
	if (count < 2) { return visibility; }
	float floor_value = native_range ? 1.0 - opacity : 0.0;
	float span = 1.0 - floor_value;
	if (span < 0.0001) { return visibility; }
	float filtered = clamp((visibility - floor_value) / span, 0.0, 1.0);
	float last = float(count - 1);
	float scaled = filtered * last;
	float index = min(last, floor(scaled) + step(threshold, fract(scaled)));
	float band = index / last;
	if (native_range) { return floor_value + span * band; }
	if (count == 2) { return mix(binary_dark, levels.w, band); }
	// The original four art stops also define a curve for three/eight levels.
	float palette_position = band * 3.0;
	int stop = min(int(palette_position), 2);
	return mix(levels[stop], levels[stop + 1], palette_position - float(stop));
}
