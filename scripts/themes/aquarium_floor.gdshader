shader_type spatial;
// Quiet polished slate, wave inlays and lacquered raised walkways.
uniform bool raised_surface = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_position.xz;
 vec2 tiles = p * vec2(1.15, 0.80);
 tiles.x += mod(floor(tiles.y), 2.0) * 0.5;
 vec2 q = fract(tiles);
 vec2 edge = min(q, 1.0-q);
 float aa = max(length(fwidth(tiles)), 0.005);
 float seam = 1.0-smoothstep(0.014, 0.014+aa, min(edge.x, edge.y));
 float tone = mod(floor(tiles.x)+floor(tiles.y), 3.0)/2.0;
 vec3 slate = mix(vec3(0.18,0.29,0.34), vec3(0.23,0.35,0.39), tone);
 float wave = abs(sin(p.x*2.0 + sin(p.y*1.4)*0.5));
 float inlay = (1.0-smoothstep(0.03,0.03+fwidth(wave),wave))*0.10;
 vec3 color = mix(slate, vec3(0.10,0.18,0.23), seam)+inlay*vec3(0.3,0.6,0.55);
 if (raised_surface) {
  float plank = 1.0-smoothstep(0.018,0.018+aa,min(fract(p.y*4.0),1.0-fract(p.y*4.0)));
  color = mix(vec3(0.48,0.25,0.23),vec3(0.24,0.12,0.15),plank);
 }
 ALBEDO = color;
 ROUGHNESS = raised_surface ? 0.37 : 0.29;
 SPECULAR = 0.65;
 EMISSION = vec3(0.012,0.022,0.026);
}
