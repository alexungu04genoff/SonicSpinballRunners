shader_type canvas_item;
render_mode unshaded;
// Phase 1 palette and structural studies only. No production bindings or maps.
uniform int item = 1;
uniform int option = 0;

float hash(vec2 p) {
 return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float periodic_noise(vec2 p, vec2 period) {
 vec2 id=floor(p), q=fract(p);
 q=q*q*(3.0-2.0*q);
 return mix(mix(hash(mod(id,period)),hash(mod(id+vec2(1,0),period)),q.x),mix(hash(mod(id+vec2(0,1),period)),hash(mod(id+vec2(1,1),period)),q.x),q.y);
}
float soft(float a, float b, float x) { return smoothstep(a, b, x); }
float box(vec2 p, vec2 half_size, float feather) {
 vec2 d = abs(p) - half_size;
 return 1.0 - soft(-feather, feather, max(d.x, d.y));
}
vec3 gold(float t) { return mix(vec3(0.46,0.24,0.15),vec3(0.88,0.66,0.30),t); }
vec3 violet(float t) { return mix(vec3(0.17,0.12,0.25),vec3(0.55,0.47,0.70),t); }

// Periodic sites; each facet receives its own broad mineral colour, not noise.
void cell_data(vec2 p, vec2 period, out vec2 offset, out vec2 site_id, out float edge) {
 vec2 base = floor(p);
 float nearest = 100.0;
 vec2 center = vec2(0.0);
 for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
  vec2 id=base+vec2(float(x),float(y));
  vec2 repeat_id=mod(id,period);
  vec2 site=id+0.5+(vec2(hash(repeat_id),hash(repeat_id+17.0))-0.5)*0.62;
  float distance_sq=dot(site-p,site-p);
  if(distance_sq<nearest) { nearest=distance_sq; center=site; site_id=repeat_id; }
 }
 offset=p-center;
 edge=100.0;
 for(int y=-2;y<=2;y++) for(int x=-2;x<=2;x++) {
  vec2 id=base+vec2(float(x),float(y));
  vec2 repeat_id=mod(id,period);
  vec2 site=id+0.5+(vec2(hash(repeat_id),hash(repeat_id+17.0))-0.5)*0.62;
  vec2 difference=site-center;
  if(dot(difference,difference)>0.001) edge=min(edge,dot((site+center)*0.5-p,normalize(difference)));
 }
}

vec3 mineral(vec2 uv, vec2 count, int kind) {
 vec2 offset, id; float edge;
 cell_data(uv*count,count,offset,id,edge);
 float tone=hash(id+43.0);
 float angle=floor((atan(offset.y,offset.x)+3.141593)*0.95493);
 float plane=fract(angle*0.381966+tone*0.3);
 vec3 face=mix(vec3(0.69,0.47,0.28),vec3(0.90,0.74,0.45),tone);
 vec3 rim=mix(vec3(0.42,0.24,0.23),vec3(0.72,0.47,0.28),plane);
 vec3 joint=vec3(0.19,0.12,0.28);
 if(kind==0) { face*=0.77; rim*=0.82; joint=vec3(0.20,0.16,0.23); }
 if(kind==1) {
  face=mix(vec3(0.22,0.19,0.25),vec3(0.37,0.29,0.35),tone);
  rim=mix(vec3(0.16,0.14,0.23),vec3(0.33,0.25,0.33),plane);
  joint=vec3(0.12,0.10,0.18);
 }
 if(kind==3) {
  face=mix(vec3(0.37,0.32,0.48),vec3(0.57,0.48,0.65),tone);
  rim=mix(vec3(0.25,0.21,0.38),vec3(0.39,0.47,0.51),plane);
  joint=vec3(0.19,0.16,0.29);
 }
 float planar=step(0.13,offset.x*0.73+offset.y*(tone-0.3));
 face*=0.96+0.06*planar;
 face*=0.985+0.025*cos(dot(offset,vec2(2.0,3.0))+tone*TAU);
 vec3 rock=mix(rim,face,soft(0.065,0.095,edge));
 // Sparse turquoise mineral rims translate the source sheet's cool rock facets.
 float inclusion=step(0.73,tone)*(1.0-soft(0.035,0.07,edge))*step(2.0,angle);
 if(kind!=1) rock=mix(rock,vec3(0.25,0.49,0.48),inclusion*0.58);
 return mix(joint,rock,soft(0.012,0.024,edge));
}

vec3 courses(vec2 uv, vec2 count, bool dark) {
 vec2 p=uv*count;
 float row=floor(p.y);
 p.x+=mod(row,2.0)*0.5;
 vec2 id=mod(floor(p),count);
 vec2 q=fract(p);
 float tone=hash(id+9.0);
 float edge=min(min(q.x,1.0-q.x),min(q.y,1.0-q.y));
 vec3 face=dark ? mix(vec3(0.23,0.19,0.29),vec3(0.36,0.30,0.38),tone) : mix(vec3(0.56,0.36,0.25),vec3(0.78,0.57,0.34),tone);
 face*=0.96+0.06*step(q.x*0.7+q.y*0.3,0.6+tone*0.12);
 vec3 edge_color=dark ? vec3(0.30,0.25,0.37) : vec3(0.56,0.33,0.23);
 vec3 stone=mix(edge_color,face,soft(0.045,0.075,edge));
 // Broad occasional mineral vein, quieter than a glowing lava fissure.
 float vein=(1.0-soft(0.008,0.025,abs(q.y-0.64-q.x*0.15)))*step(0.63,tone);
 stone=mix(stone,dark ? vec3(0.39,0.31,0.43) : vec3(0.38,0.48,0.43),vein*0.4);
 return mix(vec3(0.17,0.12,0.23),stone,soft(0.012,0.023,edge));
}

vec3 columns(vec2 uv) {
 float fracture=abs(fract(uv.y*3.0)*2.0-1.0);
 vec2 p=vec2(uv.x*8.0+fracture*0.22,uv.y*2.0);
 float col=floor(p.x);
 float offset=hash(vec2(mod(col,8.0),3.0));
 p.y+=offset+fract(p.x)*0.18;
 vec2 q=fract(p), id=mod(floor(p),vec2(8.0,2.0));
 float face=1.0-abs(q.x*2.0-1.0);
 float shade=floor(face*3.0)/3.0;
 vec3 color=mix(vec3(0.19,0.13,0.29),vec3(0.43,0.31,0.46),shade*0.75+offset*0.25);
 float edge=min(min(q.x,1.0-q.x)*0.6,min(q.y,1.0-q.y));
 color=mix(vec3(0.12,0.10,0.20),color,soft(0.014,0.035,edge));
 float lens=(1.0-soft(0.26,0.31,abs(q.x-0.49)+abs(q.y-0.72)*3.4))*step(0.71,hash(id+24.0));
 return mix(color,mix(vec3(0.50,0.31,0.20),vec3(0.81,0.62,0.34),face),lens);
}

vec3 cooled_flow(vec2 uv) {
 vec2 p=uv;
 p.y+=0.065*sin(uv.x*TAU)+0.018*sin(uv.x*TAU*3.0);
 vec3 color=courses(p,vec2(3.0,6.0),true);
 float band=fract(p.y*6.0);
 float mineral_band=(1.0-soft(0.025,0.07,abs(band-0.64)));
 color=mix(color,vec3(0.40,0.32,0.43),mineral_band*0.38);
 return color;
}

vec3 pipe_trim(vec2 uv) {
 vec2 q=vec2(fract(uv.x*4.0),uv.y);
 float end=min(q.x,1.0-q.x);
 float band=min(q.y,1.0-q.y);
 vec3 steel=mix(vec3(0.31,0.25,0.46),vec3(0.55,0.49,0.66),soft(0.05,0.16,band));
 steel=mix(steel,vec3(0.39,0.40,0.55),box(vec2(0.0,q.y-0.49),vec2(1.0,0.19),0.012)*0.65);
 steel=mix(steel,vec3(0.62,0.54,0.72),box(vec2(0.0,q.y-0.31),vec2(1.0,0.035),0.012)*0.60);
 steel=mix(steel,vec3(0.67,0.57,0.76),(1.0-soft(0.010,0.025,abs(q.y-0.22)))*step(0.10,end));
 float collar=1.0-soft(0.065,0.075,end);
 vec3 brass=mix(gold(0.54),gold(0.86),box(q-vec2(0.5,0.5),vec2(0.48,0.34),0.012));
 float fastener=box(vec2(end-0.034,abs(q.y-0.5)-0.26),vec2(0.015,0.035),0.006);
 brass=mix(brass,vec3(0.38,0.24,0.25),fastener);
 steel=mix(steel,vec3(0.21,0.17,0.32),(1.0-soft(0.080,0.095,end))*0.75);
 return mix(steel,brass,collar);
}

vec3 girder(vec2 uv) {
 vec2 q=vec2(fract(uv.x*4.0),uv.y);
 float border=min(min(q.x,1.0-q.x),min(q.y,1.0-q.y));
 vec3 inset=mix(vec3(0.18,0.13,0.25),vec3(0.29,0.23,0.36),box(q-0.5,vec2(0.38,0.30),0.015));
 float diagonal_distance=abs(q.y-(0.20+q.x*0.60));
 float diagonal=1.0-soft(0.065,0.080,diagonal_distance);
 float structure=max(1.0-soft(0.115,0.140,border),diagonal);
 vec3 beam=mix(gold(0.50),gold(0.85),soft(0.015,0.045,border));
 beam=mix(beam,gold(0.38),max(soft(0.095,0.115,border),soft(0.040,0.065,diagonal_distance))*0.42);
 float lug=box(abs(q-0.5)-vec2(0.43,0.42),vec2(0.075,0.085),0.012);
 structure=max(structure,lug);
 beam=mix(beam,gold(0.91),lug*0.65);
 float rivet=1.0-soft(0.022,0.032,length(vec2(abs(q.x-0.5)-0.43,abs(q.y-0.5)-0.42)));
 return mix(mix(inset,beam,structure),vec3(0.94,0.75,0.41),rivet);
}

vec3 deck(vec2 uv, bool ribbed) {
 vec2 p=uv*vec2(2.0,4.0), id=floor(p), q=fract(p);
 float edge=min(min(q.x,1.0-q.x),min(q.y,1.0-q.y));
 float tone=hash(id+7.0);
 vec3 color=mix(vec3(0.27,0.23,0.39),vec3(0.41,0.37,0.51),tone);
 color*=0.98+0.035*cos(q.x*3.14159);
 float panel_distance=max(max(abs(q.x-0.5)-0.37,abs(q.y-0.5)-0.31),(abs(q.x-0.5)+abs(q.y-0.5)-0.60)*0.707);
 float panel=1.0-soft(-0.008,0.008,panel_distance);
 color=mix(color,vec3(0.19,0.16,0.28),panel*0.65);
 float center=1.0-soft(-0.026,-0.012,panel_distance);
 color=mix(color,mix(vec3(0.30,0.27,0.42),vec3(0.39,0.37,0.49),tone),center);
 float cross_flange=1.0-soft(0.080,0.10,min(q.y,1.0-q.y));
 color=mix(color,vec3(0.52,0.46,0.62),cross_flange);
 color=mix(vec3(0.14,0.11,0.21),color,soft(0.014,0.035,edge));
 float rib=1.0-soft(0.055,0.075,min(q.y,1.0-q.y));
 if(ribbed) {
  float step_band=1.0-soft(0.028,0.045,abs(q.y-0.5));
  color=mix(color,vec3(0.51,0.45,0.59),step_band*box(q-0.5,vec2(0.35,0.48),0.015));
 }
 color=mix(color,mix(gold(0.48),gold(0.76),soft(0.006,0.022,min(q.y,1.0-q.y))),rib);
 float bolt=1.0-soft(0.035,0.052,length(abs(q-0.5)-vec2(0.36,0.34)));
 return mix(color,gold(0.84),bolt);
}

vec3 cliff_layers(vec2 uv) {
 vec2 warped=uv;
 warped.y+=0.027*sin(uv.x*TAU*2.0)+0.016*sin(uv.x*TAU*5.0);
 vec3 color=mineral(warped,vec2(7.0,4.0),2);
 float band=fract(warped.y*4.0);
 float stratum=1.0-soft(0.06,0.16,abs(band-0.53));
 return mix(color,vec3(0.30,0.26,0.40),stratum*0.68);
}

vec3 retaining(vec2 uv) {
 vec3 color=columns(uv);
 vec2 q=fract(uv*vec2(3.0,1.0));
 float vertical=1.0-soft(0.060,0.078,min(q.x,1.0-q.x));
 float horizontal=1.0-soft(0.07,0.09,min(q.y,1.0-q.y));
 vec3 frame=mix(violet(0.6),violet(0.88),soft(0.0,0.045,min(q.x,1.0-q.x)));
 color=mix(color,frame,max(vertical,horizontal));
 float joint=box(vec2(min(q.x,1.0-q.x),min(q.y,1.0-q.y)),vec2(0.11,0.14),0.008);
 color=mix(color,gold(0.75),joint);
 float pin=1.0-soft(0.020,0.032,length(vec2(min(q.x,1.0-q.x)-0.048,min(q.y,1.0-q.y)-0.06)));
 return mix(color,vec3(0.94,0.76,0.44),pin);
}

vec3 molten(vec2 uv, bool crust) {
 vec2 offset,id; float edge;
 if(crust) {
  cell_data(uv*5.0,vec2(5.0),offset,id,edge);
  vec3 rock=mix(vec3(0.20,0.12,0.20),vec3(0.34,0.17,0.21),hash(id));
  rock*=0.9+0.16*step(0.08,offset.x+offset.y*0.6);
  vec3 seam=mix(vec3(1.0,0.67,0.18),vec3(0.91,0.22,0.08),soft(0.0,0.075,edge));
  return mix(seam,rock,soft(0.075,0.105,edge));
 }
 vec2 p=uv*6.0;
 float warp=periodic_noise(p,vec2(6.0));
 float tongue=sin(uv.y*TAU*3.0+warp*8.0+sin(uv.x*TAU)*1.4);
 float river=abs(tongue);
 vec3 color=mix(vec3(0.48,0.10,0.12),vec3(0.94,0.31,0.07),1.0-soft(0.15,0.95,river));
 color=mix(color,vec3(1.0,0.68,0.16),1.0-soft(0.10,0.40,river));
 return mix(color,vec3(1.0,0.82,0.39),(1.0-soft(0.015,0.095,river))*0.60);
}

vec3 crystal(vec2 uv, bool honey) {
 vec2 p=uv*(honey ? vec2(3.0,3.0) : vec2(5.0,2.0));
 vec2 offset,id; float edge;
 cell_data(p,honey ? vec2(3.0,3.0) : vec2(5.0,2.0),offset,id,edge);
 float tone=hash(id+12.0);
 float plane=step(0.0,offset.x-offset.y*0.38);
 if(honey) {
  float inclusion=1.0-soft(0.19,0.23,abs(offset.x)*0.8+abs(offset.y)*1.1);
  vec3 matrix=mix(vec3(0.25,0.43,0.44),vec3(0.45,0.63,0.58),tone*0.6+plane*0.4);
  vec3 ore=mix(vec3(0.69,0.45,0.20),vec3(0.94,0.75,0.38),plane*0.6+tone*0.4);
  return mix(matrix,ore,inclusion);
 }
 vec3 color=mix(vec3(0.31,0.23,0.49),vec3(0.65,0.55,0.74),tone*0.45+plane*0.55);
 float growth=fract(offset.y*2.0+offset.x+tone);
 color*=0.94+0.08*soft(0.10,0.75,growth);
 float vein=1.0-soft(0.020,0.060,edge);
 color=mix(color,vec3(0.38,0.60,0.65),vein*0.65);
 return mix(color,vec3(0.73,0.64,0.82),(1.0-soft(0.010,0.026,abs(growth-0.72)))*0.23);
}

void fragment() {
 vec3 color=vec3(0.5);
 bool b=option==1;
 if(item==1) color=b ? cooled_flow(UV) : mineral(UV,vec2(5.0),0);
 else if(item==2) color=b ? courses(UV,vec2(7.0,1.0),false) : pipe_trim(UV);
 else if(item==3) color=b ? columns(UV) : mineral(UV,vec2(7.0,4.0),2);
 else if(item==5) color=b ? deck(UV,false) : mineral(UV,vec2(5.0),3);
 else if(item==6) color=b ? pipe_trim(UV) : mineral(UV,vec2(9.0,1.0),2);
 else if(item==7) color=b ? deck(UV,true) : courses(UV,vec2(2.0,6.0),true);
 else if(item==8) color=b ? girder(UV) : pipe_trim(UV);
 else if(item==9) color=b ? retaining(UV) : cliff_layers(UV);
 else if(item==10) color=molten(UV,b);
 else if(item==11) color=crystal(UV,b);
 COLOR=vec4(color,1.0);
}
