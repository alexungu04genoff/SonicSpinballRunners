shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float turf_height = 0.30;
varying vec3 terrain_position;
varying vec3 terrain_normal;
void vertex() {
 terrain_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 // Triplanar checker soil wraps both straight and curved walls without stretching.
 vec3 tile = terrain_position * 6.25;
 float checker_x = mod(floor(tile.z) + floor(tile.y), 2.0);
 float checker_z = mod(floor(tile.x) + floor(tile.y), 2.0);
 vec2 weights = pow(abs(terrain_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 float checker = dot(vec2(checker_x, checker_z), weights);
 vec3 soil = mix(vec3(0.30, 0.095, 0.025), vec3(0.72, 0.32, 0.075), checker);
 float fringe = abs(fract((terrain_position.x + terrain_position.z) * 24.0) - 0.5) * 0.045;
 float depth = turf_height - terrain_position.y;
 vec3 grass = mix(vec3(0.13, 0.39, 0.025), vec3(0.49, 0.79, 0.035), 1.0 - smoothstep(0.0, 0.08, depth));
 ALBEDO = mix(soil, grass, step(depth, 0.065 + fringe));
 ROUGHNESS = 1.0;
}
