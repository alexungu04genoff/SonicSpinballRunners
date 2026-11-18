shader_type spatial;
// Process-local Theme Motion candidate; zero preserves current production.
uniform int motion_candidate = 0;
uniform float time_override = -1.0;
float theme_time() { return time_override >= 0.0 ? time_override : TIME; }
// Linear palette uniforms preserve the original shader constants.
uniform vec3 deep_color = vec3(0.055, 0.025, 0.15);
uniform vec3 ripple_color = vec3(0.16, 0.035, 0.24);
render_mode unshaded, cull_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 // Cosmetic bands only; no fluid physics, screen refraction, or extra pass.
 vec2 p = world_position.xz;
 float ripple = sin(p.x * 3.2 + p.y * 1.7 + theme_time() * 0.65) * 0.5 + 0.5;
 // A carries broad feed lanes downstream; B circulates slow eddies within them.
 if (motion_candidate == 1) ripple = 0.5 + 0.5 * sin(p.y * 0.95 - theme_time() * 0.42 + sin(p.x * 0.7) * 0.8);
 if (motion_candidate == 2) {
  vec2 cell = mod(p + vec2(4.0), vec2(8.0)) - vec2(4.0);
  float radius = length(cell);
  float angle = atan(cell.y, cell.x);
  float eddy = sin(radius * 1.8 - angle * 2.0 + theme_time() * 0.52);
  float fade = 1.0 - smoothstep(2.3, 3.8, radius);
  ripple = mix(ripple, 0.5 + 0.5 * eddy, fade * 0.8);
 }
 vec3 liquid = mix(deep_color, ripple_color, ripple * 0.35);
 ALBEDO = liquid;
}
