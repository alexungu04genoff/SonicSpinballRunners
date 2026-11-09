// Appended to the albedo source so structural coordinates remain identical.
uniform int output_map = 0;
uniform vec2 pixel_size = vec2(0.001953125);
uniform float normal_gain = 0.006;
uniform float mortar_depth = 0.65;
uniform float bevel_width = 0.085;
uniform float face_variation = 0.025;

float block_height(vec2 p) {
 vec2 f=fract(p);
 float d=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
 float rise=clamp((d-0.020)/bevel_width,0.0,1.0);
 return (1.0-mortar_depth)+mortar_depth*rise;
}
float stone_field(vec2 uv,vec2 count) {
 vec2 p=uv*count;
 p.x+=mod(floor(p.y),2.0)*0.5;
 return block_height(p);
}
float structure_height(vec2 uv) {
 if(item==1) {
  vec2 p=uv*vec2(8.0,10.0);
  p.x+=mod(floor(p.y),2.0)*0.5;
  float h=block_height(p);
  // Restrained planar top tilt, gated away from the mortar.
  float face=(fract(p.x)-0.5)*(variation(floor(p),vec2(8.0,10.0))-0.5);
  return h+face*face_variation*step(0.98,h);
 }
 if(item==2) {
  // Relief follows the same scattered blades as the albedo, with no sine waves.
  return 0.15+0.78*grass_cluster(uv).y+0.025*turf_noise(uv,67.0);
 }
 if(item==10) return 0.25+0.42*turf_noise(uv,9.0)+0.18*turf_noise(uv,21.0)+0.07*turf_noise(uv,43.0);
 if(item==3) {
  // Exact coordinates of the retained wall bake, including its cream cap band.
  float depth=uv.y*1.45;
  if(depth<0.045) return 0.88;
  if(depth<0.090) return mix(0.88,0.80,smoothstep(0.045,0.090,depth));
  vec2 p=vec2(uv.x*12.0,(0.325-depth)*6.0);
  p.x+=mod(floor(p.y),2.0)*0.5;
  return block_height(p);
 }
 if(item==5) {
  vec2 p=uv*vec2(12.0,10.0);
  float x=fract(p.x);
  float curve=0.12+0.14*pow(x*2.0-1.0,2.0);
  float seam=min(edge(p.x),edge(p.y-curve));
  float rise=clamp((seam-0.016)/0.07,0.0,1.0);
  // A broad pitched profile gives tile faces readable planar lighting.
  float crown=1.0-abs(x*2.0-1.0);
  return 0.35+0.35*rise+0.28*crown*rise;
 }
 if(item==6) {
  vec2 q=abs(fract(uv*vec2(4.0,1.0))-0.5);
  vec2 corner=max(q-vec2(0.35,0.31),vec2(0.0));
  float d=length(corner)-0.12;
  return 0.35+0.65*clamp((-d-0.005)/0.065,0.0,1.0);
 }
 if(item==7) return stone_field(uv,vec2(8.0));
 if(item==8) {
  float seam=clamp((edge(uv.x*2.0)-0.006)/0.025,0.0,1.0);
  return mix(0.72+seam*0.025,0.79,1.0-smoothstep(0.105,0.125,uv.y));
 }
 if(item==9) {
  float h=stone_field(uv,vec2(8.0,6.0));
  vec2 bay=vec2(fract(uv.x*2.0)-0.5,uv.y-0.46);
  float d=arch_distance(bay);
  // Window panes remain planar; only the architectural surround has relief.
  if(d<0.0) return 0.45;
  if(d<0.030) return 0.80+0.20*clamp(min(d,0.030-d)/0.009,0.0,1.0);
  float sill=max(abs(bay.x)-0.24,abs(bay.y-0.265)-0.017);
  if(sill<0.0) return 0.90;
  return h;
 }
 return 0.5;
}
vec3 property_values(vec2 uv,float h) {
 float roughness=0.86;
 float metallic=0.0;
 float cavity=1.0-0.13*(1.0-smoothstep(0.35,0.85,h));
 if(item==1) roughness=0.84+0.06*(1.0-h);
 if(item==2 || item==10) {roughness=0.96; cavity=mix(0.92,1.0,smoothstep(0.3,0.7,h));}
 if(item==3 || item==6) roughness=0.88;
 if(item==5) roughness=0.78+0.10*(1.0-h);
 if(item==7) roughness=0.83+0.06*(1.0-h);
 if(item==8) {
  roughness=uv.y<0.11 ? 0.86:0.57;
  // Teal paint is dielectric. Exposed narrow panel joints reveal underlying metal.
  metallic=(1.0-smoothstep(0.003,0.006,edge(uv.x*2.0)))*step(0.12,uv.y);
  cavity=0.98;
 }
 if(item==9) {
  vec2 bay=vec2(fract(uv.x*2.0)-0.5,uv.y-0.46);
  if(arch_distance(bay)<0.0) {roughness=0.48; cavity=1.0;}
 }
 return vec3(roughness,metallic,cavity);
}
void fragment() {
 vec2 uv=UV;
 float h=structure_height(uv);
 vec3 props=property_values(uv,h);
 vec3 color=vec3(h);
 if(output_map==1) {
  vec2 down=uv-vec2(0.0,pixel_size.y);
  vec2 up=uv+vec2(0.0,pixel_size.y);
  if(item==3 || item==6 || item==8 || item==9) {
   down.y=clamp(down.y,0.0,1.0); up.y=clamp(up.y,0.0,1.0);
  }
  float dx=(structure_height(uv+vec2(pixel_size.x,0.0))-structure_height(uv-vec2(pixel_size.x,0.0)))/(2.0*pixel_size.x);
  float dy=(structure_height(up)-structure_height(down))/(2.0*pixel_size.y);
  // OpenGL +Y points toward the top of the image (opposite texture V).
  color=normalize(vec3(-dx*normal_gain,dy*normal_gain,1.0))*0.5+0.5;
 }
 else if(output_map==2) color=vec3(props.x);
 else if(output_map==3) color=vec3(props.z);
 else if(output_map==4) color=vec3(props.y);
 else if(output_map==5) color=item==10 ? foliage_color(uv):grass_color(uv);
 COLOR=vec4(color,1.0);
}
