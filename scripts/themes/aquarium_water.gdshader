shader_type spatial;
render_mode cull_disabled;
// Opaque deep water avoids sorted transparency over the full park. Tank walls
// use a separate transparent shell. Broad waves survive the retro world buffer.
uniform float radiance = 0.15;
uniform float time_override = -1.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float t = time_override >= 0.0 ? time_override : TIME;
 vec2 p = world_position.xz;
 p += vec2(sin(p.y*0.23),sin(p.x*0.27))*1.3;
 float a = sin(p.x*1.5+p.y*0.8+t*0.35);
 float b = sin(p.y*2.1-p.x*0.4-t*0.24+0.4*a);
 float ripple = a*0.6+b*0.4;
 NORMAL = normalize(NORMAL+vec3(a*0.045,b*0.035,0.0));
 float fresnel = pow(1.0-max(dot(NORMAL,VIEW),0.0),3.0);
 vec3 deep = mix(vec3(0.012,0.070,0.105),vec3(0.018,0.12,0.17),0.5+0.5*ripple);
 float caustic = pow(max(0.0,1.0-abs(a+b)*1.5),5.0);
 // Broken, broad reflection ribbons suggest distant amber lantern rows.
 float reflection = pow(max(0.0,sin(p.x*0.65+0.12*ripple)),18.0);
 reflection *= 0.35+0.65*pow(0.5+0.5*sin(p.y*4.0+t*0.3+a),3.0);
 ALBEDO = deep;
 EMISSION = deep*radiance+vec3(0.03,0.17,0.20)*caustic*0.22;
 EMISSION += vec3(0.10,0.22,0.29)*fresnel+vec3(0.28,0.10,0.025)*reflection*0.35;
 ROUGHNESS = 0.16;
 SPECULAR = 0.85;
 METALLIC = 0.22;
}
