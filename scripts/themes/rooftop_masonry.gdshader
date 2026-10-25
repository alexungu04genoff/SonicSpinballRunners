shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float top_height = 0.325;
uniform bool facade = false;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 masonry(vec2 position, float depth) {
 vec2 p = position * vec2(3.0, 6.0);
 p.x += mod(floor(p.y), 2.0) * 0.5;
 vec2 edge = min(fract(p), 1.0 - fract(p));
 float aa = max(length(fwidth(p)), 0.005);
 float joint = 1.0 - smoothstep(0.018, 0.018 + aa, min(edge.x, edge.y));
 float tint = mod(floor(p.x) + floor(p.y) * 3.0, 4.0) / 3.0;
 vec3 color = mix(vec3(0.68, 0.57, 0.40), vec3(0.76, 0.66, 0.49), tint);
 color = mix(color, vec3(0.44, 0.37, 0.28), joint * 0.45);
 if (facade) {
  // Shallow arched recesses below the deck sell a building on any silhouette.
  vec2 bay = vec2(fract(position.x / 0.85) - 0.5, depth - 0.64);
  float arch = max(abs(bay.x) - 0.22, max(-bay.y - 0.13, bay.y - 0.55));
  if (bay.y < 0.0) arch = max(arch, length(vec2(bay.x, bay.y)) - 0.22);
  float recess = 1.0 - smoothstep(0.0, aa * 0.15, arch);
  float trim = 1.0 - smoothstep(0.035, 0.035 + aa * 0.15, arch);
  color = mix(color, vec3(0.86, 0.74, 0.55), trim);
  color = mix(color, vec3(0.22, 0.30, 0.28), recess);
  float sill = 1.0 - smoothstep(0.025, 0.04, abs(depth - 1.21));
  color = mix(color, vec3(0.80, 0.68, 0.49), sill);
 }
 float cornice = 1.0 - smoothstep(0.045, 0.060, depth);
 color = mix(color, vec3(0.94, 0.81, 0.58), cornice);
 float shadow_line = smoothstep(0.055, 0.063, depth) * (1.0 - smoothstep(0.078, 0.090, depth));
 return mix(color, vec3(0.43, 0.28, 0.16), shadow_line);
}
void fragment() {
 vec2 weights = pow(abs(world_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 float depth = top_height - world_position.y;
 ALBEDO = masonry(world_position.zy, depth) * weights.x + masonry(world_position.xy, depth) * weights.y;
 ROUGHNESS = 0.95;
}
