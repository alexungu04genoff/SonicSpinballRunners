shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec2 guard_uv;
void vertex() {
 int corner = VERTEX_ID % 6;
 float across = (corner == 2 || corner == 3 || corner == 5) ? 1.0 : 0.0;
 guard_uv = vec2(UV.y / 0.64, across);
}
void fragment() {
 ALBEDO = textureGrad(surface_texture, vec2(fract(guard_uv.x), clamp(guard_uv.y, 0.0, 1.0)), dFdx(guard_uv), dFdy(guard_uv)).rgb;
 ROUGHNESS = 1.0;
}
