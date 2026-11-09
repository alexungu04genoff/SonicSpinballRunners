shader_type spatial;
#include "res://scripts/themes/rooftop_normal.gdshaderinc"
// Linear palette uniforms preserve the original shader constants.
uniform vec3 base_color = vec3(0.04, 0.07, 0.13);
uniform vec3 reflection_color = vec3(0.025, 0.14, 0.12);
uniform vec2 center = vec2(0.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D response_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_albedo = false;
uniform float repeat_distance = 32.0;
uniform vec3 albedo_tint_reference = vec3(1.0);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_position.xz - center;
 float bend = sin(p.x * 0.17 + TIME * 0.075) * 1.8 + sin(p.x * 0.31 - TIME * 0.045) * 0.6;
 float band = exp(-pow((p.y + 8.0 + bend) * 0.24, 2.0));
 band += exp(-pow((p.y - 6.0 + bend * 1.4) * 0.17, 2.0)) * 0.30;
 float ripples = 0.72 + sin(p.y * 4.0 + sin(p.x * 0.6) + TIME * 0.08) * 0.16;
 // Art-directed, distorted aurora reflection, not a screen-space reflection.
 ALBEDO = base_color;
 if (use_albedo) ALBEDO = texture(albedo_texture, p / repeat_distance).rgb * base_color / max(albedo_tint_reference, vec3(.001));
 EMISSION = reflection_color * band * ripples * 1.2;
 ROUGHNESS = 0.25;
 SPECULAR = 0.8;
 if (use_albedo) {
  vec3 response = texture(response_texture, p / repeat_distance).rgb;
  NORMAL = relief(VERTEX, NORMAL, p / repeat_distance, p / repeat_distance);
  ROUGHNESS = response.r;
  SPECULAR = response.g;
  EMISSION *= response.b;
 }
}
