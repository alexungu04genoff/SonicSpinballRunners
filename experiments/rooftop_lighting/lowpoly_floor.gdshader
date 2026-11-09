shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mortar_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.55;
uniform float mortar_depth : hint_range(0.0, 2.0) = 0.65;
uniform float detail_intensity : hint_range(0.0, 2.0) = 0.65;
uniform float variation_amount : hint_range(0.0, 1.0) = 0.15;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
vec2 normal_slope(vec2 rg) {
 vec2 xy = rg * 2.0 - 1.0;
 return xy / sqrt(max(1.0 - dot(xy, xy), 0.0001));
}
void fragment() {
 vec2 uv = world_position.xz / vec2(4.0);
 ALBEDO = texture(surface_texture, uv).rgb;
 vec2 mortar = normal_slope(texture(mortar_normal, uv).rg);
 vec4 detail = texture(detail_normal, uv);
 float variation = 1.0 + variation_amount * 0.35 * (detail.a * 2.0 - 1.0);
 vec2 slope = (mortar * mortar_depth + normal_slope(detail.rg) * detail_intensity * variation) * normal_strength;
 // OpenGL +Y points up the image, corresponding to world -Z on this floor.
 vec3 world_normal = normalize(vec3(slope.x, 1.0, -slope.y));
 NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
 ROUGHNESS = 1.0;
}
