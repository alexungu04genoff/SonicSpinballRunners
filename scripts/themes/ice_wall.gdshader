shader_type spatial;
render_mode cull_disabled;
uniform float top_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 glacier(vec2 p, float depth) {
 float column = p.x * 1.85 + p.y * 0.38 + sin(p.y * 1.3) * 0.14;
 float shelf = fract(p.y * 1.3 + floor(column) * 0.27);
 float facet = mix(0.22, 0.72, step(fract(column), shelf));
 vec3 color = mix(vec3(0.055, 0.15, 0.31), vec3(0.20, 0.52, 0.69), facet);
 color = mix(color, vec3(0.21, 0.35, 0.57), step(0.63, shelf) * 0.35);
 float seam = 1.0 - smoothstep(0.012, 0.04 + fwidth(column), min(fract(column), 1.0 - fract(column)));
 color += vec3(0.06, 0.13, 0.15) * seam;
 // Snow accumulates on the existing mesh, never outside the collision silhouette.
 float lip_depth = 0.035 + 0.028 * sin(p.x * 8.0) + 0.018 * sin(p.x * 19.0);
 float lip = 1.0 - smoothstep(lip_depth, lip_depth + 0.025, depth);
 return mix(color, vec3(0.80, 0.90, 0.95), lip);
}
void fragment() {
 vec2 weights = pow(abs(world_normal.xz), vec2(6.0));
 weights /= max(weights.x + weights.y, 0.001);
 float depth = top_height - world_position.y;
 ALBEDO = pow(glacier(world_position.zy, depth) * weights.x + glacier(world_position.xy, depth) * weights.y, vec3(1.35));
 ROUGHNESS = depth < 0.05 ? 0.93 : 0.24;
 SPECULAR = depth < 0.05 ? 0.18 : 0.8;
 EMISSION = ALBEDO * 0.055;
}
