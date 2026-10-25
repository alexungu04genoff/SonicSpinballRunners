shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform bool raised_surface = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 // Large staggered slabs, with derivative-filtered mortar. No sampled textures.
 vec2 p = world_position.xz * vec2(2.0, 3.2);
 p.x += mod(floor(p.y), 2.0) * 0.5;
 vec2 cell = floor(p);
 vec2 edge = min(fract(p), 1.0 - fract(p));
 float aa = max(length(fwidth(p)), 0.005);
 float joint = 1.0 - smoothstep(0.012, 0.012 + aa, min(edge.x, edge.y));
 float variation = mod(cell.x * 3.0 + cell.y * 7.0, 5.0) / 4.0;
 vec3 stone = mix(vec3(0.44, 0.43, 0.39), vec3(0.50, 0.49, 0.44), variation);
 if (raised_surface) {
  stone = mix(vec3(0.66, 0.22, 0.075), vec3(0.79, 0.33, 0.12), variation);
 }
 ALBEDO = mix(stone, raised_surface ? vec3(0.40, 0.14, 0.065) : vec3(0.40, 0.34, 0.26), joint * 0.48);
 ROUGHNESS = 0.94;
}
