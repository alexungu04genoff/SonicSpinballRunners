// The receiver's native diffuse/specular, emission and fog still run normally.
#include "res://experiments/retro_ao_lab/bands.gdshaderinc"
uniform sampler2D contact_depth : hint_default_black, filter_nearest, repeat_disable;
uniform float contact_radius = 0.42;
uniform float contact_strength = 0.62;
uniform int contact_levels = 0;
uniform bool face_study = false;
uniform bool contact_ordered = false;
uniform int contact_anchor = 2;
uniform int contact_matrix = 4;
uniform float contact_cell = 0.045;
uniform float contact_transition = 0.55;
uniform vec2 contact_heights = vec2(0.0, 1.0);
varying vec3 contact_local;
varying vec3 contact_face_normal;

float contact_field(vec2 ao_uv, vec3 ao_surface, vec3 ao_normal, mat4 ao_projection, mat4 ao_unproject) {
 vec2 ao_size = vec2(textureSize(contact_depth, 0));
 float ao_w = max((ao_projection * vec4(ao_surface, 1.0)).w, 0.001);
 vec2 ao_footprint = abs(vec2(ao_projection[0][0], ao_projection[1][1])) * (0.5 * contact_radius / ao_w);
 float ao_horizon = 0.0;
 for (int ao_direction = 0; ao_direction < 8; ao_direction++) {
  float ao_angle = (float(ao_direction) + 0.375) * (TAU / 8.0);
  vec2 ao_axis = vec2(cos(ao_angle), sin(ao_angle)) * ao_footprint;
  float ao_highest = 0.0;
  for (int ao_ring = 1; ao_ring <= 3; ao_ring++) {
   vec2 ao_tap = (floor((ao_uv + ao_axis * (float(ao_ring * ao_ring) / 9.0)) * ao_size) + 0.5) / ao_size;
   if (any(lessThan(ao_tap, vec2(0.0))) || any(greaterThanEqual(ao_tap, vec2(1.0)))) { continue; }
   float ao_z = textureLod(contact_depth, ao_tap, 0.0).r;
   if (ao_z <= 0.0) { continue; }
   vec4 ao_v = ao_unproject * vec4(ao_tap * 2.0 - 1.0, ao_z, 1.0);
   vec3 ao_delta = ao_v.xyz / ao_v.w - ao_surface;
   float ao_distance_to_tap = length(ao_delta);
   float ao_elevation = max(dot(ao_normal, ao_delta) - 0.008, 0.0) / max(ao_distance_to_tap, 0.001);
   float ao_weight = 1.0 - smoothstep(0.05 * contact_radius, contact_radius, ao_distance_to_tap);
   ao_highest = max(ao_highest, max(ao_elevation - 0.09, 0.0) * ao_weight);
  }
  ao_horizon += ao_highest;
 }
 return clamp(ao_horizon * (2.8 / 8.0), 0.0, 1.0);
}

int contact_rank(ivec2 ao_p) { return ((ao_p.x ^ ao_p.y) & 1) * 2 + (ao_p.y & 1); }

vec2 contact_plane(vec3 ao_p, vec3 ao_n) {
 vec3 ao_a = abs(ao_n);
 if (ao_a.y >= max(ao_a.x, ao_a.z)) { return ao_p.xz; }
 return ao_a.x >= ao_a.z ? ao_p.zy : ao_p.xy;
}

float contact_threshold(vec2 ao_pixel, vec3 ao_world, vec3 ao_world_normal, vec3 ao_local, vec3 ao_local_normal) {
 if (!contact_ordered) { return 0.5; }
 vec2 ao_grid = ao_pixel / max(1.0, contact_cell / 0.045);
 if (contact_anchor == 1) { ao_grid = contact_plane(ao_local, ao_local_normal) / contact_cell; }
 if (contact_anchor == 2) { ao_grid = contact_plane(ao_world, ao_world_normal) / contact_cell; }
 ivec2 ao_cell = ivec2(floor(ao_grid));
 int ao_rank = contact_rank(ao_cell);
 float ao_ordered = (float(ao_rank) + 0.5) * 0.25;
 if (contact_matrix == 4) { ao_ordered = (float(ao_rank * 4 + contact_rank(ao_cell >> ivec2(1))) + 0.5) / 16.0; }
 return mix(0.5, ao_ordered, contact_transition);
}

float face_cavity(vec3 ao_normal, float ao_local_y) {
 float ao_side = 1.0 - abs(ao_normal.y);
 float ao_underside = max(-ao_normal.y, 0.0);
 float ao_height = clamp((ao_local_y - contact_heights.x) / max(contact_heights.y, 0.001), 0.0, 1.0);
 return clamp(ao_side * (0.34 + 0.30 * (1.0 - ao_height)) + 0.75 * ao_underside, 0.0, 1.0);
}
