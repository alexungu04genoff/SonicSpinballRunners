shader_type canvas_item;
render_mode unshaded;
uniform int item=5;
uniform int option=0;
const vec3 SLATE=vec3(.58,.16,.12);
const vec3 DEEP=vec3(.25,.055,.045);
const vec3 COPPER=vec3(.31,.48,.43);
const vec3 RED=vec3(.53,.115,.08);
const vec3 GOLD=vec3(.73,.55,.25);
float line(float v,float w){return 1.-smoothstep(w,w+.003,abs(v));}
float box(vec2 p,vec2 c,vec2 h){vec2 d=abs(p-c)-h;return 1.-smoothstep(0.,.004,max(d.x,d.y));}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float segment(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.,1.));}
float scroll(vec2 p){float dist=2.;vec2 a=vec2(.31,0.);for(int i=1;i<=36;i++){float t=float(i)/36.;float angle=t*9.;vec2 b=vec2(cos(angle),sin(angle))*(.31-.26*t);dist=min(dist,segment(p,a,b));a=b;}return 1.-smoothstep(.014,.023,dist);}
// Each tile has deliberate ceramic color zones, never a directional cast shadow.
vec3 round_tiles(vec2 uv,vec2 repeats){
 vec2 p=uv*repeats;vec2 f=fract(p);vec2 id=mod(floor(p),repeats);
 float variation=(hash(id)-.5)*.065;
 float rib=1.-smoothstep(.19,.25,abs(f.x-.5));
 float pan=1.-smoothstep(.32,.47,abs(f.x-.5));
 vec3 c=SLATE+variation+vec3(.025,.035,.034)*pan;
 c=mix(c,DEEP+variation*.4,line(abs(f.x-.5)-.245,.018));
 c=mix(c,SLATE+vec3(.055,.063,.056)+variation,rib);
 c+=vec3(.006,.009,.009)*sin(f.y*6.283+hash(id)*3.);
 float end=.82+.065*cos((f.x-.5)*6.283);
 c=mix(c,DEEP,line(f.y-end,.014));
 c=mix(c,SLATE*.82,line(f.y-end+.035,.012));
 c=mix(c,DEEP,line(f.y,.012));
 return c;
}
vec3 shingles(vec2 uv,vec2 repeats){
 vec2 p=uv*repeats;float row=floor(p.y);p.x+=mod(row,2.)*.5;
 vec2 f=fract(p);vec2 id=mod(floor(p),repeats);float h=hash(id);
 float lo=.015+max(0.,.07-f.x)*.5+max(0.,f.x-.93)*.5;
 float hi=.978-max(0.,.06-f.x)*.6-max(0.,f.x-.94)*.6;
 float inside=smoothstep(lo-.006,lo+.006,f.y)*(1.-smoothstep(hi-.006,hi+.006,f.y));
 vec3 face=COPPER+vec3((h-.5)*.095,(h-.5)*.070,(h-.5)*.048);
 face+=vec3(.008,.012,.008)*sin(f.x*6.283)*sin(f.y*6.283);
 face=mix(face,COPPER*.72,line(f.x-.025,.012)+line(f.x-.975,.012));
 face=mix(face,vec3(.37,.51,.44),line(f.y-hi+.035,.016));
 vec3 c=mix(DEEP,face,inside);
 c=mix(c,DEEP,line(f.x,.009));return c;
}
vec3 timber(vec2 uv){
 vec3 c=RED+vec3(.025,.014,.009)*sin(uv.y*6.283);
 c+=vec3(.010,.007,.003)*sin(uv.y*35.+sin(uv.x*12.566)*.7);
 return c;
}
void fragment(){
 vec2 uv=UV;vec3 c;
 if(item==5){c=option==0?round_tiles(uv,vec2(6,4)):shingles(uv,vec2(4,6));}
 else if(item==6){
  // Horizontal roof-edge strip: same tile family and column rhythm as role 5.
  c=option==0?round_tiles(vec2(uv.x,uv.y*.25),vec2(6,4)):shingles(vec2(uv.x,uv.y/6.),vec2(4,6));
  c=mix(c,DEEP,step(.91,uv.y));
  c=mix(c,GOLD,line(uv.y-.94,.018));
  if(option==0){vec2 p=vec2(fract(uv.x*6.)-.5,(uv.y-.77)*1.3);float rim=line(length(p)-.14,.014);c=mix(c,SLATE+vec3(.06),rim);}
 }else{
  // Proposed transition is a fascia on existing upper wall faces, not a new ledge mesh.
  if(option==0){
   c=timber(uv);c=mix(c,vec3(.24,.09,.06),box(uv,vec2(.5,.53),vec2(2.,.16)));
   c=mix(c,GOLD,max(line(uv.y-.22,.021),line(uv.y-.79,.017)));
   vec2 p=vec2(fract(uv.x*4.),uv.y);float collar=box(p,vec2(.5,.50),vec2(.065,.35));c=mix(c,GOLD,collar);
   c=mix(c,RED,scroll((p-vec2(.5,.50))*2.0)*collar);
   c=mix(c,DEEP,step(uv.y,.09));
  }else{
   c=timber(uv)*.65;c=mix(c,GOLD,line(uv.y-.87,.016));
   vec2 p=vec2(fract(uv.x*6.)-.5,(uv.y-.40)*1.5);float r=length(p);
   float disk=1.-smoothstep(.30,.31,r);vec3 ceramic=SLATE+vec3(.026)*cos(r*5.);
   ceramic=mix(ceramic,DEEP,line(r-.255,.015));ceramic=mix(ceramic,SLATE+vec3(.10),scroll(p*.72));
   c=mix(c,ceramic,disk);
   c=mix(c,SLATE,box(vec2(fract(uv.x*6.),uv.y),vec2(.5,.07),vec2(.30,.07)));
  }
 }
 COLOR=vec4(c,1.);
}

