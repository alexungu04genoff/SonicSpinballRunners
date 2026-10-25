shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform bool raised_surface = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
 // Offset, irregular polygon slabs: broad mineral faces, never molten routes.
 vec2 p = world_position.xz * 2.3;
 vec2 cell = floor(p);
 float first = 8.0, second = 8.0, tone = 0.0;
 for (int y = -1; y <= 1; y++) {
  for (int x = -1; x <= 1; x++) {
   vec2 id = cell + vec2(float(x), float(y));
   vec2 site = id + vec2(0.5) + vec2(hash(id), hash(id + 19.0)) * 0.90 - 0.45;
   float d = dot(p - site, p - site);
   if (d < first) { second = first; first = d; tone = hash(id + 41.0); }
   else { second = min(second, d); }
  }
 }
 float seam = 1.0 - smoothstep(0.015, 0.055 + fwidth(first), second - first);
 vec3 stone = mix(vec3(0.23,0.22,0.29), vec3(0.32,0.30,0.37), tone);
 if (raised_surface) { stone = mix(vec3(0.32,0.40,0.40), vec3(0.47,0.51,0.47), tone); }
 float face = step(fract(p.x + p.y * 0.55), 0.47) * 0.005;
 ALBEDO = mix(stone + face, vec3(0.12,0.115,0.17), seam * 0.45);
 EMISSION = ALBEDO * 0.13;
 ROUGHNESS = 0.96;
}
