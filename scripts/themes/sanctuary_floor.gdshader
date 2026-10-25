shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform bool raised_surface = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 // Broad limestone slabs, not turf. Joints and inlays are filtered at distance.
 vec2 p = world_position.xz * vec2(2.0, 2.8);
 p.x += mod(floor(p.y), 2.0) * 0.5;
 vec2 cell = floor(p);
 vec2 edge = min(fract(p), 1.0 - fract(p));
 float aa = max(length(fwidth(p)), 0.008);
 float joint = 1.0 - smoothstep(0.012, 0.012 + aa, min(edge.x, edge.y));
 float tint = mod(cell.x * 3.0 + cell.y * 7.0, 7.0) / 6.0;
 vec3 stone = mix(vec3(0.49, 0.55, 0.54), vec3(0.59, 0.60, 0.54), tint);
 if (raised_surface) stone = mix(vec3(0.69, 0.73, 0.65), vec3(0.80, 0.78, 0.66), tint);
 float moss = step(0.69, tint) * joint;
 stone = mix(stone, vec3(0.22, 0.35, 0.16), moss * 0.75);
 stone = mix(stone, vec3(0.26, 0.34, 0.32), joint * 0.42);
 // Rare blue inlaid tablets stay subdued, so rings remain the brightest marks.
 float tablet = (1.0 - step(0.5, mod(cell.x + cell.y * 3.0, 19.0))) *
  smoothstep(0.10, 0.10 + aa, edge.x) * smoothstep(0.14, 0.14 + aa, edge.y);
 ALBEDO = mix(stone, vec3(0.055, 0.19, 0.28), tablet * 0.8);
 ROUGHNESS = mix(0.94, 0.32, tablet);
}
