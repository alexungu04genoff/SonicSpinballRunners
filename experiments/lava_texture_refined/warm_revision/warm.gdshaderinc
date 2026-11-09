// Reopened Phase 2 direction: warm mineral decks, charcoal geology, dark iron.
// Shared deterministic shape helpers come from the preceding selected study.
const vec3 CHARCOAL_JOINT = vec3(0.12,0.105,0.13);
const vec3 IRON_EDGE = vec3(0.14,0.15,0.17);
const vec3 IRON_FACE = vec3(0.27,0.28,0.29);

vec3 warm_basalt(vec2 uv) {
 float x=uv.x*8.0, base=floor(x), best=100.0, id=base, site=0.0;
 for(int index=-1;index<=1;index++) {
  float candidate=base+float(index);
  float position=column_site(candidate,uv.y);
  float distance=abs(position-x);
  if(distance<best) { best=distance; id=candidate; site=position; }
 }
 float left=(column_site(id-1.0,uv.y)+site)*0.5;
 float right=(column_site(id+1.0,uv.y)+site)*0.5;
 float horizontal=(x-left)/(right-left);
 float wrapped=mod(id,8.0), tone=hash(vec2(wrapped,41.0));
 float vertical=uv.y*2.0+hash(vec2(wrapped,15.0))+horizontal*(tone-0.5)*0.22;
 vec2 q=vec2(horizontal,fract(vertical));
 float cell_tone=hash(vec2(wrapped,mod(floor(vertical),2.0)+27.0));
 vec3 c=mix(vec3(0.20,0.18,0.205),vec3(0.31,0.285,0.30),tone*0.7+cell_tone*0.3);
 float plane=floor(clamp(1.0-abs(horizontal*2.0-1.0),0.0,0.999)*3.0)/2.0;
 c*=0.84+plane*0.17;
 float vertical_edge=min(q.x,1.0-q.x), cross_edge=min(q.y,1.0-q.y);
 c=mix(vec3(0.19,0.17,0.205),c,smoothstep(0.025,0.065,vertical_edge));
 c=mix(CHARCOAL_JOINT,c,smoothstep(0.004,0.014,vertical_edge));
 c=mix(CHARCOAL_JOINT,c,smoothstep(0.006,0.018,cross_edge));
 vec2 ore=q-vec2(0.38+cell_tone*0.24,0.61);
 float lens=fill(abs(ore.x)*0.45+abs(ore.y)*2.8-0.12)*step(0.79,cell_tone);
 return mix(c,mix(BRASS,BRASS_FACE,step(0.0,ore.x+ore.y*0.8)),lens);
}

vec3 orange_mineral_slabs(vec2 uv) {
 vec2 p=uv*vec2(3.0,4.0);
 float row=floor(p.y);
 p.x+=mod(row,2.0)*0.5;
 vec2 id=mod(floor(p),vec2(3.0,4.0)), q=fract(p)-0.5;
 float tone=hash(id+vec2(61.0,17.0));
 float corner=0.055+hash(id+44.0)*0.075;
 // Broad fitted mineral plates have irregular clipped corners and planar rims.
 float silhouette=octagon(q,vec2(0.482,0.476),corner);
 float face=octagon(q,vec2(0.402,0.387),corner*0.78);
 float sector=floor((atan(q.y,q.x)+3.14159265)*0.95493);
 float facet=fract(sector*0.381966+tone*0.3);
 vec3 rim=mix(vec3(0.43,0.255,0.18),vec3(0.72,0.43,0.235),facet);
 vec3 center=mix(vec3(0.67,0.355,0.17),vec3(0.84,0.53,0.255),tone);
 float pale_face=step(0.77,tone)*step(0.12,q.x*0.6-q.y*0.4);
 center=mix(center,vec3(0.88,0.65,0.35),pale_face*0.52);
 float broad_plane=step(0.13+tone*0.12,q.x*0.7+q.y*0.8);
 center*=0.975+broad_plane*0.045;
 return mix(CHARCOAL_JOINT,mix(rim,center,face),silhouette);
}

vec3 iron_retaining_bays(vec2 uv) {
 vec3 c=warm_basalt(uv);
 vec2 q=vec2(fract(uv.x*2.0),uv.y)-0.5;
 float perimeter=min(0.5-abs(q.x),0.5-abs(q.y));
 c=mix(c,CHARCOAL_JOINT,1.0-smoothstep(0.090,0.098,perimeter));
 c=mix(c,IRON_EDGE,1.0-smoothstep(0.072,0.080,perimeter));
 c=mix(c,IRON_FACE,1.0-smoothstep(0.046,0.058,perimeter));
 c=mix(c,vec3(0.36,0.36,0.37),band(perimeter-0.028,0.009));
 c=mix(c,IRON_EDGE,1.0-smoothstep(0.010,0.018,perimeter));
 vec2 corner=abs(q)-vec2(0.439);
 c=mix(c,BRASS_EDGE,octagon(corner,vec2(0.060),0.019));
 c=mix(c,BRASS,octagon(corner,vec2(0.049),0.016));
 c=mix(c,BRASS_FACE,octagon(corner,vec2(0.036),0.013));
 return fastener(c,corner,0.018);
}

void fragment() {
 vec3 c=vec3(0.0);
 if(item==3) c=warm_basalt(UV);
 else if(item==5) c=orange_mineral_slabs(UV);
 else if(item==9) c=iron_retaining_bays(UV);
 COLOR=vec4(c,1.0);
}
