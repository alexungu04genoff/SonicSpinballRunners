shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float top_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 carved_stone(vec2 p, float depth) {
 vec2 blocks = p * vec2(2.8, 4.8);
 blocks.x += mod(floor(blocks.y), 2.0) * 0.5;
 vec2 edge = min(fract(blocks), 1.0 - fract(blocks));
 float aa = max(length(fwidth(blocks)), 0.008);
 float mortar = 1.0 - smoothstep(0.018, 0.018 + aa, min(edge.x, edge.y));
 float tint = mod(floor(blocks.x) * 3.0 + floor(blocks.y) * 5.0, 7.0) / 6.0;
 vec3 stone = mix(vec3(0.57, 0.64, 0.59), vec3(0.79, 0.77, 0.61), tint);
 stone = mix(stone, vec3(0.31, 0.40, 0.38), mortar * 0.52);
 // Recesses, pilaster ribs and cornices follow any authored side, including curves.
 float bay = abs(fract(p.x / 0.85) - 0.5);
 float shaft = smoothstep(0.27, 0.31, bay);
 float flute = 0.5 + 0.5 * cos(p.x * 150.0);
 stone = mix(stone, vec3(0.52, 0.64, 0.44) * (0.85 + flute * 0.15), shaft * 0.65);
 float panel = (1.0 - smoothstep(0.18, 0.22, bay)) * smoothstep(0.22, 0.28, depth) * (1.0 - smoothstep(1.12, 1.2, depth));
 stone *= 1.0 - panel * 0.24;
 float band = 1.0 - smoothstep(0.025, 0.045, abs(mod(depth, 0.72) - 0.12));
 stone = mix(stone, vec3(0.83, 0.77, 0.48), band * 0.68);
 float vine_x = abs(fract(p.x * 3.1 + sin(depth * 9.0) * 0.07) - 0.5);
 float vine = (1.0 - smoothstep(0.02, 0.055, vine_x)) * (1.0 - smoothstep(0.15, 1.15, depth));
 stone = mix(stone, vec3(0.19, 0.36, 0.15), vine * 0.85);
 float lip = 1.0 - smoothstep(0.04, 0.065, depth);
 return mix(stone, vec3(0.88, 0.86, 0.71), lip);
}
void fragment() {
 vec2 weights = pow(abs(world_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 float depth = top_height - world_position.y;
 ALBEDO = carved_stone(world_position.zy, depth) * weights.x + carved_stone(world_position.xy, depth) * weights.y;
 ROUGHNESS = 0.96;
}
