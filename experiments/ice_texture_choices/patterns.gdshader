shader_type canvas_item;
render_mode unshaded;
uniform int item = 1;
uniform int option = 0;
// Deterministic color-only studies. Graphic facets describe ice structure,
// without cast shadows, photographic wear, or generated response maps.
const vec3 SNOW = vec3(.88,.95,.98);
const vec3 FROST = vec3(.65,.83,.94);
const vec3 CYAN = vec3(.24,.66,.85);
const vec3 BLUE = vec3(.16,.38,.69);
const vec3 VIOLET = vec3(.35,.37,.65);
const vec3 DEEP = vec3(.12,.23,.46);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float line(float d,float w){return 1.0-smoothstep(w,w+.006,abs(d));}
float box(vec2 p,vec2 center,vec2 halfsize){vec2 d=abs(p-center)-halfsize;return 1.0-smoothstep(0.0,.006,max(d.x,d.y));}
float broad(vec2 p){return .5+.25*sin(TAU*p.x+sin(TAU*p.y))+.25*cos(TAU*p.y*2.0-TAU*p.x);}
// Periodic Voronoi cells provide broad, irregular glacier plates.
vec4 cells(vec2 p,vec2 period){
 vec2 cell=floor(p),f=fract(p),delta=vec2(0.0);float first=9.0,second=9.0,id=0.0;
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  vec2 g=vec2(float(x),float(y));vec2 key=mod(cell+g,period);
  vec2 center=vec2(.22)+.56*vec2(hash(key),hash(key+31.1));vec2 d=g+center-f;
  float dist=dot(d,d);
  if(dist<first){second=first;first=dist;delta=d;id=hash(key+17.8);}else{second=min(second,dist);}
 }}return vec4(delta,second-first,id);
}
vec3 plate(vec2 uv,vec2 count,bool pale){
 vec4 v=cells(uv*count,count);
 vec3 c=mix(BLUE,CYAN,v.w*.75);
 if(pale)c=mix(FROST,SNOW,.72+v.w*.25);
 float plane=step(v.x*.64,v.y+.12)*.05-step(-v.x*.9,v.y-.25)*.035;
 c+=vec3(plane)+(broad(uv)-.5)*.025;
 c=mix(c,pale?FROST:BLUE*.82,(1.0-smoothstep(.0,.055,v.z))*(pale?.07:.42));
 c=mix(c,pale?SNOW:vec3(.51,.79,.91),line(v.z-.09,.018)*.25);
 return c;
}
// Sonic 3's staggered crystal clusters: eight-sided masses with calm centers.
vec3 crystal_field(vec2 uv,vec2 count){
 vec2 p=uv*count;float row=floor(p.y);p.x+=mod(row,2.0)*.5;
 vec2 cell=floor(p),q=(fract(p)-.5)*2.0;float seed=hash(mod(cell,count));
 float d=max(max(abs(q.x),abs(q.y)),(abs(q.x)+abs(q.y))*.7071);
 float oct=1.0-smoothstep(.97,.99,d);
 vec3 c=mix(BLUE,VIOLET,seed*.7)*.95;
 float angle=atan(q.y,q.x);float sector=floor((angle+3.14159)/(.785398));
 vec3 face=mix(vec3(.31,.58,.85),vec3(.54,.48,.77),seed*.65);
 face=mix(face,vec3(.83,.95,1.0),mod(sector,3.0)*.27);
 face-=mod(sector+seed*3.0,2.0)*.08;
 face+=vec3(.065)*(1.0-d);
 float inner=1.0-smoothstep(.49,.52,d+q.x*.11-q.y*.08);
 vec3 heart=mix(vec3(.26,.48,.78),vec3(.46,.61,.86),seed);
 heart+=vec3(.08)*clamp(q.y*.65-q.x*.42+.2,0.0,1.0);
 heart=mix(heart,vec3(.59,.83,.96),step(q.y,q.x*.48-.11)*.42);
 heart=mix(heart,VIOLET,step(q.y,-q.x*.81-.31)*.26);
 face=mix(face,heart,inner);
 c=mix(c,face,oct);
 // Small connecting facets prevent the gaps becoming a heavy mortar grid.
 float corner=step(.99,d)*line(abs(q.x)-abs(q.y),.25);
 c=mix(c,mix(vec3(.36,.53,.82),FROST,step(q.x*q.y,0.0)*.35),corner*.8);
 return mix(c,SNOW,line(d-.93,.018)*.15);
}
// Sonic Advance's cut ice blocks: broad chamfers and restrained diagonal inclusions.
vec3 cut_ice(vec2 uv,vec2 count){
 vec2 p=uv*count;p.x+=mod(floor(p.y),2.0)*.5;vec2 q=fract(p);
 float seed=hash(mod(floor(p),count));vec2 e=min(q,1.0-q);
 float d=min(min(e.x,e.y),(e.x+e.y-.085)*.707);
 vec3 c=mix(vec3(.26,.61,.84),vec3(.43,.58,.82),seed);
 c+=step(q.y,q.x*.64+.13)*.085+(q.y-.5)*.04;
 c=mix(c,VIOLET,step(q.y,-q.x*.85+.45)*.22);
 vec3 bevel=mix(vec3(.32,.47,.77),FROST,step(q.y,q.x)*.7+.1);
 c=mix(c,bevel,(1.0-smoothstep(.10,.13,d))*.82);
 c=mix(DEEP*.95,c,smoothstep(.004,.018,d));
 float slash=line(q.y-q.x*.8-.05,.067)+line(q.y-q.x*.8-.30,.023);
 return mix(c,vec3(.70,.90,.97),slash*.30*step(.15,d));
}
vec3 snow_surface(vec2 uv,int kind){
 // Broad compressed snow shelves, not granular noise or repeated glyphs.
 vec4 v=cells(uv*vec2(4,4),vec2(4,4));
 float drift_mass=broad(uv);
 vec3 c=mix(vec3(.78,.88,.94),SNOW,smoothstep(.05,.77,drift_mass));
 c+=vec3(.018)*(v.w-.5);
 float ridge=sin(TAU*(uv.y*2.0+uv.x*.1)+sin(TAU*uv.x)*.48);
 c=mix(c,FROST,line(ridge-.70,.06)*.085);
 float drift=sin(TAU*uv.x+sin(TAU*uv.y)*.75)+.42*cos(TAU*(uv.x-uv.y)*2.0);
 float edge=kind==1?1.15:.79;
 float exposed=smoothstep(edge,edge+.065,drift);
 vec3 ice=plate(uv+vec2(.13,.21),vec2(3,4),false);
 ice=mix(ice,CYAN,.4);
 c=mix(c,ice,exposed);
 c=mix(c,SNOW,line(drift-edge,.04)*.35);
 return c;
}
vec3 buried_ice(vec2 uv,bool upper){
 vec3 ice=plate(uv,vec2(4,4),false);
 float s=sin(TAU*uv.y+sin(TAU*uv.x)*.8)+.35*cos(TAU*(uv.x+uv.y)*2.0);
 float snow=smoothstep(upper?-.15:.55,upper?.07:.77,s);
 return mix(mix(ice,FROST,.32),SNOW-(1.0-broad(uv))*.05,snow);
}
vec3 snow_lip(vec2 uv,bool segmented){
 float lip=.68+.07*cos(TAU*uv.x*6.0)+.025*cos(TAU*uv.x*12.0);
 vec3 c=segmented?cut_ice(uv,vec2(6,1)):plate(uv,vec2(6,1),false);
 float cap=1.0-smoothstep(lip-.015,lip+.02,uv.y);
 vec3 snow=mix(FROST,SNOW,smoothstep(.0,.3,min(uv.y,lip-uv.y)));
 snow+=.012*cos(TAU*uv.x*3.0);
 return mix(c,snow,cap);
}
vec3 diamond_trim(vec2 uv){
 vec2 p=vec2(uv.x*8.0,uv.y*2.0);p.x+=mod(floor(p.y),2.0)*.5;
 vec2 q=fract(p);float seed=hash(floor(p));
 float d=abs(q.x-.5)+abs(q.y-.5);
 vec3 gem=mix(BLUE,VIOLET,seed*.6);
 gem=mix(gem,CYAN,step(q.x,.5)*.50);
 gem=mix(gem,FROST,step(q.y,.5)*.55);
 gem+=vec3(.03)*(.5-d);
 vec3 c=mix(vec3(.20,.30,.53),gem,1.0-smoothstep(.47,.49,d));
 c=mix(c,vec3(.85,.72,.46),step(.86,seed)*line(d-.30,.08)*.6);
 c=mix(c,SNOW,line(uv.y-.06,.035)+line(uv.y-.94,.035));
 return c;
}
vec3 glacier_wall(vec2 uv,bool cluster){
 vec3 c=cluster?crystal_field(uv,vec2(5,3)):plate(uv,vec2(5,2),false);
 if(!cluster){
  vec4 col=cells(vec2(uv.x*6.0,uv.y*.6),vec2(6,1));
  c=mix(c,mix(BLUE,FROST,col.w*.78),.92);
  c+=vec3(.06)*col.x;
  c=mix(c,CYAN,step(col.y,col.x*.6-.15)*.2);
  c=mix(c,CYAN,line(col.z-.07,.018)*.35);
  float vein=line(uv.y-.36-.08*sin(uv.x*TAU),.009);
  c=mix(c,FROST,vein*.22);
 }
 float lip=.10+.025*cos(uv.x*TAU*6.0)+.018*cos(uv.x*TAU*11.0);
 c=mix(c,FROST,1.0-smoothstep(lip+.02,lip+.05,uv.y));
 return mix(c,SNOW,1.0-smoothstep(lip-.008,lip+.008,uv.y));
}
vec3 ramp(vec2 uv,bool snow){
 vec3 c=snow?snow_surface(uv,0):cut_ice(uv,vec2(3,5));
 if(snow){
  float lane=abs(uv.x-.5+.025*sin(uv.y*TAU));
  c=mix(c,mix(FROST,SNOW,.45),1.0-smoothstep(.24,.33,lane));
  c=mix(c,FROST,line(lane-.28,.012)*.4);
 }else{
  float side=smoothstep(.33,.44,abs(uv.x-.5));
  c=mix(c,SNOW,side);
 }
 return c;
}
vec3 guard(vec2 uv,bool blocks){
 vec3 c=blocks?cut_ice(uv,vec2(6,1)):crystal_field(uv,vec2(5,1));
 float lip=.27+.035*cos(uv.x*TAU*6.0);
 c=mix(c,SNOW,1.0-smoothstep(lip-.01,lip+.01,uv.y));
 if(blocks){
  vec2 q=vec2(fract(uv.x*3.0),uv.y);
  float collar=box(q,vec2(.5,.63),vec2(.065,.36));
  c=mix(c,vec3(.78,.36,.15),collar);
  c=mix(c,vec3(.97,.74,.35),collar*(line(q.y-.43,.025)+line(q.y-.81,.025)));
 }
 return c;
}
vec3 facade(vec2 uv,bool constructed){
 if(!constructed){
  vec3 c=glacier_wall(uv,true);vec2 q=vec2(fract(uv.x*4.0),uv.y);
  float curtain=box(q,vec2(.5,.64),vec2(.13,.33));
  c=mix(c,mix(DEEP,VIOLET,.3),curtain);
  float prism=abs(q.x-.5)*4.0+abs(q.y-.45)*.35;
  c=mix(c,mix(FROST,CYAN,step(q.x,.5)*.55),curtain*(1.0-smoothstep(.38,.43,prism)));
  return c;
 }
 vec3 c=cut_ice(uv,vec2(8,3));vec2 q=vec2(fract(uv.x*3.0),uv.y);
 float upright=step(.80,q.x);
 c=mix(c,FROST,upright*.8);
 c=mix(c,DEEP,line(q.x-.80,.012));
 float jewel=abs(q.x-.40)*1.7+abs(q.y-.48);
 c=mix(c,VIOLET,1.0-smoothstep(.22,.24,jewel));
 c=mix(c,vec3(.63,.77,.93),1.0-smoothstep(.12,.14,jewel));
 c=mix(c,SNOW,1.0-smoothstep(.10,.13,uv.y));
 return c;
}
vec3 crystal_skin(vec2 uv,bool bands){
 if(bands){
  vec3 c=plate(uv,vec2(5,2),false);
  float y=fract(uv.y*2.0+uv.x*.6+.05*sin(uv.x*TAU*2.0));
  c=mix(c,FROST,smoothstep(.55,.67,y)*(1.0-smoothstep(.79,.87,y))*.42);
  return c;
 }
 vec2 p=vec2(uv.x,uv.y*.48);
 vec3 c=crystal_field(p,vec2(5,2));
 return mix(c,CYAN,.12);
}
float needle(vec2 p,vec2 a,vec2 b,float width){
 vec2 v=b-a;float t=clamp(dot(p-a,v)/dot(v,v),0.0,1.0);
 return 1.0-smoothstep(width*(1.0-t)+.002,width*(1.0-t)+.007,length(p-a-v*t));
}
vec3 foliage(vec2 uv,bool ribs){
 vec3 c=vec3(.13,.27,.30);vec2 p=uv*vec2(4,4);vec2 cell=floor(p);
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  vec2 g=vec2(float(x),float(y));float seed=hash(mod(cell+g,vec2(4.0)));
  vec2 q=p-cell-g-vec2(.5+(seed-.5)*.4,.1);
  q.x+=q.y*(seed-.5)*.5;
  float cover=needle(q,vec2(0,.9),vec2(0,-.02),.02);
  float tips=0.0;
  for(int j=0;j<7;j++){
   float f=float(j)/7.0;float spread=.18+f*.22;
   for(int s=-1;s<=1;s+=2){
    vec2 a=vec2(0.0,.16+f*.77),b=vec2(float(s)*spread,.02+f*.61);
    cover=max(cover,needle(q,a,b,.025));
    tips=max(tips,needle(q,mix(a,b,.67),b,.016));
   }
  }
  vec3 green=mix(vec3(.18,.36,.38),vec3(.29,.49,.47),seed);
  green+=vec3(.025)*q.y;
  float snow=1.0-smoothstep(.22,.29,q.y+.16*sin(q.x*11.0+seed*5.0));
  green=mix(green,ribs?FROST:SNOW,ribs?tips*.55:snow*.86);
  c=mix(c,green,cover);
 }}return c;
}
vec3 lake(vec2 uv,bool floes){
 vec3 c=mix(DEEP,BLUE,.45)+(broad(uv)-.5)*.025;
 if(floes){
  vec4 v=cells(uv*vec2(4,3),vec2(4,3));
  float ice=smoothstep(.26,.37,v.z)*step(.55,v.w);
  vec3 snow=mix(FROST,SNOW,smoothstep(.27,.65,v.z));
  snow+=vec3(.02)*step(v.y,v.x*.5);
  return mix(c,snow,ice);
 }
 vec4 v=cells(uv*vec2(3,3),vec2(3,3));
 c=mix(c,mix(BLUE,CYAN,v.w*.4),.7);
 c=mix(c,FROST,(1.0-smoothstep(.01,.035,v.z))*.30);
 return c;
}
void fragment(){
 vec2 uv=UV;vec3 c=SNOW;
 if(item==1)c=option==0?snow_surface(uv,0):buried_ice(uv,false);
 else if(item==2)c=option==0?snow_lip(uv,false):diamond_trim(uv);
 else if(item==3)c=glacier_wall(uv,option==0);
 else if(item==5)c=option==0?snow_surface(uv,1):cut_ice(uv,vec2(4,4));
 else if(item==6)c=option==0?snow_lip(uv,true):diamond_trim(uv);
 else if(item==7)c=ramp(uv,option==0);
 else if(item==8)c=guard(uv,option==1);
 else if(item==9)c=facade(uv,option==1);
 else if(item==10)c=crystal_skin(uv,option==1);
 else if(item==11)c=foliage(uv,option==1);
 else if(item==12)c=lake(uv,option==1);
 COLOR=vec4(clamp(c,vec3(0.0),vec3(1.0)),1.0);
}
