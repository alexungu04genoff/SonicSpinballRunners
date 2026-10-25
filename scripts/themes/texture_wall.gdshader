shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D wall_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float top_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 wall(vec2 coordinates) {
 vec2 uv = coordinates / vec2(3.4, 1.45);
 return textureGrad(wall_texture, vec2(fract(uv.x), clamp(uv.y, 0.0, 1.0)), dFdx(uv), dFdy(uv)).rgb;
}
void fragment() {
 vec2 weights = pow(abs(world_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 float depth = top_height - world_position.y;
 ALBEDO = wall(vec2(world_position.z, depth)) * weights.x + wall(vec2(world_position.x, depth)) * weights.y;
 ROUGHNESS = 0.95;
}
