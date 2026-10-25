shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 repeat_size = vec2(1.0);
uniform bool world_mapping = true;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 coordinates = world_mapping ? world_position.xz : UV;
 ALBEDO = texture(surface_texture, coordinates / repeat_size).rgb;
 ROUGHNESS = 1.0;
}
