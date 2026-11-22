shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.05, 0.42, 1.0, 1.0);
uniform float phase = 0.0;
uniform float travel = 0.0;
varying float along;

void vertex() {
	along = VERTEX.y * 0.5 + 0.5;
	float radius = mix(2.1, 0.24, along);
	VERTEX.xz *= radius;
	VERTEX.y = mix(-1.55, 7.2, along);
	// The front dome encloses the runner. The far end narrows to a jet.
	NORMAL = normalize(vec3(NORMAL.x / radius, NORMAL.y / 4.375, NORMAL.z / radius));
}

void fragment() {
	// Feather a luminous band inside the silhouette. No framebuffer taps.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = smoothstep(0.0, 0.24, facing) * (1.0 - smoothstep(0.24, 0.84, facing));
	float wave = 0.5 + 0.5 * cos(TAU * (UV.x * 5.0 + along * 0.30));
	float streak = wave * wave * wave;
	float pulse = 0.5 + 0.5 * cos(TAU * (along * 2.0 - phase * 1.7));
	float tail = 1.0 - smoothstep(0.04, 1.0, along);
	float collar = 1.0 - smoothstep(0.0, 0.115, abs(along - 0.16));
	float feather = smoothstep(0.0, 0.19, facing);
	ALBEDO = mix(tint.rgb, vec3(0.9, 0.97, 1.0), 0.32 * collar + 0.09 * streak);
	ALPHA = tail * mix(1.0, 0.53, smoothstep(0.0, 1.0, travel))
		* (0.54 * rim + feather * (0.12 + streak * (0.17 + 0.21 * pulse) + 0.30 * collar));
}
