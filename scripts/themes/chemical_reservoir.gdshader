shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 // Cosmetic bands only; no fluid physics, screen refraction, or extra pass.
 float ripple = sin(world_position.x * 3.2 + world_position.z * 1.7 + TIME * 0.65) * 0.5 + 0.5;
 vec3 liquid = mix(vec3(0.055, 0.025, 0.15), vec3(0.16, 0.035, 0.24), ripple * 0.35);
 ALBEDO = liquid;
}
