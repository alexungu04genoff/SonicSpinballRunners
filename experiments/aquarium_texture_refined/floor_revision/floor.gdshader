shader_type canvas_item;
render_mode unshaded;
uniform int view=0;
const vec3 RED=vec3(.59,.145,.105);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
vec2 hash2(vec2 p){return vec2(hash(p),hash(p+vec2(27.2,13.7)));}
float line(float x,float w){float aa=max(fwidth(x)*.8,.0005);return 1.-smoothstep(w-aa,w+aa,abs(x));}
vec3 flagstone(vec2 uv){
 // Periodic Voronoi stones with true cell-boundary distances, not brightness-derived relief.
 vec2 p=uv*12.;vec2 base=floor(p),f=fract(p),nearest=vec2(0),chosen=vec2(0);float best=100.;
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  vec2 cell=vec2(float(x),float(y));vec2 id=mod(base+cell,12.);vec2 offset=.18+hash2(id)*.64;
  vec2 d=cell+offset-f;float dist=dot(d,d);
  if(dist<best){best=dist;nearest=d;chosen=cell;}
 }}
 float edge_distance=100.;
 for(int y=-2;y<=2;y++){for(int x=-2;x<=2;x++){
  vec2 cell=chosen+vec2(float(x),float(y));vec2 id=mod(base+cell,12.);vec2 d=cell+.18+hash2(id)*.64-f;
  if(dot(d-nearest,d-nearest)>.0001)edge_distance=min(edge_distance,dot((nearest+d)*.5,normalize(d-nearest)));
 }}
 vec2 tint=hash2(mod(base+chosen,12.));
 vec3 face=vec3(.695,.713,.655)+vec3((tint.x-.5)*.085,(tint.x-.5)*.075,(tint.y-.5)*.065);
 float broad=sin(nearest.x*3.1+nearest.y*2.3+tint.x*6.28);
 face+=vec3(.010,.011,.009)*broad;
 float aa=max(fwidth(edge_distance),.002);
 vec3 c=mix(vec3(.385,.425,.385),face,smoothstep(.013-aa,.025+aa,edge_distance));
 c=mix(c,face*.94,line(edge_distance-.038,.009)*.55);
 return c;
}
vec3 blue_panel(vec2 p){
 vec3 c=vec3(.105,.385,.525);
 c+=vec3(.009,.015,.016)*sin(p.x*TAU*2.+sin(p.y*TAU))*sin(p.y*TAU*2.);
 float edge_tint=pow(abs(p.x*2.-1.),5.);c=mix(c,vec3(.32,.68,.70),edge_tint*.63);
 float center=.5+.205*sin(p.y*TAU);
 float ribbon=1.-smoothstep(.145,.19,abs(p.x-center));
 c=mix(c,vec3(.28,.57,.64),ribbon*.25);
 vec2 grid=p*vec2(20,20);grid.x+=mod(floor(grid.y),2.)*.5;
 vec2 q=fract(grid)-.5;float scales=1.-smoothstep(.24,.35,abs(q.x)+abs(q.y)*1.3);
 c=mix(c,vec3(.11,.32,.43),ribbon*scales*.28);
 // The same border width in X and Y makes a genuine square module.
 float d=min(min(p.x,1.-p.x),min(p.y,1.-p.y));
 c=mix(c,RED,1.-smoothstep(.020,.026,d));
 c=mix(c,vec3(.32,.085,.065),line(d-.028,.0025)*.65);
 return c;
}
void fragment(){
 vec3 c;
 if(view==1)c=flagstone(UV);
 else if(view==2)c=blue_panel(UV);
 else{
  vec2 cells=UV*6.,id=floor(cells),p=fract(cells);
  c=flagstone(UV);
  // Reference layout: broad central paving, square side insets, occasional crossing.
  bool inset=id.x<1. || id.x>4. || id.y==3.;
  if(inset)c=blue_panel(p);
 }
 COLOR=vec4(c,1.);
}
