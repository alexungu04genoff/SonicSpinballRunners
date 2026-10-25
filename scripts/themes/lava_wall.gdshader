shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float top_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec4 basalt(vec2 p) {
 float layer = p.y * 4.0 + 0.22 * sin(p.x * 2.8);
 float column = p.x * 3.1 + floor(layer) * 0.37 + 0.13 * sin(p.y * 5.0);
 vec2 f = fract(vec2(column, layer));
 float split = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
 float crack = 1.0 - smoothstep(0.018, 0.05 + length(fwidth(p)), split);
 float facet = step(f.x * 0.7, f.y) * 0.5 + 0.25 * sin(floor(column) * 4.7 + floor(layer));
 vec3 rock = mix(vec3(0.12,0.105,0.17), vec3(0.31,0.24,0.32), facet + 0.3);
 float mineral = smoothstep(0.85, 0.98, sin(p.x * 1.8 + p.y * 3.5));
 rock = mix(rock, vec3(0.17,0.40,0.39), mineral * 0.45);
 return vec4(mix(rock, vec3(0.065,0.045,0.08), crack * 0.6), crack);
}
void fragment() {
 vec2 weights = pow(abs(world_normal.xz), vec2(6.0));
 weights /= max(weights.x + weights.y, 0.001);
 vec4 rock = basalt(world_position.zy) * weights.x + basalt(world_position.xy) * weights.y;
 float depth = max(top_height - world_position.y, 0.0);
 float lip = 1.0 - smoothstep(0.025, 0.075, depth);
 ALBEDO = mix(rock.rgb, vec3(0.42,0.48,0.46), lip * 0.8);
 // Fixed low-frequency bounce suggests the lake beneath; it is not a light per crack.
 float warm = smoothstep(0.22, 1.6, depth);
 float fissure = rock.a * smoothstep(0.64, 0.94, sin(world_position.x * 3.0 + world_position.z * 2.7 + depth));
 EMISSION = ALBEDO * 0.12 + vec3(0.26,0.04,0.008) * warm * (0.3 + fissure);
 ROUGHNESS = 0.94;
}
