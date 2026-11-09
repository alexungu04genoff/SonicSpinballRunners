shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cap_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// 0: world floor, 1: contour wall, 2: contour strip, 3: ramp, 4: facade.
uniform int mapping = 0;
uniform vec2 repeat_size = vec2(1.0);
uniform float wall_height = 0.325;
uniform float cap_height = 0.055;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 uv = UV / repeat_size;
 if (mapping == 0) uv = world_position.xz / repeat_size;
 if (mapping == 3) uv = vec2(clamp(UV2.x, 0.001, 0.999), UV.y / repeat_size.y);
 if (mapping == 1) uv = vec2(UV.x / repeat_size.x, clamp((wall_height - cap_height - world_position.y) / (wall_height - cap_height), 0.001, 0.999));
 if (mapping == 2 || mapping == 4) uv.y = clamp(uv.y, 0.001, 0.999);
 vec3 color = texture(albedo_texture, uv).rgb;
 if (mapping == 1 && world_position.y > wall_height - cap_height) {
  // Four cap inserts span the same length as three column bays.
  vec2 cap_uv = vec2(UV.x / repeat_size.x, clamp((wall_height - world_position.y) / cap_height, 0.001, 0.999));
  color = texture(cap_texture, cap_uv).rgb;
 }
 ALBEDO = color;
 ROUGHNESS = 0.65;
 SPECULAR = 0.3;
}
