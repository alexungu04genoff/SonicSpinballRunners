shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 repeat_size = vec2(4.0);
uniform float grass_bump = 0.0025;
uniform float grass_density = 65.0;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_position.xz*grass_density;
 // Fade fine relief as its cells become smaller than a screen pixel.
 float fade=1.0-smoothstep(0.3,1.2,max(length(dFdx(p)),length(dFdy(p))));
 float h=(noise(p)*0.7+noise(p*2.07)*0.3)*grass_bump*fade;
 vec3 dx=dFdx(VERTEX), dy=dFdy(VERTEX);
 vec3 r1=cross(dy,NORMAL), r2=cross(NORMAL,dx);
 float determinant=dot(dx,r1);
 if(abs(determinant)>0.00000001) {
  vec3 gradient=(r1*dFdx(h)+r2*dFdy(h))/determinant;
  NORMAL=normalize(NORMAL-gradient);
 }
 ALBEDO=texture(surface_texture,world_position.xz/repeat_size).rgb;
 ROUGHNESS=1.0;
}
