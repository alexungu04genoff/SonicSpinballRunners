shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float top_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec4 facade(vec2 p) {
 vec2 q = fract(p);
 float aa = max(length(fwidth(p)), 0.004);
 vec2 edge = min(q, 1.0 - q);
 // Broad navy bays and slim brass frames replace the busy circular gold grid.
 float frame = 1.0 - smoothstep(0.022, 0.022 + aa, min(edge.x, edge.y));
 float bevel = 1.0 - smoothstep(0.055, 0.055 + aa, min(edge.x, edge.y));
 vec3 recess = mix(vec3(0.022, 0.035, 0.085), vec3(0.035, 0.055, 0.12), mod(floor(p.x), 2.0));
 vec3 color = mix(recess, vec3(0.09, 0.11, 0.18), bevel);
 color = mix(color, vec3(0.48, 0.29, 0.085), frame);
 float lamp = (1.0 - smoothstep(0.045, 0.045 + aa, abs(q.x - 0.5))) * (1.0 - smoothstep(0.25, 0.25 + aa, abs(q.y - 0.5)));
 return vec4(color, lamp);
}
void fragment() {
 vec2 weights = pow(abs(world_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 vec4 panel = facade(world_position.zy * vec2(1.4, 1.5)) * weights.x + facade(world_position.xy * vec2(1.4, 1.5)) * weights.y;
 float depth = top_height - world_position.y;
 float rim = 1.0 - smoothstep(0.025, 0.040, abs(depth - 0.055));
 float gold = 1.0 - smoothstep(0.012, 0.022, abs(depth - 0.115));
 ALBEDO = mix(panel.rgb, vec3(0.67, 0.40, 0.10), gold);
 ALBEDO = mix(ALBEDO, vec3(0.68, 0.10, 0.18), rim);
 EMISSION = vec3(0.025, 0.30, 1.0) * panel.a * 1.4 + vec3(1.0, 0.025, 0.16) * rim * 2.4;
 ROUGHNESS = 0.55;
}
