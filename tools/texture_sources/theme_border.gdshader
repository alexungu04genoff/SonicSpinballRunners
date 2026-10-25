shader_type canvas_item;
render_mode unshaded;
uniform int theme = 0;
uniform bool raised = false;
uniform int bake_channel = 0;
uniform float emission_scale = 1.0;
void fragment() {
 vec2 p = UV;
 vec3 color = vec3(0.5);
 vec3 glow = vec3(0.0);
 vec3 properties = vec3(0.85, 0.0, 0.0);
 float edge = min(p.y, 1.0 - p.y);
 float joint = 1.0 - smoothstep(0.01, 0.025, min(fract(p.x * 4.0), 1.0 - fract(p.x * 4.0)));
 float bevel = smoothstep(0.0, 0.14, edge);
 if (theme == 0) {
  color = mix(vec3(0.025, 0.04, 0.06), vec3(0.65, 0.43, 0.035), step(0.5, fract(p.x * 8.0 + p.y * 0.5)));
  color = mix(vec3(0.29, 0.38, 0.46), color, smoothstep(0.12, 0.18, edge));
  color *= 1.0 - joint * 0.22;
 } else if (theme == 1) {
  color = mix(vec3(0.25, 0.12, 0.035), vec3(0.65, 0.40, 0.12), bevel);
  float inset = smoothstep(0.26, 0.32, edge);
  color = mix(color, raised ? vec3(0.40, 0.035, 0.07) : vec3(0.04, 0.12, 0.28), inset);
  glow = (raised ? vec3(0.6, 0.02, 0.07) : vec3(0.02, 0.16, 0.5)) * inset * (1.0 - joint);
  properties = vec3(0.55, 0.0, 0.0);
 } else if (theme == 2) {
  color = mix(vec3(0.34, 0.42, 0.32), raised ? vec3(0.76, 0.73, 0.55) : vec3(0.57, 0.62, 0.49), bevel);
  color = mix(color, vec3(0.22, 0.32, 0.23), joint * 0.65);
 } else if (theme == 3) {
  float snow = smoothstep(0.18, 0.30, p.y + sin(p.x * 25.13274123) * 0.04);
  color = mix(vec3(0.14, 0.35, 0.50), vec3(0.64, 0.76, 0.84), snow) * mix(0.8, 1.0, bevel);
  properties = vec3(mix(0.23, 0.94, snow), mix(0.8, 0.18, snow), 0.0);
 } else if (theme == 4) {
  color = mix(vec3(0.25, 0.09, 0.20), raised ? vec3(0.77, 0.53, 0.25) : vec3(0.57, 0.37, 0.22), bevel * (1.0 - joint));
  glow = color * 0.12;
  properties.r = 0.96;
 } else {
  color = mix(vec3(0.20, 0.26, 0.27), raised ? vec3(0.46, 0.32, 0.13) : vec3(0.36, 0.48, 0.47), bevel);
  color *= 1.0 - joint * 0.35;
  properties = vec3(0.45, 0.6, 0.0);
 }
 COLOR = vec4(bake_channel == 0 ? color : (bake_channel == 1 ? glow / emission_scale : properties), 1.0);
}
