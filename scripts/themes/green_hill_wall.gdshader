shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D soil_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fringe_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float turf_height = 0.30;
varying vec3 terrain_position;
varying vec3 terrain_normal;
void vertex() {
 terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 vec2 weights = pow(abs(terrain_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 vec3 soil = texture(soil_texture, terrain_position.zy / 0.32).rgb * weights.x
  + texture(soil_texture, terrain_position.xy / 0.32).rgb * weights.y;
 float depth = turf_height - terrain_position.y;
 // The image owns the blade silhouette and color; height only places the trim.
 vec4 fringe = texture(fringe_texture, vec2((terrain_position.x + terrain_position.z) * 3.0, clamp(depth / 0.1, 0.008, 0.992)));
 ALBEDO = mix(soil, fringe.rgb, fringe.a * (1.0 - step(0.1, depth)));
 ROUGHNESS = 1.0;
}
