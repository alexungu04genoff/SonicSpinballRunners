shader_type canvas_item;
render_mode unshaded;
uniform int item = 1;
uniform int option = 0;
const vec3 IVORY = vec3(.82,.82,.72);
const vec3 CREAM = vec3(.91,.86,.62);
const vec3 JOINT = vec3(.53,.58,.46);
const vec3 JADE = vec3(.38,.55,.27);
const vec3 BLUE = vec3(.18,.25,.37);
const vec3 TEAL = vec3(.28,.65,.64);
float line(float v,float w){return 1.0-smoothstep(w,w+.003,abs(v));}
float box(vec2 p,vec2 c,vec2 h){vec2 d=abs(p-c)-h;return 1.0-smoothstep(0.0,.003,max(d.x,d.y));}
float edge(vec2 p,float w){vec2 d=min(fract(p),1.0-fract(p));return 1.0-smoothstep(w,w+.006,min(d.x,d.y));}
vec3 blocks(vec2 p,vec3 base){
 p.x+=mod(floor(p.y),2.0)*.5;
 float v=mod(floor(p.x)+floor(p.y)*2.0,3.0);
 return mix(base+vec3((v-1.0)*.018),JOINT,edge(p,.013));
}
// A periodic polyomino partition: no photographic texture or height inference.
vec3 interlock(vec2 uv,vec3 base,vec3 seam){
 vec2 p=uv*3.0;
 float row=floor(p.y);
 p.x+=mod(row,2.0)*.5;
 float x=fract(p.x);
 float y=fract(p.y);
 float seam_y=line(y-.0,.010)+line(y-1.0,.010);
 float jog=.50+(.10*step(.30,y)-.10*step(.68,y));
 float cut=line(x-jog,.010);
 cut=max(cut,line(y-.30,.010)*box(vec2(x,0),vec2(.55,0),vec2(.05,1)));
 cut=max(cut,line(y-.68,.010)*box(vec2(x,0),vec2(.55,0),vec2(.05,1)));
 float tone=step(jog,x)*.025;
 return mix(base+tone,seam,clamp(max(cut,seam_y),0.0,1.0));
}
vec3 mosaic(vec2 uv,vec3 base){
 vec2 p=uv*4.0;
 vec3 c=blocks(p,base);
 vec2 q=fract(p);
 float diamond=1.0-smoothstep(.11,.12,abs(q.x-.5)+abs(q.y-.5));
 float select=1.0-step(.5,mod(floor(p.x)+floor(p.y),3.0));
 return mix(c,TEAL,diamond*select);
}
vec3 trim(vec2 uv,bool green,bool ornate){
 vec3 c=mix(IVORY,CREAM,float(ornate));
 if(green)c=JADE;
 float band=line(uv.y-.12,.022)+line(uv.y-.88,.022);
 c=mix(c,green?IVORY:JOINT,clamp(band,0.0,1.0));
 if(ornate){
  vec2 q=vec2(fract(uv.x*8.0),uv.y);
  float v=line(q.y-(.29+abs(q.x-.5)*.8),.026);
  c=mix(c,green?CREAM:JADE,v);
 }else c=mix(c,JOINT,line(fract(uv.x*8.0),.012));
 return c;
}
float arch(vec2 p,float width,float crown,float bottom){
 float d=max(abs(p.x-.5)-width,p.y-bottom);
 if(p.y<crown)d=max(d,length(vec2(p.x-.5,p.y-crown))-width);
 return 1.0-smoothstep(0.0,.005,d);
}
vec3 facade(vec2 uv,bool panels){
 vec3 c=blocks(uv*vec2(8,4),panels?CREAM:IVORY);
 vec2 q=vec2(fract(uv.x*4.0),uv.y);
 if(panels){
  c=mix(c,JOINT,box(q,vec2(.5,.52),vec2(.35,.29)));
  c=mix(c,IVORY,box(q,vec2(.5,.52),vec2(.31,.25)));
  c=mix(c,JADE,box(q,vec2(.5,.52),vec2(.19,.14)));
  c=mix(c,CREAM,box(q,vec2(.5,.52),vec2(.14,.09)));
 }else{
  c=mix(c,JOINT,arch(q,.29,.40,.77));
  c=mix(c,CREAM,arch(q,.25,.40,.74));
  c=mix(c,BLUE,arch(q,.19,.40,.70));
 }
 c=mix(c,JADE,1.0-step(.08,uv.y));
 c=mix(c,CREAM,line(uv.y-.12,.025)+line(uv.y-.87,.025));
 return c;
}
void fragment(){
 vec2 uv=UV;
 bool b=option==1;
 vec3 c=IVORY;
 if(item==1)c=b?mosaic(uv,CREAM):interlock(uv,IVORY,JOINT);
 if(item==2)c=trim(uv,b,b);
 if(item==3){
  if(b){
   c=blocks(uv*vec2(8,4),CREAM);
   vec2 q=vec2(fract(uv.x*4.0),uv.y);
   c=mix(c,JADE,box(q,vec2(.5,.5),vec2(.13,.43)));
   c=mix(c,IVORY,box(q,vec2(.5,.5),vec2(.045,.43)));
  }else c=interlock(uv*vec2(1.5,.65),IVORY,JOINT);
  c=mix(c,CREAM,line(uv.y-.08,.025)+line(uv.y-.92,.025));
 }
 if(item==5){
  if(b){
   c=blocks(uv*4.0,IVORY);
   vec2 q=fract(uv*2.0)-.5;
   float ring=line(length(q)-.32,.045);
   float bars=max(line(q.x,.025),line(q.y,.025));
   c=mix(c,TEAL,ring);
   c=mix(c,IVORY,bars);
  }else c=interlock(uv,BLUE,TEAL);
 }
 if(item==6)c=trim(uv,!b,b);
 if(item==7){
  if(b)c=interlock(uv*vec2(.65,1.0),BLUE,TEAL);
  else{
   c=blocks(vec2(uv.x*2.0,uv.y*5.0),IVORY);
   c=mix(c,JADE,step(.40,abs(uv.x-.5)));
   c=mix(c,CREAM,line(abs(uv.x-.5)-.40,.014));
  }
 }
 if(item==8){
  c=trim(uv,false,b);
  if(!b)c=mix(c,TEAL,line(uv.y-.5,.07));
 }
 if(item==9)c=facade(uv,b);
 COLOR=vec4(c,1.0);
}
