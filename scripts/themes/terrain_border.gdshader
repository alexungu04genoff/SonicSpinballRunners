shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D border_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void fragment() {
 // Repeat along the path, clamp across it at every mip level. Unwrapped
 // derivatives keep sampling stable on either side of the U texture seam.
 ALBEDO = textureGrad(border_texture, vec2(fract(UV.x), clamp(UV.y, 0.0, 1.0)), dFdx(UV), dFdy(UV)).rgb;
 ROUGHNESS = 1.0;
}
