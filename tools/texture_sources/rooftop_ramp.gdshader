shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec4 base_color : source_color;
uniform vec4 alternate_color : source_color;
uniform int surface_kind = 0;
// UV is measured in world units: cross-deck distance and distance along the route.
void fragment() {
 vec2 p = UV;
 float shade = 0.0;
 float seam = 1.0;
 if (surface_kind == 0) {
  float plank = floor(p.y / 0.13);
  shade = 0.35 + 0.18 * sin(plank * 2.4) + 0.07 * sin(p.x * 170.0 + sin(p.y * 13.0));
  float edge = min(fract(p.y / 0.13), 1.0 - fract(p.y / 0.13));
  seam = smoothstep(0.0, 0.055, edge);
 } else if (surface_kind == 1) {
  vec2 panel = fract(p / vec2(0.18, 0.24));
  vec2 edge = min(panel, 1.0 - panel);
  seam = smoothstep(0.0, 0.04, min(edge.x, edge.y));
  vec2 diamond = abs(fract((p.x + p.y) * 32.0) - 0.5) * vec2(1.0);
  shade = 0.30 + 0.18 * step(0.42, diamond.x);
 } else {
  p.x += mod(floor(p.y / 0.22), 2.0) * 0.12;
  vec2 tile = p / vec2(0.24, 0.22);
  vec2 edge = min(fract(tile), 1.0 - fract(tile));
  seam = smoothstep(0.0, 0.045, min(edge.x, edge.y));
  shade = 0.3 + 0.25 * mod(floor(tile.x) + floor(tile.y), 2.0);
 }
 ALBEDO = mix(base_color.rgb, alternate_color.rgb, shade) * mix(0.58, 1.0, seam);
 ROUGHNESS = 0.9;
}
