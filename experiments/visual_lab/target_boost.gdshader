shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.05, 0.42, 1.0, 1.0);
uniform float phase = 0.0;
varying float along;

void vertex() {
	along = VERTEX.y * 0.5 + 0.5;
	float radius = mix(1.9, 0.18, along);
	VERTEX.xz *= radius;
	VERTEX.y = mix(-1.55, 4.2, along);
	// The front dome encloses the runner. The far end narrows to a jet.
	NORMAL = normalize(vec3(NORMAL.x / radius, NORMAL.y / 2.875, NORMAL.z / radius));
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.7);
	float streak = pow(0.5 + 0.5 * cos(TAU * (UV.x * 5.0 + along * 0.32)), 12.0);
	float pulse = 0.5 + 0.5 * cos(TAU * (along * 2.6 - phase * 1.7));
	float edge = 1.0 - smoothstep(0.73, 1.0, along);
	float collar = exp(-abs(along - 0.20) * 45.0);
	ALBEDO = mix(tint.rgb, vec3(0.88, 0.96, 1.0), 0.24 * collar + 0.07 * streak);
	ALPHA = edge * clamp(0.08 + rim * 0.85 + streak * (0.19 + 0.27 * pulse) + collar * 0.32, 0.0, 1.0);
}
