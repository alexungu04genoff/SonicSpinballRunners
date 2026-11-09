#include "res://experiments/rooftop_lighting/scene_normal.gdshaderinc"
uniform sampler2D height_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float height_strength : hint_range(0.0, 0.08) = 0.04;
uniform int parallax_steps : hint_range(4, 24) = 12;
uniform int relief_boundary = 0;
vec2 relief_sample(vec2 uv) {
 if (relief_boundary == 1) { return vec2(fract(uv.x), clamp(uv.y, 0.001, 0.999)); }
 if (relief_boundary == 2) { return clamp(uv, vec2(0.001), vec2(0.999)); }
 return uv;
}
vec2 crossed_uv(vec3 position, vec3 geometric, vec2 uv, vec3 to_camera) {
 vec2 sx = dFdx(uv), sy = dFdy(uv);
 vec3 dx = dFdx(position), dy = dFdy(position);
 float determinant = sx.x * sy.y - sx.y * sy.x;
 if (height_strength <= 0.0 || abs(determinant) < 0.00000001) { return uv; }
 vec3 n = normalize(geometric);
 vec3 t = (dx * sy.y - dy * sx.y) / determinant;
 vec3 b = (dy * sx.x - dx * sy.x) / determinant;
 vec3 dual_u = cross(b, n), dual_v = cross(n, t);
 float area = dot(t, dual_u);
 if (abs(area) < 0.00000001) { return uv; }
 float facing = dot(n, to_camera);
 vec2 direction = vec2(dot(to_camera, dual_u), dot(to_camera, dual_v)) / area;
 vec2 offset = direction * height_strength * smoothstep(0.08, 0.3, facing) / max(facing, 0.2);
 // Prevent large UV jumps on thin strips at grazing angles.
 offset = clamp(offset, vec2(-0.15), vec2(0.15));
 float step_depth = 1.0 / float(parallax_steps);
 vec2 at = uv, previous = uv;
 float ray_depth = 0.0;
 float surface_depth = 1.0 - textureGrad(height_texture, relief_sample(at), sx, sy).r;
 float previous_difference = surface_depth;
 for (int i = 0; i < 24; i++) {
  if (i >= parallax_steps || ray_depth >= surface_depth) { break; }
  previous = at;
  previous_difference = surface_depth - ray_depth;
  at -= offset * step_depth;
  ray_depth += step_depth;
  surface_depth = 1.0 - textureGrad(height_texture, relief_sample(at), sx, sy).r;
 }
 float difference = ray_depth - surface_depth;
 return mix(previous, at, clamp(previous_difference / max(previous_difference + difference, 0.00001), 0.0, 1.0));
}
