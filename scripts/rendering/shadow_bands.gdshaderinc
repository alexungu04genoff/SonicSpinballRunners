// Signed correction to the existing key diffuse term. The opaque pass still
// owns direct specular, local lights, ambient, emission and depth.
#include "res://scripts/rendering/shadow_curve.gdshaderinc"
uniform int lab_count = 4; // zero is the signed-pass cost/identity control
uniform bool lab_dither = false;
uniform bool lab_native_range = true;
uniform float lab_shadow_opacity = 1.0;
uniform vec4 lab_levels = vec4(0.25, 0.50, 0.75, 1.00);
uniform float lab_binary_dark = 0.50;
uniform int lab_anchor = 2;
uniform int lab_matrix = 4;
uniform float lab_cell = 0.035;
uniform float lab_screen_cell = 1.0;
uniform float lab_width = 0.70;
uniform float lab_sun_size = 0.0;
uniform vec3 lab_key_direction;
uniform vec4 lab_fog; // density, depth begin, depth end, depth exponent (zero for exponential)
uniform vec2 lab_height_fog; // height and density
varying vec3 lab_world;
varying vec3 lab_object;
varying flat vec3 lab_object_axis;
varying vec3 lab_world_axis;
varying float lab_transmission;

float lab_fog_transmission(float distance_to_eye, float height) {
	float depth = exp(-distance_to_eye * lab_fog.x);
	if (lab_fog.w > 0.0) {
		float ramp = smoothstep(lab_fog.y, lab_fog.z, distance_to_eye);
		depth = 1.0 - pow(ramp, lab_fog.w) * lab_fog.x;
	}
	return clamp(min(depth, exp(min(0.0, (height - lab_height_fog.x) * lab_height_fog.y))), 0.0, 1.0);
}

vec2 lab_plane(vec3 point, vec3 axis) {
	if (axis.y >= max(axis.x, axis.z)) { return point.xz; }
	return axis.x >= axis.z ? point.zy : point.xy;
}

int lab_bayer2(ivec2 p) {
	return ((p.x ^ p.y) & 1) * 2 + (p.y & 1);
}

float lab_threshold(vec2 grid) {
	ivec2 cell = ivec2(floor(grid));
	int rank = lab_bayer2(cell);
	if (lab_matrix == 2) { return (float(rank) + 0.5) / 4.0; }
	return (float(4 * rank + lab_bayer2(cell >> ivec2(1))) + 0.5) / 16.0;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL && dot(LIGHT, mat3(VIEW_MATRIX) * lab_key_direction) > 0.999) {
		float threshold = 0.5;
		if (lab_dither) {
			vec2 grid = FRAGCOORD.xy / lab_screen_cell;
			if (lab_anchor == 1) { grid = lab_plane(lab_object, lab_object_axis) / lab_cell; }
			if (lab_anchor == 2) { grid = lab_plane(lab_world, lab_world_axis) / lab_cell; }
			threshold = mix(0.5, lab_threshold(grid), lab_width);
		}
		float correction = lab_response(ATTENUATION, threshold, lab_count, lab_native_range,
				lab_shadow_opacity, lab_levels, lab_binary_dark) - ATTENUATION;
		// Burley diffuse as used by the supported opaque terrain programs.
		float nl = clamp(lab_sun_size + dot(NORMAL, LIGHT), 0.0, 1.0);
		float nv = clamp(dot(NORMAL, VIEW), 0.0001, 1.0);
		float lh = clamp(lab_sun_size + dot(LIGHT, normalize(LIGHT + VIEW)), 0.0, 1.0);
		float fd = 2.0 * lh * lh * ROUGHNESS - 0.5;
		float diffuse = nl * (1.0 + fd * pow(1.0 - nv, 5.0)) * (1.0 + fd * pow(1.0 - nl, 5.0)) / PI;
		DIFFUSE_LIGHT += LIGHT_COLOR * (correction * diffuse * lab_transmission);
	}
}
