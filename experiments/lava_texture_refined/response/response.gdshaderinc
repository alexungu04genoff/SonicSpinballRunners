// Structural response from the approved procedural module definitions.
// No albedo pixels or pigment brightness are sampled to construct height.
uniform int response_pass=0;
uniform vec2 texel=vec2(0.001953125);
uniform vec2 physical_repeat=vec2(1.6);
uniform float reference_range=0.06;

float bevel_ramp(float edge,float low,float high) { return clamp((edge-low)/(high-low),0.0,1.0); }
float soft_band(float value,float radius,float feather) { return 1.0-smoothstep(radius-feather,radius,abs(value)); }
float oct_distance(vec2 p,vec2 size,float corner) {
 vec2 a=abs(p);
 return max(max(a.x-size.x,a.y-size.y),(a.x+a.y-size.x-size.y+corner)*0.70710678);
}

void floor_shape(vec2 uv,out vec2 offset,out float silhouette,out float seed) {
 // Same sites, periodic hash, cell metric and clipped outline as balanced_floor.
 vec2 p=uv*8.0,cell=floor(p);
 float nearest=8.0,second=8.0;
 offset=vec2(0.0); seed=0.0;
 for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
  vec2 id=cell+vec2(float(x),float(y));
  vec2 site=id+0.5+(vec2(original_floor_hash(id),original_floor_hash(id+19.0))-0.5)*0.65;
  vec2 delta=p-site;
  float d=dot(delta,delta);
  if(d<nearest) { second=nearest; nearest=d; offset=delta; seed=original_floor_hash(id+41.0); }
  else second=min(second,d);
 }
 float clipped=max(abs(offset.x)*0.85+abs(offset.y)*0.52,abs(offset.y)*0.85+abs(offset.x)*0.52);
 silhouette=min(second-nearest,0.68-clipped);
}

void inset_shape(vec2 uv,out vec2 offset,out float silhouette,out float seed,out float selected) {
 vec2 site,id;
 float edge;
 inset_cell(uv,offset,site,id,edge);
 vec2 a=abs(fract(site-vec2(0.24,0.32)+0.5)-0.5)/vec2(0.19,0.16);
 vec2 b=abs(fract(site-vec2(0.74,0.72)+0.5)-0.5)/vec2(0.19,0.20);
 selected=1.0-step(1.0,min(length(a),length(b)));
 float clipped=max(abs(offset.x)*0.85+abs(offset.y)*0.52,abs(offset.y)*0.85+abs(offset.x)*0.52);
 silhouette=min(edge*2.0,0.68-clipped);
 seed=hash(id+vec2(37.0,13.0));
}

float rock_height(vec2 offset,float silhouette,float seed,float cell_width) {
 // A broad, asymmetric faceted crown avoids the previous flat paving-like center.
 // Both floors share this volume profile at their own physical rock size.
 float bevel=bevel_ramp(silhouette,0.025,0.235);
 vec2 axis=vec2(cos(seed*6.2831853),sin(seed*6.2831853));
 vec2 local=vec2(dot(offset,axis),dot(offset,vec2(-axis.y,axis.x)));
 float crown=1.0-max(abs(local.x-0.06)*1.7,abs(local.y+0.03)*1.35);
 crown=clamp(crown,0.0,0.88);
 float plane=dot(offset,axis)*0.040;
 return cell_width*bevel*(0.085+0.145*crown+plane);
}

float timber_height(vec2 uv) {
 vec2 p=uv*vec2(6.0,2.0);
 p.y+=mod(floor(p.x),2.0)*0.5;
 vec2 id=mod(floor(p),vec2(6.0,2.0)),q=fract(p);
 float tone=hash(id+vec2(41.0,19.0));
 float side=min(q.x,1.0-q.x),end=min(q.y,1.0-q.y);
 float plank=bevel_ramp(side,0.007,0.044)*bevel_ramp(end,0.004,0.024);
 float knots=step(0.72,hash(id+27.0));
 vec2 knot=q-vec2(0.40+hash(id+16.0)*0.20,0.40+hash(id+73.0)*0.24);
 float axis=q.x+0.034*sin(q.y*6.2831853+tone*4.0);
 axis+=knots*0.065*exp(-abs(knot.y)*11.0)*sign(knot.x);
 float grain=1.0-smoothstep(0.04,0.16,abs(sin(axis*12.5663706+tone)));
 // Grain is far shallower than the plank bevel or mineral insets.
 return plank*(0.0035-grain*0.00016);
}

vec2 column_coordinates(vec2 uv) {
 float x=uv.x*8.0,base=floor(x),best=100.0,id=base;
 for(int i=-1;i<=1;i++) {
  float candidate=base+float(i),site=column_site(candidate,uv.y);
  if(abs(site-x)<best) { best=abs(site-x); id=candidate; }
 }
 float site=column_site(id,uv.y);
 float left=(column_site(id-1.0,uv.y)+site)*0.5;
 float right=(column_site(id+1.0,uv.y)+site)*0.5;
 float horizontal=(x-left)/(right-left),wrapped=mod(id,8.0);
 float tone=hash(vec2(wrapped,41.0));
 return vec2(horizontal,fract(uv.y*2.0+hash(vec2(wrapped,15.0))+horizontal*(tone-0.5)*0.22));
}

float column_height(vec2 uv) {
 vec2 q=column_coordinates(uv);
 float edge=min(q.x,1.0-q.x),joint=min(q.y,1.0-q.y);
 float shoulder=bevel_ramp(edge,0.004,0.065);
 float crown=min(edge/0.32,1.0);
 return (0.012*shoulder+0.010*crown)*bevel_ramp(joint,0.006,0.024);
}

float pipe_profile(float axis) {
 float d=clamp(1.0-abs(axis)/0.47,0.0,1.0);
 return min(d*1.6,0.70)+max(d-0.65,0.0)*0.30;
}

float design_height(vec2 uv) {
 if(item==1) {
  vec2 offset;float edge,seed;
  floor_shape(uv,offset,edge,seed);
  return rock_height(offset,edge,seed,(8.0/2.1)/8.0);
 }
 if(item==5) {
  vec2 offset;float edge,seed,selected;
  inset_shape(uv,offset,edge,seed,selected);
  float h=timber_height(uv);
  float inset=selected*smoothstep(-0.025,0.005,edge);
  float stone=-0.001+rock_height(offset,edge,seed,1.6/6.0);
  return mix(h,stone,inset);
 }
 if(item==2) {
  vec2 q=vec2(fract(uv.x*2.0),uv.y)-0.5;
  float collar=soft_band(abs(q.x)-0.44,0.045,0.015);
  return 0.007*pipe_profile(q.y)+0.0012*collar*soft_band(q.y,0.47,0.015);
 }
 if(item==6) {
  vec2 q=vec2(fract(uv.x),uv.y)-0.5;
  float tube=(abs(q.y)-0.245)*2.05;
  float saddle=1.0-smoothstep(-0.020,0.0,oct_distance(q,vec2(0.090,0.48),0.045));
  return 0.0034*pipe_profile(tube)+0.0011*saddle;
 }
 if(item==3)return column_height(uv);
 if(item==7) {
  vec2 p=uv*vec2(3.0,4.0);p.x+=mod(floor(p.y),2.0)*0.5;
  vec2 q=fract(p)-0.5;
  return 0.0075*bevel_ramp(-oct_distance(q,vec2(0.487,0.481),0.024),0.0,0.042);
 }
 if(item==8) {
  vec2 q=vec2(fract(uv.x*2.0),uv.y)-0.5;
  float flange=max(soft_band(abs(q.y)-0.435,0.065,0.028),soft_band(abs(q.x)-0.445,0.055,0.023));
  float brace=soft_band(q.y+q.x*0.72,0.075,0.030)*soft_band(q.x,0.44,0.012)*soft_band(q.y,0.43,0.012);
  float plate=1.0-smoothstep(-0.016,0.0,oct_distance(abs(q)-vec2(0.445,0.435),vec2(0.075,0.095),0.028));
  return 0.0028*max(flange,brace)+0.0009*plate;
 }
 vec2 q=vec2(fract(uv.x*2.0),uv.y)-0.5;
 float perimeter=min(0.5-abs(q.x),0.5-abs(q.y));
 float frame=1.0-smoothstep(0.072,0.098,perimeter);
 float edge=bevel_ramp(perimeter,0.002,0.018);
 float plate=1.0-smoothstep(-0.016,0.0,oct_distance(abs(q)-vec2(0.439),vec2(0.060),0.019));
 return mix(column_height(uv)*0.65,0.027*edge,frame)+0.003*plate;
}

float design_roughness(vec2 uv) {
 if(item==1)return 0.89;
 if(item==5) {
  vec2 offset;float edge,seed,selected;
  inset_shape(uv,offset,edge,seed,selected);
  return mix(0.72,0.89,selected*smoothstep(-0.025,0.025,edge));
 }
 if(item==3)return 0.91;
 if(item==7)return 0.87;
 if(item==2||item==6)return 0.48;
 if(item==8)return 0.46;
 vec2 q=vec2(fract(uv.x*2.0),uv.y)-0.5;
 float perimeter=min(0.5-abs(q.x),0.5-abs(q.y));
 return mix(0.49,0.91,smoothstep(0.072,0.098,perimeter));
}

float design_cavity(vec2 uv) {
 vec2 offset;float edge,seed;
 if(item==1) {
  floor_shape(uv,offset,edge,seed);
  return mix(0.72,1.0,smoothstep(0.020,0.125,edge));
 }
 float selected;
 inset_shape(uv,offset,edge,seed,selected);
 float rock_contact=selected*(1.0-smoothstep(0.020,0.100,edge))*smoothstep(-0.040,0.0,edge);
 vec2 p=uv*vec2(6.0,2.0);p.y+=mod(floor(p.x),2.0)*0.5;
 vec2 q=fract(p);
 float joint=min(bevel_ramp(min(q.x,1.0-q.x),0.007,0.044),bevel_ramp(min(q.y,1.0-q.y),0.004,0.024));
 float timber_contact=mix(0.89,1.0,joint);
 return mix(timber_contact,0.77,rock_contact);
}

vec2 response_uv(vec2 uv) {
 uv.x=fract(uv.x);
 if(item==2||item==3||item==6||item==8||item==9) uv.y=clamp(uv.y,texel.y*0.5,1.0-texel.y*0.5);
 else uv.y=fract(uv.y);
 return uv;
}

void fragment() {
 vec2 uv=response_uv(UV);
 vec3 value=vec3((design_height(uv)+0.003)/reference_range);
 if(response_pass==1) {
  float dx=(design_height(response_uv(UV+vec2(texel.x,0.0)))-design_height(response_uv(UV-vec2(texel.x,0.0))))/(2.0*texel.x*physical_repeat.x);
  float dy=(design_height(response_uv(UV+vec2(0.0,texel.y)))-design_height(response_uv(UV-vec2(0.0,texel.y))))/(2.0*texel.y*physical_repeat.y);
  value=normalize(vec3(-dx,dy,1.0))*0.5+0.5;
 } else if(response_pass==2)value=vec3(design_roughness(uv));
 else if(response_pass==3)value=vec3(design_cavity(uv));
 COLOR=vec4(value,1.0);
}
