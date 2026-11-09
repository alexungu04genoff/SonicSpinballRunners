// Phase 2 revision requested by Alex: meet between the two floor values and
// use the same mineral palette and broad facets for the ground and timber insets.
uniform float rock_gain = 1.0;
uniform float wood_gain = 0.88;

vec3 mineral_joint() { return vec3(0.28,0.20,0.26)*rock_gain; }

vec3 mineral_rock(vec2 offset, float tone, float silhouette) {
 float facet=floor((atan(offset.y,offset.x)+3.14159265)*0.95493);
 // Facet colors vary by rock, rather than baking a global light direction.
 float plane=fract(facet*0.381966+tone*0.6);
 vec3 rim=mix(vec3(0.43,0.28,0.23),vec3(0.65,0.425,0.25),plane);
 vec3 face=mix(vec3(0.68,0.475,0.28),vec3(0.77,0.575,0.34),tone);
 float aa=max(fwidth(silhouette)*0.65,0.003);
 return mix(rim,face,smoothstep(0.235-aa,0.235+aa,silhouette))*rock_gain;
}

float original_floor_hash(vec2 p) {
 // Match the periodic construction of the current floor, retaining its layout.
 return fract(sin(dot(mod(p,vec2(8.0)),vec2(127.1,311.7)))*43758.5453);
}

vec3 balanced_floor(vec2 uv) {
 vec2 p=uv*8.0, cell=floor(p), offset=vec2(0.0);
 float nearest=8.0, second=8.0, tone=0.0;
 for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
  vec2 id=cell+vec2(float(x),float(y));
  vec2 site=id+0.5+(vec2(original_floor_hash(id),original_floor_hash(id+19.0))-0.5)*0.65;
  vec2 delta=p-site;
  float distance_sq=dot(delta,delta);
  if(distance_sq<nearest) {
   second=nearest; nearest=distance_sq; offset=delta; tone=original_floor_hash(id+41.0);
  } else { second=min(second,distance_sq); }
 }
 float clipped=max(abs(offset.x)*0.85+abs(offset.y)*0.52,abs(offset.y)*0.85+abs(offset.x)*0.52);
 float silhouette=min(second-nearest,0.68-clipped);
 float aa=max(fwidth(silhouette)*0.65,0.003);
 return mix(mineral_joint(),mineral_rock(offset,tone,silhouette),smoothstep(0.025-aa,0.055+aa,silhouette));
}

vec3 balanced_timber(vec2 uv) {
 vec3 timber=orange_timber(uv)*wood_gain;
 vec2 offset,site,id;
 float edge;
 inset_cell(uv,offset,site,id,edge);
 // Keep the approved plank pattern and the two approved inset cluster locations.
 vec2 a=abs(fract(site-vec2(0.24,0.32)+0.5)-0.5)/vec2(0.19,0.16);
 vec2 b=abs(fract(site-vec2(0.74,0.72)+0.5)-0.5)/vec2(0.19,0.20);
 float selected=1.0-step(1.0,min(length(a),length(b)));
 float clipped=max(abs(offset.x)*0.85+abs(offset.y)*0.52,abs(offset.y)*0.85+abs(offset.x)*0.52);
 // Convert true Voronoi edge distance to the broad bevel convention of the floor.
 float silhouette=min(edge*2.0,0.68-clipped);
 float tone=hash(id+vec2(37.0,13.0));
 vec3 c=mix(timber,mineral_joint(),selected*fill(-silhouette-0.014));
 float aa=max(fwidth(silhouette)*0.65,0.003);
 return mix(c,mineral_rock(offset,tone,silhouette),selected*smoothstep(0.025-aa,0.055+aa,silhouette));
}

void fragment() { COLOR=vec4(item==1 ? balanced_floor(UV) : balanced_timber(UV),1.0); }
