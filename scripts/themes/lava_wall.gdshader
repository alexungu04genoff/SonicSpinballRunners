shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://scripts/themes/lava_rock.gdshaderinc"
uniform float top_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 vec2 weights = pow(abs(world_normal.xz),vec2(6.0));
 weights /= max(weights.x+weights.y,0.001);
 vec3 rock = reef_boulder(world_position.zy*2.5)*weights.x + reef_boulder(world_position.xy*2.5)*weights.y;
 float depth = max(top_height-world_position.y,0.0);
 ALBEDO = rock;
 EMISSION = ALBEDO*0.14 + vec3(0.12,0.018,0.005)*smoothstep(0.4,1.6,depth);
 ROUGHNESS = 0.94;
}
