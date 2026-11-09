// Structural response only. These functions use the albedo's module definitions;
// pigment brightness and color variation never determine physical height.
uniform int response_pass=0;
uniform vec2 texel=vec2(.001953125);
uniform vec2 physical_repeat=vec2(3.2);
uniform float height_range=.012;
float bevel(float distance_to_joint){return smoothstep(.010,.070,distance_to_joint);}
float course_height(vec2 uv,vec2 counts){
 vec2 p=uv*counts;p.x+=mod(floor(p.y),2.0)*.5;
 vec2 q=fract(p),e=min(q,1.0-q);
 return bevel(min(e.x,e.y));
}
float raised_box(vec2 p,vec2 center,vec2 size,float bevel_width){
 return 1.0-smoothstep(-bevel_width,0.0,box_distance(p,center,size));
}
float trim_height(vec2 uv){
 float e=min(uv.y,1.0-uv.y);
 return .50+.20*smoothstep(.008,.045,e)+.09*band(e-.10,.025);
}
float design_height(vec2 uv){
 if(item==1){
  float h=.30+.40*bevel(fitted_distance(uv*8.0,false));
  float across=abs(uv.x-.52);
  float frame=1.0-smoothstep(.131,.138,across);
  h=mix(h,.66,frame);
  float end=min(fract(uv.y*4.0),1.0-fract(uv.y*4.0));
  // Cyan key lines are decoration, while the four framed modules have joints.
  return mix(h,.57+.06*smoothstep(.012,.035,end),1.0-smoothstep(.109,.116,across));
 }
 if(item==2||item==6){
  float h=.32+.30*course_height(uv,vec2(8,1));
  return h+.12*(band(uv.y-.22,.024)+band(uv.y-.78,.024));
 }
 if(item==3){
  float h=.30+.22*course_height(uv,vec2(12,8));
  vec2 q=vec2(fract(uv.x*3.0),uv.y);
  float shaft=raised_box(q,vec2(.5),vec2(.18,.43),.024);
  h=mix(h,.65+.06*course_height(vec2(q.x,uv.y),vec2(5,6)),shaft);
  // Broad carved shaft facets, independent of its green/ivory paint stripes.
  h+=shaft*.035*(1.0-abs(q.x-.5)/.18);
  for(int end=0;end<2;end++){
   float y=end==0?.16:.84;
   h=mix(h,.87,raised_box(q,vec2(.5,y),vec2(.24,.040),.012));
   float collar=end==0?.23:.77;
   h=mix(h,.76,raised_box(q,vec2(.5,collar),vec2(.18,.021),.008));
  }
  if(uv.y<.08)h=trim_height(vec2(uv.x,uv.y/.08));
  if(uv.y>.92)h=trim_height(vec2(uv.x,(uv.y-.92)/.08));
  return h;
 }
 if(item==5){
  float h=.30+.40*bevel(fitted_distance(uv*8.0,false));
  // Turf remains a soft, shallow bed; no invented noisy blade displacement.
  return mix(h,.56,lawn_mask(uv));
 }
 if(item==7)return .32+.34*bevel(fitted_distance(uv*vec2(4,8),true));
 if(item==8){
  float h=trim_height(uv);
  h=mix(h,.47+.10*bevel(fitted_distance(uv*vec2(8,4),true)),raised_box(uv,vec2(.5),vec2(.6,.19),.018));
  return h+.10*(band(uv.y-.29,.016)+band(uv.y-.71,.016));
 }
 vec2 q=vec2(fract(uv.x*4.0),uv.y);
 float h=.35+.20*course_height(uv,vec2(8,4));
 float d=box_distance(q,vec2(.5,.54),vec2(.37,.30));
 h=mix(h,.78,1.0-smoothstep(-.040,0.0,d));
 h=mix(h,.64,1.0-smoothstep(-.086,-.068,d));
 h=mix(h,.35,1.0-smoothstep(-.122,-.100,d));
 // The green band and pale center occupy the same recessed plane.
 if(uv.y<.19)h=trim_height(vec2(uv.x,uv.y/.19));
 return h;
}
vec2 response_uv(vec2 uv){
 if(item==2||item==3||item==6||item==8||item==9)uv.y=clamp(uv.y,texel.y*.5,1.0-texel.y*.5);
 else uv.y=fract(uv.y);
 uv.x=fract(uv.x);
 return uv;
}
float surface_roughness(vec2 uv){
 if(item==1)return mix(.83,.38,inside(abs(uv.x-.52)-.114));
 if(item==5)return mix(.84,.96,lawn_mask(uv));
 if(item==7)return .66;
 if(item==8)return mix(.82,.66,box(uv,vec2(.5),vec2(.6,.19)));
 return .84;
}
void fragment(){
 vec2 uv=UV;
 float h=design_height(response_uv(uv));
 vec3 value=vec3(h);
 if(response_pass==1){
  float dx=(design_height(response_uv(uv+vec2(texel.x,0)))-design_height(response_uv(uv-vec2(texel.x,0))))*height_range/(2.0*texel.x*physical_repeat.x);
  float dy=(design_height(response_uv(uv+vec2(0,texel.y)))-design_height(response_uv(uv-vec2(0,texel.y))))*height_range/(2.0*texel.y*physical_repeat.y);
  // OpenGL convention: image V down, tangent-space Y up.
  value=normalize(vec3(-dx,dy,1.0))*.5+.5;
 }else if(response_pass==2)value=vec3(surface_roughness(uv));
 COLOR=vec4(value,1.0);
}
