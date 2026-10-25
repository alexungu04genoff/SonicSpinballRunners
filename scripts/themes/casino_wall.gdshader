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
 float frame = 1.0 - smoothstep(0.055, 0.055 + aa, min(edge.x, edge.y));
 float arch = 1.0 - smoothstep(0.024, 0.024 + aa, abs(length((q - vec2(0.5, 0.43)) * vec2(1.0, 0.70)) - 0.28));
 vec3 recess = mix(vec3(0.045, 0.055, 0.13), vec3(0.22, 0.025, 0.045), mod(floor(p.x), 2.0));
 vec3 color = mix(recess, vec3(0.49, 0.29, 0.075), max(frame, arch * 0.75));
 vec2 bulb = vec2(fract(q.x * 4.0) - 0.5, (q.y - 0.86) * 4.0);
 float lamp = 1.0 - smoothstep(0.13, 0.13 + aa * 4.0, length(bulb));
 return vec4(color, lamp);
}
void fragment() {
 vec2 weights = pow(abs(world_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 vec4 panel = facade(world_position.zy * vec2(1.8, 2.8)) * weights.x + facade(world_position.xy * vec2(1.8, 2.8)) * weights.y;
 float depth = top_height - world_position.y;
 float rim = 1.0 - smoothstep(0.012, 0.026, abs(depth - 0.045));
 float gold = 1.0 - smoothstep(0.015, 0.024, abs(depth - 0.095));
 ALBEDO = mix(panel.rgb, vec3(0.67, 0.40, 0.10), gold);
 ALBEDO = mix(ALBEDO, vec3(0.68, 0.10, 0.18), rim);
 EMISSION = vec3(0.9, 0.36, 0.08) * panel.a * 0.75 + vec3(0.7, 0.035, 0.12) * rim * 0.6;
 ROUGHNESS = 0.55;
}
