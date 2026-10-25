shader_type spatial;
render_mode specular_disabled;
uniform vec4 rock_color : source_color = vec4(0.18,0.15,0.23,1.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 float along = dot(world_position.xz, abs(world_normal.zx));
 float stratum = world_position.y * 0.85 + sin(along * 0.8) * 0.21;
 float band = smoothstep(0.03,0.13,fract(stratum));
 float facet = 0.8 + 0.2 * sin(floor(along * 0.7) * 7.7 + floor(stratum) * 3.7);
 float vein = pow(max(0.0,sin(along * 0.65 + world_position.y * 0.72)),12.0);
 ALBEDO = rock_color.rgb * mix(0.62,1.0,band) * facet;
 ALBEDO = mix(ALBEDO,vec3(0.06,0.16,0.15),vein * 0.28);
 float bounce = 1.0 - smoothstep(-7.2,-1.0,world_position.y);
 EMISSION = vec3(0.24,0.047,0.012) * bounce * (0.5 + 0.5 * band) + ALBEDO * 0.08;
 ROUGHNESS = 1.0;
}
