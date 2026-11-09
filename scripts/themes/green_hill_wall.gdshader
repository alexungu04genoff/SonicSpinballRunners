shader_type spatial;
#include "res://scripts/atmosphere/hue.gdshaderinc"
render_mode cull_disabled, specular_disabled;
uniform sampler2D soil_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fringe_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool show_fringe = true;
uniform float turf_height = 0.30;
varying vec3 terrain_position;
void vertex() {
 terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
 // U follows the mesh contour continuously, including curves. World height
 // keeps checker rows aligned between raised walls and the outer floor cliff.
 float along = UV.x;
 vec3 dpdx = dFdx(terrain_position);
 vec3 dpdy = dFdy(terrain_position);
 float along_dx = dFdx(UV.x);
 float along_dy = dFdy(UV.x);
 vec3 soil = textureGrad(soil_texture, vec2(along, -terrain_position.y) / 0.64,
  vec2(along_dx, -dpdx.y) / 0.64, vec2(along_dy, -dpdy.y) / 0.64).rgb;
 float depth = turf_height - terrain_position.y;
 // The image owns the blade silhouette and color; height only places the trim.
 vec2 fringe_uv = vec2(along * 3.125, depth / 0.1);
 // Repeat along the wall only. Explicit gradients avoid a mip discontinuity at
 // fract(U), while sampler clamping prevents transparent tips leaking into its top.
 vec4 fringe = textureGrad(fringe_texture, vec2(fract(fringe_uv.x), clamp(fringe_uv.y, 0.0, 1.0)),
  vec2(along_dx * 3.125, -dpdx.y / 0.1), vec2(along_dy * 3.125, -dpdy.y / 0.1));
 ALBEDO = mix(soil, fringe.rgb, fringe.a * (1.0 - step(0.1, depth)) * (show_fringe ? 1.0 : 0.0));
 ROUGHNESS = 1.0;
 ALBEDO = atmosphere_shift(ALBEDO);
}
