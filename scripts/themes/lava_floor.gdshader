shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://scripts/themes/lava_rock.gdshaderinc"
uniform bool raised_surface = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 // The same boulder vocabulary stays quieter on the rolling plane.
 vec3 rock = reef_boulder(world_position.xz*2.1);
 ALBEDO = mix(vec3(0.38,0.25,0.24),rock*0.74,raised_surface ? 0.86 : 0.60);
 EMISSION = ALBEDO*0.12;
 ROUGHNESS = 0.96;
}
