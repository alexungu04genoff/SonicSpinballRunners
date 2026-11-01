shader_type spatial;
#include "res://scripts/atmosphere/hue.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 repeat_size = vec2(0.32);
uniform bool clamp_depth = false;
uniform float top_height = 0.325;
uniform float roughness_value = 1.0;
uniform float specular_value = 0.0;
uniform sampler2D fringe_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool show_fringe = false;
uniform float turf_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 facade(vec2 coordinates) {
 vec2 uv = coordinates / repeat_size;
 vec2 dx = dFdx(uv), dy = dFdy(uv);
 if (clamp_depth) uv.y = clamp(uv.y, 0.001, 0.999);
 return textureGrad(surface_texture, uv, dx, dy).rgb;
}
void fragment() {
 vec2 weights = pow(abs(world_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 // One world-space datum for every piece, including translated Act recipes.
 float v = (clamp_depth ? top_height : 0.0) - world_position.y;
 ALBEDO = facade(vec2(world_position.z, v)) * weights.x
  + facade(vec2(world_position.x, v)) * weights.y;
 float depth = turf_height - world_position.y;
 vec2 uv = vec2((world_position.x + world_position.z) * 3.125, depth / 0.1);
 vec2 dx = dFdx(uv), dy = dFdy(uv);
 if (show_fringe && depth >= 0.0 && depth < 0.1) {
  vec4 fringe = textureGrad(fringe_texture, vec2(fract(uv.x), clamp(uv.y, 0.0, 1.0)), dx, dy);
  ALBEDO = mix(ALBEDO, fringe.rgb, fringe.a);
 }
 ROUGHNESS = roughness_value;
 SPECULAR = specular_value;
 ALBEDO = atmosphere_shift(ALBEDO);
}
