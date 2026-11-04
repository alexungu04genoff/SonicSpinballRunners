shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform bool raised_surface = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 // Broad cobalt lacquer tiles and ivory terrace inlays keep the routes readable.
 vec2 p = world_position.xz * 1.2;
 vec2 q = fract(p) - 0.5;
 vec2 edge = 0.5 - abs(q);
 float aa = max(length(fwidth(p)), 0.004);
 float seam = 1.0 - smoothstep(0.012, 0.012 + aa, min(edge.x, edge.y));
 float inset = 1.0 - smoothstep(0.014, 0.014 + aa, abs(max(abs(q.x), abs(q.y)) - 0.40));
 float cell = mod(floor(p.x) + floor(p.y), 4.0);
 vec3 base = mix(vec3(0.10, 0.21, 0.47), vec3(0.15, 0.29, 0.56), cell / 4.0);
 if (raised_surface) { base = mix(vec3(0.62, 0.52, 0.35), vec3(0.76, 0.66, 0.48), cell / 4.0); }
 float angle = atan(q.x, q.y);
 float star_radius = 0.13 + 0.055 * cos(angle * 5.0);
 float star = (1.0 - smoothstep(star_radius, star_radius + aa, length(q))) * step(2.5, cell);
 base = mix(base, raised_surface ? vec3(0.48, 0.28, 0.12) : vec3(0.24, 0.38, 0.64), star * (raised_surface ? 0.45 : 0.35));
 base = mix(base, vec3(0.48, 0.31, 0.10), inset * (raised_surface ? 0.65 : 0.16));
 ALBEDO = mix(base, raised_surface ? vec3(0.30, 0.22, 0.12) : vec3(0.045, 0.10, 0.26), seam * 0.50);
 // Short, sparse blue inserts rather than bright lines beneath every ring.
 float strip = (1.0 - smoothstep(0.017, 0.017 + aa, abs(q.y - 0.43))) * (1.0 - smoothstep(0.12, 0.12 + aa, abs(q.x))) * step(2.5, cell);
 EMISSION = vec3(0.045, 0.12, 0.40) * strip * 0.42;
 if (raised_surface) {
  float ledge_strip = (1.0 - smoothstep(0.03, 0.03 + aa, abs(q.y - 0.43))) * (1.0 - smoothstep(0.28, 0.28 + aa, abs(q.x)));
  EMISSION = vec3(1.0, 0.04, 0.18) * ledge_strip * 1.6;
 }
 ROUGHNESS = 0.78;
}
