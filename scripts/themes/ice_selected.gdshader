shader_type spatial;
#include "res://scripts/atmosphere/hue.gdshaderinc"
#include "res://scripts/themes/rooftop_normal.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D response_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool reflections_enabled = true;
uniform bool has_response_map = true;
uniform bool flip_vertical = false;
// 0: world floor, 1: exterior projection, 2: strip, 3: ramp, 5: wall, 6: foliage UV.
uniform int mapping = 0;
uniform vec2 repeat_size = vec2(1.0);
uniform float top_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 sample_surface(sampler2D map, vec2 uv, bool clamp_vertical) {
 vec2 dx = dFdx(uv), dy = dFdy(uv);
 if (clamp_vertical) uv.y = clamp(uv.y, .002, .998);
 return textureGrad(map, uv, dx, dy).rgb;
}
vec2 sample_coordinates(vec2 uv, bool clamp_vertical) {
 if (clamp_vertical) uv.y = clamp(uv.y, .002, .998);
 return uv;
}
void fragment() {
 vec2 uv = UV / repeat_size;
 if (mapping == 2 && flip_vertical) uv.y = 1.0 - uv.y;
 if (mapping == 0) uv = world_position.xz / repeat_size;
 if (mapping == 3) uv = vec2(clamp(UV2.x, .002, .998), UV.y / repeat_size.y);
 if (mapping == 5) uv = vec2(UV.x / repeat_size.x, (top_height - world_position.y) / repeat_size.y);
 vec3 color;
 vec3 response;
 vec3 geometric = NORMAL;
 if (mapping == 1) {
  float depth = top_height - world_position.y;
  vec2 weights = pow(abs(world_normal.xz), vec2(6.0));
  weights /= max(weights.x + weights.y, .001);
  vec2 first = vec2(world_position.z, depth) / repeat_size;
  vec2 second = vec2(world_position.x, depth) / repeat_size;
  color = sample_surface(albedo_texture, first, true) * weights.x;
  color += sample_surface(albedo_texture, second, true) * weights.y;
  response = sample_surface(response_texture, first, true) * weights.x;
  response += sample_surface(response_texture, second, true) * weights.y;
  NORMAL = normalize(relief(VERTEX, geometric, first, sample_coordinates(first, true)) * weights.x
   + relief(VERTEX, geometric, second, sample_coordinates(second, true)) * weights.y);
 } else {
  bool clamped = mapping == 2 || mapping == 5;
  color = sample_surface(albedo_texture, uv, clamped);
  response = has_response_map ? sample_surface(response_texture, uv, clamped) : vec3(.93, .18, 0.0);
  NORMAL = relief(VERTEX, geometric, uv, sample_coordinates(uv, clamped));
 }
 ALBEDO = atmosphere_shift(color);
 // User-requested ice reflections use the existing sky. Snow stays matte.
 // The structural response uses exactly the same chart as the albedo.
 ROUGHNESS = reflections_enabled ? response.r : .75;
 SPECULAR = reflections_enabled ? response.g : .22;
 METALLIC = 0.0;
}
