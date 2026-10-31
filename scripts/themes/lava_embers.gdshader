shader_type spatial;
// Linear palette uniforms preserve the original shader constants.
uniform vec3 ember_color = vec3(0.65,0.14,0.035);
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float review_time = -1.0;
void vertex() {
 // Instances start below and outside the deck. No particles cross the play area.
 float time = review_time < 0.0 ? TIME : review_time;
 VERTEX.y += mod(time * 0.27 + float(INSTANCE_ID) * 0.31, 3.2);
 VERTEX.x += sin(time * 0.45 + float(INSTANCE_ID) * 2.3) * 0.13;
}
void fragment() { ALBEDO = ember_color; }
