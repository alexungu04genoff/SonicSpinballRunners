shader_type spatial;
render_mode cull_disabled;

uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 repeat_size = vec2(4.0);
uniform float normal_strength : hint_range(0.0, 1.0) = 0.35;
uniform float roughness_variation : hint_range(0.0, 1.0) = 0.0;
uniform float specular_strength : hint_range(0.0, 0.5) = 0.0;
varying vec3 world_position;

void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
 vec2 coordinates = world_position.xz / repeat_size;
 ALBEDO = texture(surface_texture, coordinates).rgb;
 vec3 detail = texture(normal_texture, coordinates).rgb * 2.0 - 1.0;
 // Explicit world-XZ basis matches the floor UVs, including meshes without tangents.
 vec3 world_normal = normalize(vec3(detail.x * normal_strength, detail.z, detail.y * normal_strength));
 NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
 ROUGHNESS = mix(1.0, texture(roughness_texture, coordinates).r, roughness_variation);
 SPECULAR = specular_strength;
}
