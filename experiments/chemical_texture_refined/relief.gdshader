shader_type canvas_item;
render_mode unshaded;
uniform int item=1;
uniform int output_map=0;
uniform vec2 pixel_size=vec2(0.001953125);
uniform float normal_gain=.004;
float slab(float distance,float bevel) { return clamp(distance/bevel,0.0,1.0); }
float box_distance(vec2 p,vec2 center,vec2 half_size) {
 vec2 d=half_size-abs(p-center); return min(d.x,d.y);
}
float inset(vec2 p,vec2 center,vec2 half_size,float bevel) {
 return slab(box_distance(p,center,half_size),bevel);
}
float chamfer(vec2 p,vec2 half_size,float corner,float bevel) {
 vec2 d=abs(p-.5);
 return slab(min(min(half_size.x-d.x,half_size.y-d.y),half_size.x+half_size.y-corner-d.x-d.y),bevel);
}
// Return structural height, roughness, and metalness. Painted marks are absent.
vec3 structure(vec2 uv) {
 float h=.7,r=.72,m=.08;
 if(item==1) {
  vec2 q=fract(uv*6.0),e=min(q,1.0-q);
  h=.38+.32*slab(min(e.x,e.y)-.012,.035);
  r=.70; m=.12;
 } else if(item==2) {
  float rim=max(inset(uv,vec2(.5,.1),vec2(2,.055),.025),inset(uv,vec2(.5,.9),vec2(2,.055),.025));
  h=.66+.14*rim; r=mix(.76,.48,rim); m=mix(.03,.55,rim);
 } else if(item==3 || item==9) {
  float depth=uv.y*1.6;
  vec2 p=vec2(uv.x*3.0,((item==3?.325:0.0)-depth)*3.0);
  vec2 q=fract(p),e=min(q,1.0-q);
  float frame=1.0-slab(min(e.x,e.y)-.025,.035);
  float bay=mod(floor(p.x),3.0);
  float brace=(1.0-slab(min(abs(q.x-q.y),abs(q.x+q.y-1.0))-.015,.025))*(1.0-step(.5,bay));
  float vent=inset(q,vec2(.5),vec2(.35,.3),.02)*step(1.5,bay);
  float slot=slab(fract(p.y*9.0)-.45,.12)*(1.0-slab(fract(p.y*9.0)-.88,.12));
  h=.54+.20*frame+.09*brace-.20*vent*slot;
  r=mix(.74,.52,frame);m=mix(.08,.45,frame);
  // Shared wall-top warning band is flat paint. Only its physical rim rises.
  if(depth<.080) {h=.66;r=.72;m=.04;}
  float rim=1.0-slab(abs(depth-.012)-.008,.006);
  h+=rim*.08;
 } else if(item==5) {
  vec2 q=fract(uv*2.0);
  float frame=chamfer(q,vec2(.482),.065,.03);
  float hole=chamfer(q,vec2(.308,.345),.025,.025);
  float tread=inset(q,vec2(.5),vec2(.255,.29),.02);
  float groove=(1.0-slab(abs(fract(q.y*8.0)-.5)-.035,.035))*tread;
  h=.30+.45*frame-.25*hole+.09*tread-.07*groove;
  r=mix(.71,.57,hole);m=mix(.03,.32,hole);
 } else if(item==6) {
  vec2 q=vec2(fract(uv.x*4.0),uv.y);
  float slot=inset(uv,vec2(.5,.58),vec2(2,.105),.03);
  float insert=inset(q,vec2(.5,.58),vec2(.30,.055),.025);
  h=.72-.26*slot+.1*insert;
  r=mix(.54,.78,slot);m=mix(.55,.16,slot);
  // Yellow line is painted: no height contribution.
 } else if(item==7) {
  vec2 p=vec2(uv.x,fract(uv.y*2.0));
  float hatch=mod(floor(uv.y*2.0),2.0);
  float rim=inset(p,vec2(.5),vec2(.36,.37),.018);
  float inner=inset(p,vec2(.5),vec2(.32,.32),.02);
  float slots=inset(p,vec2(.455,.5),vec2(.165,.15),.01)*slab(fract(p.y*17.0)-.60,.14);
  float grid=max(1.0-slab(min(fract(p.x*18.0),1.0-fract(p.x*18.0))-.015,.04),1.0-slab(min(fract(p.y*10.0),1.0-fract(p.y*10.0))-.015,.04));
  h=.66+.12*rim-.23*inner-.17*slots*(1.0-hatch)-.055*grid*inner*hatch;
  h-=.22*(1.0-slab(min(p.y,1.0-p.y),.018));
  r=mix(.73,.57,inner);m=mix(.03,.32,inner);
 } else if(item==8) {
  vec2 q=vec2(fract(uv.x*4.0),uv.y);
  float seam=1.0-slab(abs(q.x-.5)-.015,.03);
  float edge=max(1.0-slab(abs(uv.y-.1)-.025,.025),1.0-slab(abs(uv.y-.9)-.025,.025));
  h=.66+.13*max(seam,edge);
  r=mix(.65,.49,max(seam,edge));m=mix(.04,.50,max(seam,edge));
 }
 return vec3(h,r,m);
}
vec2 bounded(vec2 uv) {
 if(item==2 || item==3 || item==6 || item==8 || item==9) return vec2(fract(uv.x),clamp(uv.y,0.0,1.0));
 if(item==7) return vec2(clamp(uv.x,0.0,1.0),fract(uv.y));
 return fract(uv);
}
void fragment() {
 vec3 s=structure(bounded(UV));
 float l=structure(bounded(UV-vec2(pixel_size.x,0))).x;
 float r=structure(bounded(UV+vec2(pixel_size.x,0))).x;
 float t=structure(bounded(UV-vec2(0,pixel_size.y))).x;
 float b=structure(bounded(UV+vec2(0,pixel_size.y))).x;
 vec3 value=vec3(s.x);
 if(output_map==1) value=normalize(vec3(-(r-l)/pixel_size.x,(b-t)/pixel_size.y,1.0/normal_gain))*.5+.5;
 if(output_map==2) value=vec3(s.y);
 if(output_map==3) value=vec3(1.0-clamp((.65-s.x)*.45,0.0,.18));
 if(output_map==4) value=vec3(s.z);
 COLOR=vec4(value,1.0);
}
