shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// Original bounded-cost curtain: no raymarch, texture reads, or per-frame CPU work.
uniform float phase = 0.0;
uniform float strength = 0.65;
void vertex() {
 float wave = sin(UV.x * 13.0 + TIME * 0.075 + phase);
 VERTEX.y += wave * 1.8 + sin(UV.x * 24.0 - TIME * 0.045) * 0.6;
 VERTEX.z += sin(UV.x * 10.0 + TIME * 0.055 + phase) * 3.0;
}
void fragment() {
 float edge = 0.73 + sin(UV.x * 12.0 + TIME * 0.075 + phase) * 0.07;
 float height = edge - UV.y;
 float curtain = smoothstep(-0.035, 0.035, height) * exp(-max(height, 0.0) * 6.0);
 float folds = 0.64 + 0.22 * sin(UV.x * 91.0 + sin(UV.x * 21.0 + TIME * 0.06) * 3.0);
 folds += 0.10 * sin(UV.x * 169.0 - TIME * 0.025);
 float ends = smoothstep(0.0, 0.10, UV.x) * smoothstep(0.0, 0.10, 1.0 - UV.x);
 vec3 color = mix(vec3(0.05, 0.95, 0.32), vec3(0.14, 0.52, 0.80), clamp(height * 4.0, 0.0, 1.0));
 color = mix(color, vec3(0.57, 0.23, 0.62), smoothstep(0.24, 0.52, height));
 ALBEDO = color;
 ALPHA = curtain * folds * ends * strength;
}
