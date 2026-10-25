shader_type spatial;
render_mode cull_disabled;
uniform float top_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec4 facade(vec2 p) {
 vec2 q = fract(p*vec2(1.1,1.6));
 float aa = max(length(fwidth(p)),0.005);
 float pillar = 1.0-smoothstep(0.045,0.045+aa,min(q.x,1.0-q.x));
 float band = 1.0-smoothstep(0.055,0.055+aa,min(q.y,1.0-q.y));
 vec3 stone = mix(vec3(0.035,0.080,0.11),vec3(0.15,0.052,0.047),pillar);
 stone = mix(stone,vec3(0.22,0.25,0.25),band);
 float inset = smoothstep(0.25,0.3,q.x)*(1.0-smoothstep(0.7,0.75,q.x));
 inset *= smoothstep(0.40,0.45,q.y)*(1.0-smoothstep(0.6,0.65,q.y));
 return vec4(stone,inset);
}
void fragment() {
 vec2 weights = pow(abs(world_normal.xz),vec2(8.0));
 weights /= max(weights.x+weights.y,0.001);
 vec4 wall = facade(world_position.zy)*weights.x+facade(world_position.xy)*weights.y;
 float depth = top_height-world_position.y;
 float trim = 1.0-smoothstep(0.018,0.028,abs(depth-0.065));
 ALBEDO = mix(wall.rgb,vec3(0.38,0.30,0.15),trim);
 EMISSION = vec3(0.015,0.14,0.17)*wall.a;
 ROUGHNESS = 0.62;
}
