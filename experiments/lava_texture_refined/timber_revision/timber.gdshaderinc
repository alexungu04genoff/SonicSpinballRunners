// 5B revision: orange structural timber with embedded gold mineral-rock clusters.
// The user explicitly confirmed wood plus rock insets, not a full rock surface.
vec3 orange_timber(vec2 uv) {
 vec2 p=uv*vec2(6.0,2.0);
 float lane=floor(p.x);
 p.y+=mod(lane,2.0)*0.5;
 vec2 id=mod(floor(p),vec2(6.0,2.0)), q=fract(p);
 float tone=hash(id+vec2(41.0,19.0));
 vec3 face=mix(vec3(0.64,0.335,0.16),vec3(0.80,0.465,0.215),tone);
 float knot_amount=step(0.72,hash(id+27.0));
 vec2 knot=q-vec2(0.40+hash(id+16.0)*0.20,0.40+hash(id+73.0)*0.24);
 // A few broad grain paths follow each long plank and bend around sparse knots.
 float grain_axis=q.x+0.034*sin(q.y*6.2831853+tone*4.0);
 grain_axis+=knot_amount*0.065*exp(-abs(knot.y)*11.0)*sign(knot.x);
 float grain=1.0-smoothstep(0.04,0.16,abs(sin(grain_axis*12.5663706+tone)));
 face=mix(face,face*vec3(0.78,0.73,0.79),grain*0.46);
 float broad_grain=sin(grain_axis*6.2831853+tone*2.0)*0.016;
 face+=vec3(broad_grain,broad_grain*0.65,broad_grain*0.25);
 float knot_distance=length(knot*vec2(1.0,2.4));
 float ring=band(knot_distance-0.105,0.014)*knot_amount;
 face=mix(face,vec3(0.45,0.235,0.13),ring*0.55);
 face=mix(face,vec3(0.46,0.245,0.14),fill(knot_distance-0.063)*knot_amount*0.74);
 float side=min(q.x,1.0-q.x), end=min(q.y,1.0-q.y);
 vec3 timber=mix(face*0.83,face,smoothstep(0.020,0.044,side));
 timber=mix(timber*0.84,timber,smoothstep(0.009,0.024,end));
 float board=smoothstep(0.007,0.015,side)*smoothstep(0.004,0.010,end);
 return mix(vec3(0.19,0.13,0.12),timber,board);
}

void inset_cell(vec2 uv, out vec2 offset, out vec2 site_uv, out vec2 site_id, out float edge) {
 vec2 p=uv*6.0, base=floor(p), center=vec2(0.0);
 float nearest=100.0;
 for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
  vec2 id=base+vec2(float(x),float(y)), wrapped=mod(id,vec2(6.0));
  vec2 site=id+0.5+(vec2(hash(wrapped),hash(wrapped+19.0))-0.5)*0.72;
  float distance_sq=dot(p-site,p-site);
  if(distance_sq<nearest) { nearest=distance_sq; center=site; site_id=wrapped; }
 }
 offset=p-center;
 site_uv=fract(center/6.0);
 edge=100.0;
 for(int y=-2;y<=2;y++) for(int x=-2;x<=2;x++) {
  vec2 id=base+vec2(float(x),float(y)), wrapped=mod(id,vec2(6.0));
  vec2 site=id+0.5+(vec2(hash(wrapped),hash(wrapped+19.0))-0.5)*0.72;
  vec2 delta=site-center;
  if(dot(delta,delta)>0.001) edge=min(edge,dot((site+center)*0.5-p,normalize(delta)));
 }
}

vec3 timber_with_rock_insets(vec2 uv) {
 vec3 timber=orange_timber(uv);
 vec2 offset,site,id;
 float edge;
 inset_cell(uv,offset,site,id,edge);
 // Select whole rocks by their centers so inset edges follow rock outlines.
 // Periodic cluster selection keeps both image boundaries tileable.
 vec2 a=abs(fract(site-vec2(0.24,0.32)+0.5)-0.5)/vec2(0.19,0.16);
 vec2 b=abs(fract(site-vec2(0.74,0.72)+0.5)-0.5)/vec2(0.19,0.20);
 float selected=1.0-step(1.0,min(length(a),length(b)));
 float clipped=max(abs(offset.x)*0.87+abs(offset.y)*0.52,abs(offset.y)*0.87+abs(offset.x)*0.52);
 float silhouette=min(edge,0.66-clipped);
 float tone=hash(id+vec2(37.0,13.0));
 float facet=floor((atan(offset.y,offset.x)+3.14159265)*0.95493);
 float plane=fract(facet*0.381966+tone*0.3);
 vec3 rim=mix(vec3(0.49,0.255,0.18),vec3(0.87,0.54,0.27),plane);
 vec3 face=mix(vec3(0.86,0.64,0.32),vec3(0.96,0.82,0.49),tone);
 face*=0.975+0.035*step(0.12,offset.x*0.65+offset.y*0.7);
 vec3 rock=mix(rim,face,smoothstep(0.072,0.099,silhouette));
 float cool_edge=step(0.81,tone)*step(3.0,facet)*(1.0-smoothstep(0.030,0.070,silhouette));
 rock=mix(rock,vec3(0.29,0.48,0.45),cool_edge*0.50);
 vec3 c=mix(timber,vec3(0.18,0.12,0.19),selected*fill(-silhouette-0.015));
 return mix(c,rock,selected*smoothstep(0.015,0.030,silhouette));
}

void fragment() { COLOR=vec4(timber_with_rock_insets(UV),1.0); }
