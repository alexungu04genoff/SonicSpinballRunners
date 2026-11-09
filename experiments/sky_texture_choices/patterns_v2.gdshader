shader_type canvas_item;
render_mode unshaded;
uniform int item = 1;
uniform int option = 0;
// Color-only structural studies. No height inferred from albedo.
const vec3 IVORY=vec3(.78,.79,.69), CREAM=vec3(.86,.83,.61);
const vec3 JOINT=vec3(.43,.48,.38), GREEN=vec3(.40,.53,.23);
const vec3 BLUE=vec3(.22,.28,.38), TEAL=vec3(.26,.60,.59);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float line(float v,float w){return 1.0-smoothstep(w,w+.006,abs(v));}
float box(vec2 p,vec2 c,vec2 h){vec2 d=abs(p-c)-h;return 1.0-smoothstep(0.0,.005,max(d.x,d.y));}
float sd_box(vec2 p,vec2 c,vec2 h){vec2 d=abs(p-c)-h;return max(d.x,d.y);}
vec3 face(vec2 p,vec3 base,float seed){
 float broad=noise(p*1.8+seed*3.0)-.5;
 float plane=smoothstep(.43,.53,noise(p*3.0+seed*9.0))-.5;
 return base+vec3(broad*.035+plane*.012)+vec3(.023,.014,-.013)*(seed-.5);
}
vec3 stone(vec2 p,vec3 base,float seed,float d,bool azure){
 vec3 c=face(p,base+(seed-.5)*.075,seed);
 vec3 seam=azure?BLUE*.72:JOINT;
 c=mix(mix(c,seam,.22),c,smoothstep(.020,.075,d));
 c=mix(seam,c,smoothstep(.008,.024,d));
 if(azure)c=mix(c,TEAL,line(d-.013,.004)*.68);
 return c;
}
// Five fitted stones fill each 4x4 module; joins include concave corners.
float tile_id(vec2 cell){
 vec2 q=mod(cell,4.0);float id=0.0;
 if(q.y<1.0)id=q.x<2.0?0.0:1.0;
 else if(q.y<2.0)id=q.x<1.0?0.0:(q.x<3.0?2.0:1.0);
 else if(q.y<3.0)id=q.x<1.0?3.0:(q.x<2.0?2.0:4.0);
 else id=q.x<3.0?3.0:4.0;
 vec2 m=floor(cell/4.0);return id+m.x*7.0+m.y*101.0;
}
vec3 fitted(vec2 p,vec3 base,bool azure){
 vec2 cell=floor(p),q=fract(p);float id=tile_id(cell),d=2.0;
 if(tile_id(cell+vec2(-1,0))!=id)d=min(d,q.x);
 if(tile_id(cell+vec2(1,0))!=id)d=min(d,1.0-q.x);
 if(tile_id(cell+vec2(0,-1))!=id)d=min(d,q.y);
 if(tile_id(cell+vec2(0,1))!=id)d=min(d,1.0-q.y);
 for(int x=-1;x<=1;x+=2){for(int y=-1;y<=1;y+=2){
  if(tile_id(cell+vec2(float(x),float(y)))!=id)d=min(d,length(q-vec2(x<0?0.0:1.0,y<0?0.0:1.0)));
 }}
 return stone(p,base,hash(vec2(mod(id,101.0),mod(id,7.0))),d,azure);
}
vec3 courses(vec2 p,vec3 base){
 p.x+=mod(floor(p.y),2.0)*.5;vec2 q=fract(p),e=min(q,1.0-q);
 return stone(p,base,hash(mod(floor(p),vec2(8.0))),min(e.x,e.y),false);
}
vec3 molding(vec2 uv,vec3 base){
 float edge=min(uv.y,1.0-uv.y);vec3 c=face(vec2(uv.x*12.0,uv.y),base,.3);
 c=mix(JOINT,c,smoothstep(.005,.045,edge));
 c=mix(c,base+.055,line(edge-.10,.027));
 return mix(c,base*.84,line(edge-.20,.018));
}
vec3 chevrons(vec2 uv){
 vec3 c=courses(vec2(uv.x*6.0,uv.y),IVORY);vec2 q=vec2(fract(uv.x*6.0),uv.y);
 float v=abs(q.y-(.24+abs(q.x-.5)*.86));float zone=step(.19,uv.y)*(1.0-step(.82,uv.y));
 c=mix(c,JOINT,(1.0-smoothstep(.09,.12,v))*zone);
 c=mix(c,CREAM,(1.0-smoothstep(.065,.084,v))*zone);
 c=mix(c,IVORY+.04,(1.0-smoothstep(.026,.043,v))*zone);
 return mix(c,molding(uv,IVORY),1.0-zone);
}
vec3 crown(vec2 uv){
 vec3 c=courses(vec2(uv.x*8.0,uv.y),IVORY);
 c=mix(c,courses(vec2(uv.x*8.0,uv.y),GREEN),box(uv,vec2(.5),vec2(.6,.25)));
 return mix(c,CREAM,line(uv.y-.22,.028)+line(uv.y-.78,.028));
}
float arch_distance(vec2 p,float width,float crown_y,float bottom){
 float d=max(abs(p.x-.5)-width,p.y-bottom);
 if(p.y<crown_y)d=max(d,length(vec2(p.x-.5,p.y-crown_y))-width);return d;
}
vec3 arcade(vec2 uv,bool small){
 vec3 c=courses(uv*vec2(12,5),IVORY);vec2 q=vec2(fract(uv.x*4.0),uv.y);
 float d=arch_distance(q,small?.19:.31,small?.38:.34,small?.66:.85);
 float seed=hash(vec2(floor(uv.x*4.0),2.0));
 c=mix(c,JOINT,1.0-smoothstep(.045,.055,d));
 c=mix(c,face(q*3.0,CREAM,seed),1.0-smoothstep(-.018,-.008,d));
 float a=atan(q.y-(small?.38:.34),q.x-.5);
 float wedge=line(fract((a+3.141593)/3.141593*7.0),.025);
 float zone=(1.0-step(small?.38:.34,q.y))*step(-.065,d)*(1.0-step(.04,d));
 c=mix(c,JOINT,wedge*zone);
 c=mix(c,face(q*2.0,vec3(.32,.39,.37),seed),1.0-smoothstep(-.080,-.070,d));
 return mix(c,IVORY+.045,box(q,vec2(.5,small?.70:.88),vec2(small?.26:.39,.018)));
}
vec3 coffers(vec2 uv){
 vec3 c=courses(uv*vec2(8,4),CREAM);vec2 q=vec2(fract(uv.x*4.0),uv.y);
 float d=sd_box(q,vec2(.5,.54),vec2(.37,.30));float seed=hash(vec2(floor(uv.x*4.0),9.0));
 c=mix(c,JOINT,1.0-smoothstep(.0,.006,d));
 c=mix(c,face(q*3.0,IVORY+.035,seed),1.0-smoothstep(-.032,-.026,d));
 c=mix(c,face(q*3.0,IVORY*.87,seed),1.0-smoothstep(-.075,-.069,d));
 c=mix(c,face(q*3.0,GREEN*.83,seed),1.0-smoothstep(-.105,-.099,d));
 return mix(c,face(q*3.0,IVORY,seed),1.0-smoothstep(-.151,-.145,d));
}
vec3 relic_floor(vec2 uv){
 vec3 c=fitted(uv*8.0,IVORY,false);vec2 p=fract(uv)-.5;float r=length(p),a=atan(p.y,p.x);
 float sector=step(.16,r)*(1.0-step(.43,r));
 vec3 inset=face(uv*9.0,TEAL*.78,.42);
 inset+=vec3(.03,.055,.045)*(floor(noise(uv*10.0)*4.0)/4.0-.5);
 c=mix(c,inset,sector);
 float rib=max(line(r-.29,.027),line(sin(a*4.0)*r,.019));
 c=mix(c,JOINT,rib*sector);
 c=mix(c,IVORY+.025,max(line(r-.29,.019),line(sin(a*4.0)*r,.012))*sector);
 c=mix(c,CREAM,line(r-.16,.012)+line(r-.43,.012));
 return mix(c,JOINT,line(r-.445,.005));
}
void fragment(){
 vec2 uv=UV;bool b=option==1;vec3 c=IVORY;
 if(item==1)c=b?courses(uv*vec2(6,8),CREAM):fitted(uv*8.0,IVORY,false);
 if(item==2){
  c=b?crown(uv):molding(uv,IVORY);
  if(!b){vec2 q=vec2(fract(uv.x*12.0),uv.y);
   c=mix(c,JOINT,box(q,vec2(.5),vec2(.27,.24))*.55);
   c=mix(c,IVORY+.025,box(q,vec2(.5),vec2(.20,.19)));
  }
 }
 if(item==3){
  if(b){
   c=courses(uv*vec2(12,7),CREAM);vec2 q=vec2(fract(uv.x*3.0),uv.y);
   vec3 column=courses(vec2(q.x*5.0,q.y*6.0),GREEN);
   column=mix(column,CREAM,line(q.x-.36,.018)+line(q.x-.64,.018));
   column=mix(column,IVORY,line(q.x-.5,.035)*.6);
   c=mix(c,column,box(q,vec2(.5),vec2(.18,.43)));
   c=mix(c,IVORY,box(q,vec2(.5,.16),vec2(.24,.040))+box(q,vec2(.5,.84),vec2(.24,.040)));
   c=mix(c,GREEN*.64,box(q,vec2(.5,.23),vec2(.18,.023))+box(q,vec2(.5,.77),vec2(.18,.023)));
  }else{
   c=fitted(uv*vec2(12,4),IVORY,false);
   if(uv.y>.61)c=arcade(vec2(uv.x,(uv.y-.61)/.39),false);
  }
  if(uv.y<.09||uv.y>.93)c=molding(vec2(uv.x,fract(uv.y*12.0)),CREAM);
 }
 if(item==5)c=b?relic_floor(uv):fitted(uv*8.0,BLUE,true);
 if(item==6)c=b?chevrons(uv):crown(uv);
 if(item==7){
  if(b)c=fitted(uv*vec2(4,8),BLUE,true);
  else{
   c=courses(uv*vec2(3,6),IVORY);float side=abs(uv.x-.5);
   c=mix(c,courses(uv*vec2(8,8),GREEN),step(.37,side));
   c=mix(c,CREAM,line(side-.37,.018)+line(side-.47,.010));
  }
 }
 if(item==8){
  c=b?chevrons(uv):molding(uv,IVORY);
  if(!b){
   c=mix(c,fitted(vec2(uv.x*8.0,uv.y*4.0),BLUE,true),box(uv,vec2(.5),vec2(.6,.19)));
   c=mix(c,IVORY+.04,line(uv.y-.29,.018)+line(uv.y-.71,.018));
  }
 }
 if(item==9){
  c=b?coffers(uv):arcade(uv,true);
  if(!b&&uv.y>.76)c=chevrons(vec2(uv.x,(uv.y-.76)/.24));
  if(b&&uv.y<.19)c=molding(vec2(uv.x,uv.y/.19),IVORY);
  if(uv.y<.055)c=face(uv*vec2(12,3),GREEN,.7);
 }
 COLOR=vec4(clamp(c,0.0,1.0),1.0);
}
