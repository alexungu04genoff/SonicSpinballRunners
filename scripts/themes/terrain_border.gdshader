shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D border_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
 ALBEDO = texture(border_texture, vec2(UV.x, clamp(UV.y, 0.01, 0.99))).rgb;
 ROUGHNESS = 1.0;
}
