shader_type spatial;
uniform vec2 center = vec2(0.0);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_position.xz - center;
 float bend = sin(p.x * 0.17 + TIME * 0.075) * 1.8 + sin(p.x * 0.31 - TIME * 0.045) * 0.6;
 float band = exp(-pow((p.y + 8.0 + bend) * 0.24, 2.0));
 band += exp(-pow((p.y - 6.0 + bend * 1.4) * 0.17, 2.0)) * 0.30;
 float ripples = 0.72 + sin(p.y * 4.0 + sin(p.x * 0.6) + TIME * 0.08) * 0.16;
 // Art-directed, distorted aurora reflection, not a screen-space reflection.
 ALBEDO = vec3(0.04, 0.07, 0.13);
 EMISSION = vec3(0.025, 0.14, 0.12) * band * ripples * 1.2;
 ROUGHNESS = 0.25;
 SPECULAR = 0.8;
}
