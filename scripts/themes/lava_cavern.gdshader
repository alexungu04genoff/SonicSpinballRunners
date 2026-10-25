shader_type spatial;
render_mode specular_disabled;
#include "res://scripts/themes/lava_rock.gdshaderinc"
uniform vec4 rock_color : source_color = vec4(0.08,0.25,0.20,1.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec3 weights = pow(abs(world_normal),vec3(4.0));
 weights /= max(dot(weights,vec3(1.0)),0.001);
 vec3 boulder = reef_boulder(world_position.zy*0.8)*weights.x + reef_boulder(world_position.xz*0.8)*weights.y + reef_boulder(world_position.xy*0.8)*weights.z;
 ALBEDO = mix(vec3(0.025,0.018,0.085),rock_color.rgb,boulder.r);
 float bounce = 1.0-smoothstep(-7.2,-1.0,world_position.y);
 EMISSION = ALBEDO*0.18 + vec3(0.12,0.022,0.005)*bounce;
 ROUGHNESS = 1.0;
}
