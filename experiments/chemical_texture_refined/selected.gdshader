shader_type canvas_item;
render_mode unshaded;
uniform int item = 2;
// Existing Chemical Plant albedo palette, expressed as stored PNG RGB values.
const vec3 STEEL = vec3(125.0,143.0,163.0)/255.0;
const vec3 PALE = vec3(178.0,184.0,171.0)/255.0;
const vec3 DARK = vec3(31.0,48.0,77.0)/255.0;
const vec3 SLOT = vec3(14.0,20.0,36.0)/255.0;
const vec3 YELLOW = vec3(240.0,173.0,20.0)/255.0;
const vec3 OCHRE = vec3(127.0,99.0,11.0)/255.0;
const vec3 BLUE = vec3(36.0,90.0,202.0)/255.0;
float rect(vec2 p, vec2 center, vec2 half_size) {
 vec2 d=abs(p-center)-half_size;
 float edge=max(d.x,d.y);
 float aa=max(fwidth(edge)*.65,.0002);
 return 1.0-smoothstep(-aa,aa,edge);
}
float band(float x,float width) {
 float aa=max(fwidth(x)*.65,.0002);
 return 1.0-smoothstep(width-aa,width+aa,abs(x));
}
float circle(vec2 p,vec2 center,float radius) {
 float d=length(p-center);
 float aa=max(fwidth(d)*.65,.0002);
 return 1.0-smoothstep(radius-aa,radius+aa,d);
}
float chamfer(vec2 p,vec2 half_size,float corner) {
 vec2 d=abs(p-.5);
 float edge=max(max(d.x-half_size.x,d.y-half_size.y),d.x+d.y-half_size.x-half_size.y+corner);
 float aa=max(fwidth(edge)*.65,.0002);
 return 1.0-smoothstep(-aa,aa,edge);
}
vec3 ramp(vec2 uv) {
 vec2 p=uv*vec2(2.0,4.0),q=fract(p);
 float variation=mod(floor(p.x)+floor(p.y),2.0);
 vec3 c=mix(STEEL,vec3(122.0,145.0,163.0)/255.0,variation*.4);
 vec2 edge=min(q,1.0-q);
 c=mix(c,DARK,1.0-smoothstep(.009,.018,min(edge.x,edge.y)));
 float bolts=circle(abs(q-.5),vec2(.40,.39),.012);
 c=mix(c,vec3(48.0,56.0,64.0)/255.0,bolts);
 c=mix(c,SLOT,band(abs(uv.x-.5)-.404,.008));
 c=mix(c,OCHRE,smoothstep(.425,.429,abs(uv.x-.5)));
 return c;
}
void fragment() {
 vec2 uv=UV;
 vec3 c=STEEL;
 if(item==2) {
  // Four hazard modules repeat along the strip; across-strip coordinates stay fixed.
  float phase=fract(uv.x*4.0+uv.y*.45);
  float stripe=smoothstep(.497,.503,phase)*(1.0-smoothstep(.994,1.0,phase));
  c=mix(c,mix(SLOT,YELLOW,stripe),rect(uv,vec2(.5),vec2(1,.265)));
  c=mix(c,PALE,band(uv.y-.10,.035)+band(uv.y-.90,.035));
  c=mix(c,DARK,band(uv.y-.225,.012)+band(uv.y-.775,.012));
 } else if(item==5) {
  // Two by two complete access plates; clean chamfers, broad tread faces.
  vec2 p=uv*2.0,q=fract(p);
  c=DARK;
  c=mix(c,YELLOW*.83,chamfer(q,vec2(.482),.065));
  c=mix(c,YELLOW,chamfer(q,vec2(.461),.065));
  c=mix(c,PALE,chamfer(q,vec2(.308,.345),.025));
  c=mix(c,SLOT,chamfer(q,vec2(.287,.323),.025));
  c=mix(c,vec3(.28,.32,.35),rect(q,vec2(.5),vec2(.255,.29)));
  float rib=band(fract(q.y*8.0)-.5,.055)*rect(q,vec2(.5),vec2(.255,.29));
  c=mix(c,SLOT,rib);
  float bolts=circle(abs(q-.5),vec2(.394,.39),.013);
  c=mix(c,DARK,bolts);
 } else if(item==6) {
  vec2 q=vec2(fract(uv.x*4.0),uv.y);
  c=mix(c,PALE,band(uv.y-.05,.025)+band(uv.y-.95,.025));
  c=mix(c,YELLOW,band(uv.y-.18,.045));
  c=mix(c,DARK,band(uv.y-.58,.105));
  c=mix(c,vec3(76.0,97.0,123.0)/255.0,rect(q,vec2(.5,.58),vec2(.30,.055)));
  c=mix(c,DARK,circle(q,vec2(.5,.83),.018));
 } else if(item==7) c=ramp(uv);
 else if(item==8) {
  vec2 q=vec2(fract(uv.x*4.0),uv.y);
  c=BLUE;
  c=mix(c,DARK,band(q.x-.5,.046));
  c=mix(c,STEEL,band(q.x-.5,.031));
  c=mix(c,PALE,band(uv.y-.10,.045)+band(uv.y-.90,.045));
  c=mix(c,YELLOW,rect(q,vec2(.78,.5),vec2(.07,.13)));
  c=mix(c,DARK,circle(q,vec2(.5,.30),.016)+circle(q,vec2(.5,.70),.016));
 } else if(item==10) {
  // Flat enamel and collar bands: geometry, not painted highlights, supplies curvature.
  vec2 q=vec2(fract(uv.x*2.0),uv.y);
  c=BLUE;
  c=mix(c,SLOT,band(q.x-.5,.115));
  c=mix(c,STEEL,band(q.x-.5,.091));
  c=mix(c,DARK,band(q.x-.5,.010));
 }
 COLOR=vec4(c,1.0);
}
