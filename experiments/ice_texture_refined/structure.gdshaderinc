// Physical profiles share the selected color generator's shape functions.
// Colored internal ice planes and diamond colors never become height by brightness.
uniform vec2 physical_size = vec2(1.0);
uniform vec2 sample_step = vec2(.001953125);
uniform float height_world_scale = .025;
uniform bool export_normal = true;

float crystal_profile(vec2 uv,vec2 count){
 vec4 shape=crystal_shape(uv,count);
 float face=clamp((1.0-shape.z)/.44,0.0,1.0);
 return .20+.55*face+(.025*shape.x+.015*shape.y)*face;
}
float block_profile(vec2 uv,vec2 count){
 vec4 shape=block_shape(uv,count);
 return mix(.20,.67,clamp((shape.z-.01)/.09,0.0,1.0));
}
float structure_height(vec2 coordinates){
 vec2 uv=fract(coordinates);
 if(item==2||item==3||item==6||item==9)uv.y=clamp(coordinates.y,0.0,1.0);
 if(item==7)uv.x=clamp(coordinates.x,0.0,1.0);
 float ice_mask=0.0;
 if(item==1||item==5){
  vec3 unused_color=snow_field(item==5?uv+vec2(.31,.19):uv,item==5,ice_mask);
  return .52-ice_mask*(item==5?.09:.14);
 }
 if(item==2){
  vec2 p=vec2(uv.x*12.0+.25,(uv.y-.12)/.76*2.0);
  p.x+=mod(floor(p.y),2.0)*.5;
  vec2 q=fract(p)*2.0-1.0;
  float diamond=clamp(1.0-abs(q.x)-abs(q.y),0.0,1.0);
  float zone=smoothstep(.10,.13,uv.y)*(1.0-smoothstep(.87,.90,uv.y));
  return mix(.65,.25+diamond*.22,zone);
 }
 if(item==3)return mix(.88,crystal_profile(uv,vec2(6,4)),cap_ice_mask(uv,.10,.065,3.4));
 if(item==6)return mix(.88,block_profile(uv,vec2(6,1)),cap_ice_mask(uv,.64,.16,9.2));
 if(item==7){
  float edge=min(uv.x,1.0-uv.x);
  float lip=.074+(noise1(uv.y*8.0,8.0,7.6)-.5)*.021;
  return mix(.82,block_profile(uv,vec2(3,6)),smoothstep(lip-.008,lip+.008,edge));
 }
 if(item==9){
  float h=crystal_profile(uv,vec2(6,4));
  vec2 p=vec2(uv.x*6.0,uv.y);
  float cell=floor(p.x),seed=hash(vec2(mod(cell,6.0),17.3));
  float x=fract(p.x)-(.40+seed*.20);
  float start=.21+seed*.10,end=.78+seed*.20;
  float t=clamp((uv.y-start)/(end-start),0.0,1.0);
  float width=(.075+seed*.065)*(1.0-t*.62);
  float curtain=(1.0-smoothstep(width,width+.012,abs(x)))*smoothstep(start,start+.03,uv.y)*(1.0-smoothstep(end-.02,end,uv.y));
  float prism=.84+.08*clamp(1.0-abs(x)/width,0.0,1.0);
  h=mix(h,max(h,prism),curtain);
  return mix(.88,h,cap_ice_mask(uv,.105,.07,7.6));
 }
 if(item==11){
  float bough_height;
  vec3 unused_color=boughs(uv,bough_height);
  return bough_height;
 }
 if(item==12){
  vec3 unused_color=floe_lake(uv,ice_mask);
  return .30+(1.0-ice_mask)*.18;
 }
 return .5;
}
void fragment(){
 float height=structure_height(UV);
 vec3 result=vec3(height);
 if(export_normal){
  float du=(structure_height(UV+vec2(sample_step.x,0.0))-structure_height(UV-vec2(sample_step.x,0.0)))*height_world_scale/(2.0*sample_step.x*physical_size.x);
  float dv=(structure_height(UV+vec2(0.0,sample_step.y))-structure_height(UV-vec2(0.0,sample_step.y)))*height_world_scale/(2.0*sample_step.y*physical_size.y);
  // Texture V grows down; OpenGL tangent normal Y grows up.
  result=normalize(vec3(-du,dv,1.0))*.5+.5;
 }
 COLOR=vec4(result,1.0);
}
