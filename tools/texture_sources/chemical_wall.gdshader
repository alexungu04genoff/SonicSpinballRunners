shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float top_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec4 machinery(vec2 p) {
 vec2 q = fract(p);
 vec2 edge = min(q, 1.0 - q);
 float aa = max(length(fwidth(p)), 0.004);
 float frame = 1.0 - smoothstep(0.045, 0.045 + aa, min(edge.x, edge.y));
 float brace = 1.0 - smoothstep(0.025, 0.025 + aa, min(abs(q.x - q.y), abs(q.x + q.y - 1.0)));
 float bay = mod(floor(p.x), 3.0);
 vec3 panel = vec3(0.12, 0.19, 0.30);
 panel = mix(panel, vec3(0.34, 0.43, 0.53), brace * step(bay, 0.5) * 0.8);
 float vent = step(1.5, bay) * step(0.15, q.x) * step(q.x, 0.85) * step(0.2, q.y) * step(q.y, 0.8);
 panel = mix(panel, vec3(0.055, 0.08, 0.14), vent * step(0.45, fract(p.y * 9.0)));
 panel = mix(panel, vec3(0.49, 0.56, 0.64), frame);
 float lamp = step(0.72, q.x) * step(q.x, 0.86) * step(0.76, q.y) * step(q.y, 0.81);
 return vec4(mix(panel, vec3(0.15, 0.8, 0.49), lamp), lamp);
}
void fragment() {
 // World-space projection wraps every authored curve without modifying its mesh.
 vec2 weights = pow(abs(world_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 vec4 panel = machinery(world_position.zy * vec2(2.0, 3.0)) * weights.x + machinery(world_position.xy * vec2(2.0, 3.0)) * weights.y;
 float depth = top_height - world_position.y;
 float band = step(0.025, depth) * step(depth, 0.080);
 float diagonal = step(0.5, fract((world_position.x + world_position.z + world_position.y) * 12.0));
 vec3 warning = mix(vec3(0.025, 0.035, 0.06), vec3(0.98, 0.72, 0.10), diagonal);
 ALBEDO = mix(panel.rgb, warning, band);
 float rim = 1.0 - smoothstep(0.014, 0.024, abs(depth - 0.012));
 ALBEDO = mix(ALBEDO, vec3(0.12, 0.62, 0.83), rim);
 EMISSION = vec3(0.03, 0.44, 0.65) * rim * 0.42 + vec3(0.12, 0.6, 0.30) * panel.a * 0.35;
 ROUGHNESS = 0.8;
}
