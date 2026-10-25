shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D surface_texture : filter_linear_mipmap_anisotropic, repeat_disable;
// 0: world floor, 1: wall depth, 2: contour band, 3: route, 4: normalized route width.
uniform int mapping = 0;
uniform vec2 repeat_size = vec2(1.0);
uniform float top_height = 0.325;
uniform float normal_power = 8.0;
uniform bool ice_fresnel = false;
uniform float emission_scale = 1.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 sample_map(sampler2D image, vec2 uv) {
 // Repeat only along the intended axes; keep derivatives before wrapping.
 vec2 dx = dFdx(uv), dy = dFdy(uv);
 vec2 wrapped = fract(uv);
 if (mapping == 1 || mapping == 2) wrapped.y = clamp(uv.y, 0.0, 1.0);
 if (mapping == 4) wrapped.x = clamp(uv.x, 0.0, 1.0);
 return textureGrad(image, wrapped, dx, dy).rgb;
}
void fragment() {
 vec2 uv = (mapping == 0 ? world_position.xz : UV) / repeat_size;
 if (mapping == 4) uv = vec2(UV2.x, UV.y / repeat_size.y);
 vec3 color;
 vec3 glow;
 vec3 properties;
 if (mapping == 1) {
  float depth = top_height - world_position.y;
  vec2 a = vec2(world_position.z, depth) / repeat_size;
  vec2 b = vec2(world_position.x, depth) / repeat_size;
  vec2 weights = pow(abs(world_normal.xz), vec2(normal_power));
  weights /= max(weights.x + weights.y, 0.001);
  color = sample_map(albedo_texture, a) * weights.x + sample_map(albedo_texture, b) * weights.y;
  glow = sample_map(emission_texture, a) * weights.x + sample_map(emission_texture, b) * weights.y;
  properties = sample_map(surface_texture, a) * weights.x + sample_map(surface_texture, b) * weights.y;
 } else {
  color = sample_map(albedo_texture, uv);
  glow = sample_map(emission_texture, uv);
  properties = sample_map(surface_texture, uv);
 }
 ALBEDO = color;
 EMISSION = glow * emission_scale;
 if (ice_fresnel) EMISSION *= 1.0 + 3.75 * pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
 ROUGHNESS = properties.r;
 SPECULAR = properties.g;
 METALLIC = properties.b;
}
