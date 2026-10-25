shader_type spatial;
render_mode cull_back, depth_draw_opaque;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
 float fresnel = pow(1.0-max(dot(NORMAL,VIEW),0.0),3.0);
 float streak = pow(max(0.0,sin(local_position.x*6.0+local_position.z*3.0)),20.0);
 ALBEDO = vec3(0.015,0.32,0.43);
 EMISSION = vec3(0.03,0.28,0.40)*(0.8+fresnel*0.5)+streak*vec3(0.12,0.24,0.27);
 ALPHA = 0.32+fresnel*0.25+streak*0.045;
 ROUGHNESS = 0.12;
 SPECULAR = 0.8;
}
