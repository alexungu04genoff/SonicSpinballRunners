shader_type spatial;
// Linear palette uniforms preserve the original shader constants.
uniform vec3 deep_color = vec3(0.08, 0.32, 0.36);
uniform vec3 reflection_color = vec3(0.16, 0.48, 0.52);
render_mode specular_disabled;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 float ripple = sin(world_position.z * 3.0 + sin(world_position.x * 1.7) + TIME * 0.45);
 ALBEDO = mix(deep_color, reflection_color, ripple * 0.5 + 0.5);
 ROUGHNESS = 0.34;
}
