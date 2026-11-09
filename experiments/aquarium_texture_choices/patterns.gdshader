shader_type canvas_item;
render_mode unshaded;
uniform int item = 1;
uniform int option = 0;
const vec3 STONE=vec3(.70,.74,.70);
const vec3 JOINT=vec3(.34,.43,.44);
const vec3 RED=vec3(.65,.12,.10);
const vec3 GOLD=vec3(.80,.61,.25);
const vec3 IVORY=vec3(.88,.86,.72);
const vec3 BLUE=vec3(.10,.38,.53);
const vec3 CYAN=vec3(.36,.76,.77);
const vec3 NAVY=vec3(.08,.20,.26);
float line(float x,float w){return 1.0-smoothstep(w,w+.003,abs(x));}
float edge(vec2 p,float w){vec2 d=min(fract(p),1.0-fract(p));return 1.0-smoothstep(w,w+.004,min(d.x,d.y));}
float box(vec2 p,vec2 center,vec2 halfsize){vec2 d=abs(p-center)-halfsize;return 1.0-smoothstep(0.0,.003,max(d.x,d.y));}
vec2 hash(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
vec3 stones(vec2 uv){
 vec2 p=uv*4.0; vec2 cell=floor(p); vec2 f=fract(p); float a=20.0; float b=20.0; vec2 chosen=vec2(0);
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  vec2 o=vec2(float(x),float(y)); vec2 h=hash(mod(cell+o,4.0)); vec2 d=o+.24+h*.52-f; float dist=dot(d,d);
  if(dist<a){b=a;a=dist;chosen=h;}else if(dist<b){b=dist;}
 }}
 return mix(JOINT,STONE+(chosen.x-.5)*.08,smoothstep(.025,.055,b-a));
}
vec3 slabs(vec2 uv){vec2 p=uv*vec2(3,4);p.x+=mod(floor(p.y),2.0)*.5;return mix(STONE,JOINT,edge(p,.015));}
vec3 glass_deck(vec2 uv){
 float side=pow(abs(uv.x*2.0-1.0),8.0); vec3 c=mix(BLUE,CYAN,side*.8);
 c=mix(c,RED,step(.94,abs(uv.x*2.0-1.0)));
 c=mix(c,RED,line(fract(uv.y*2.0),.014));
 vec2 p=vec2(uv.x-.5,fract(uv.y*2.0)-.5);
 float badge=1.0-smoothstep(.065,.075,abs(p.x)+abs(p.y)*.8);
 return mix(c,CYAN,badge*.65);
}
vec3 wood(vec2 uv){vec2 p=uv*vec2(3,5);p.y+=mod(floor(p.x),2.0)*.5;vec3 c=vec3(.38,.16,.12)+(mod(floor(p.x),3.0)-1.0)*.025;return mix(c,vec3(.19,.10,.09),edge(p,.012));}
// Broad material structure only; no lighting, surface maps or photographic noise.
float segment(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.,1.));}
float scroll(vec2 p){
 float dist=2.;vec2 a=vec2(.36,0.);
 for(int i=1;i<=40;i++){float t=float(i)/40.;float angle=t*9.3;vec2 b=vec2(cos(angle),sin(angle))*(.36-.30*t);dist=min(dist,segment(p,a,b));a=b;}
 return 1.-smoothstep(.018,.029,dist);
}
vec3 timber(vec2 uv){
 vec2 p=uv*vec2(4,3);p.y+=mod(floor(p.x),2.)*.5;vec2 f=fract(p),h=hash(mod(floor(p),vec2(4,3)));
 float grain=sin(f.x*36.+sin(f.y*6.28+h.x*3.)*1.8);
 vec3 c=vec3(.38,.19,.13)+(h.x-.5)*.09+vec3(.025,.015,.007)*sin(f.x*12.+sin(f.y*6.28)*.7);
 c+=vec3(.025,.016,.007)*smoothstep(.75,.95,grain);
 return mix(c,vec3(.17,.09,.065),edge(p,.018));
}
vec3 redwood(vec2 p){return RED+vec3(.022,.012,.008)*sin(p.y*6.283)+vec3(.008)*sin(p.x*25.13+p.y*6.28);}
vec3 decorated_deck(vec2 uv,bool serpent){
 vec2 p=vec2(uv.x,fract(uv.y*2.));vec3 c=BLUE+vec3(.015,.035,.04)*sin(p.y*6.283)*sin(p.x*12.566);
 c=mix(c,CYAN,pow(abs(p.x*2.-1.),5.)*.66);
 c+=vec3(.018,.025,.023)*sin(p.x*18.85+sin(p.y*6.283)*1.8)*sin(p.y*12.566-p.x*6.283);
 if(serpent){float s=.5+.22*sin(p.y*6.283);float band=1.-smoothstep(.16,.20,abs(p.x-s));float dots=1.-smoothstep(.23,.30,length(fract(p*vec2(27,19))-.5));c=mix(c,CYAN,band*.18);c=mix(c,BLUE*.75,band*dots*.3);}
 else{vec2 d=(p-.5)*vec2(1.,.8);float angle=atan(d.y,d.x);float emblem=1.-smoothstep(.055+.018*cos(angle*4.),.063+.018*cos(angle*4.),length(d));c=mix(c,IVORY,emblem*.68);}
 float frame=max(step(.944,abs(p.x*2.-1.)),line(p.y,.015)+line(p.y-1.,.015));
 c=mix(c,redwood(p),frame);return c;
}
vec3 ornamental_trim(vec2 uv){
 vec3 c=redwood(uv);float band=box(uv,vec2(.5),vec2(2.,.30));c=mix(c,vec3(.25,.13,.08),band);
 c=mix(c,GOLD,scroll(vec2(fract(uv.x*6.)-.5,(uv.y-.5)*1.3))*band);
 return mix(c,GOLD,max(line(uv.y-.16,.022),line(uv.y-.84,.022)));
}
float waves(vec2 uv){vec2 p=fract(uv*vec2(4,2));float d=length((p-vec2(.5,1.0))*vec2(1.0,.8));return max(line(d-.30,.014),line(d-.43,.014));}
vec3 trim(vec2 uv){
 vec3 c=option==0?RED:STONE;
 if(option==0){
  c=mix(c,GOLD,max(line(uv.y-.13,.025),line(uv.y-.87,.025)));
  vec2 p=vec2(fract(uv.x*4.0)-.5,(uv.y-.5)*.5);
  c=mix(c,GOLD,1.0-smoothstep(.045,.055,abs(p.x)+abs(p.y)));
 }else{
  c=mix(c,vec3(.18,.45,.43),box(vec2(fract(uv.x*4.0),uv.y),vec2(.5),vec2(.43,.29)));
  c=mix(c,JOINT,line(fract(uv.x*4.0),.018));
 }
 return c;
}
void fragment(){
 vec2 uv=UV; vec3 c=STONE;
 if(item==1){
  if(option==0)c=stones(uv);
  else{vec2 p=fract(uv*3.0)-.5;c=mix(vec3(.48,.67,.66),JOINT,edge(uv*3.0,.016));float ring=line(length(p)-.27,.025);c=mix(c,IVORY,ring);c=mix(c,BLUE,1.0-smoothstep(.12,.14,abs(p.x)+abs(p.y)));}
 }else if(item==2||item==6){c=trim(uv);}
 else if(item==3){
  if(option==0){vec2 p=fract(uv*vec2(2,1));c=vec3(.62,.75,.72);float frame=edge(p,.045);c=mix(c,RED,frame);vec2 q=abs(p-.5);float inset=max(line(q.x-.37,.012)*step(q.y,.31),line(q.y-.31,.012)*step(q.x,.37));c=mix(c,IVORY,inset);}
  else{c=mix(NAVY,GOLD,waves(uv));c=mix(c,RED,max(line(uv.y-.06,.035),line(uv.y-.94,.035)));}
 }else if(item==5){c=option==0?glass_deck(uv):wood(uv);}
 else if(item==7){c=option==0?glass_deck(uv):slabs(uv);}
 else if(item==8){
  if(option==0)c=trim(uv);
  else{c=vec3(.25,.12,.10);float panels=line(fract(uv.x*4.0),.035);c=mix(c,GOLD,max(panels,max(line(uv.y-.16,.035),line(uv.y-.84,.035))));}
 }else if(item==9){
  vec2 p=fract(uv*vec2(2,1));
  if(option==0){c=IVORY;c=mix(c,vec3(.32,.17,.11),edge(p*vec2(3,4),.035));c=mix(c,RED,edge(p,.06));c=mix(c,GOLD,box(p,vec2(.07,.07),vec2(.045)) +box(p,vec2(.93,.93),vec2(.045)));}
  else{c=vec3(.82,.79,.63);vec2 d=(p-.5)*vec2(1.0,.8);float angle=atan(d.y,d.x);float flower=1.0-smoothstep(.17+.045*cos(angle*5.0),.18+.045*cos(angle*5.0),length(d));c=mix(c,RED,flower);c=mix(c,GOLD,1.0-smoothstep(.035,.045,length(d)));c=mix(c,vec3(.27,.46,.36),box(p,vec2(.25,.74),vec2(.09,.035)));c=mix(c,vec3(.27,.46,.36),box(p,vec2(.75,.26),vec2(.09,.035)));c=mix(c,GOLD,edge(p,.045));c=mix(c,NAVY,edge(p,.017));}
 }
 // Second and final Phase-1 generation pass: reference-led material studies.
 if(item==1&&option==0){c=stones(uv);c+=.012*sin(uv.x*25.13+uv.y*18.85)+.008*cos(uv.x*37.7-uv.y*12.56);}
 if((item==1||item==7)&&option==1){
  vec2 p=uv*vec2(3,4);p.x+=mod(floor(p.y),2.)*.5;vec2 h=hash(mod(floor(p),vec2(3,4)));
  c=STONE+(h.x-.5)*.10+.01*sin(uv.x*25.13+uv.y*18.85);c=mix(c,c*.87,edge(p,.045));c=mix(c,JOINT,edge(p,.014));
  if(item==1){float band=step(.84,uv.x);c=mix(c,vec3(.19,.41,.42),band);c=mix(c,IVORY,scroll(vec2((uv.x-.92)*7.,fract(uv.y*3.)-.5))*band*.65);}
  else{c=mix(c,redwood(uv),step(.92,abs(uv.x*2.-1.)));c=mix(c,GOLD,line(abs(uv.x-.5)-.46,.006));}
 }
 if(item==2||item==6){
  if(option==0)c=ornamental_trim(uv);
  else if(item==2){vec2 p=vec2(uv.x*4.,uv.y);vec2 h=hash(vec2(floor(p.x),0));c=STONE+(h.x-.5)*.10+.012*sin(uv.x*25.13)*sin(uv.y*6.28);c=mix(c,JOINT,line(fract(p.x),.014));c=mix(c,c*.83,max(line(uv.y-.10,.018),line(uv.y-.90,.018)));}
  else{c=mix(BLUE,CYAN,.13+.10*sin(uv.y*6.283));c=mix(c,IVORY,scroll(vec2(fract(uv.x*6.)-.5,(uv.y-.5)*1.2))*.6);c=mix(c,NAVY,max(line(uv.y-.1,.028),line(uv.y-.9,.028)));}
 }
 if(item==3){
  vec2 p=fract(uv*vec2(2,1));
  if(option==0){c+=.012*sin(p.x*12.56)*sin(p.y*6.28);vec2 seal=(p-.5)*vec2(1,1.8);c=mix(c,NAVY,line(length(seal)-.095,.012));c=mix(c,RED,box(seal,vec2(0),vec2(.025,.09)));}
  else{c=timber(vec2(p.x*.5,p.y));vec2 corner=min(p,1.-p);float bracket=max(box(corner,vec2(.10,.16),vec2(.012,.09)),box(corner,vec2(.16,.10),vec2(.09,.012)));c=mix(c,GOLD,bracket);c=mix(c,GOLD,scroll((corner-vec2(.17,.18))*3.)*box(corner,vec2(.18),vec2(.10)));}
  c=mix(c,redwood(p),edge(p,.045));c=mix(c,GOLD,max(line(p.y-.055,.008),line(p.y-.945,.008)));
 }
 if(item==5)c=option==0?decorated_deck(uv,true):timber(uv);
 if(item==7&&option==0)c=decorated_deck(uv,false);
 if(item==8){
  if(option==0){c=redwood(uv);c=mix(c,GOLD,max(line(uv.y-.15,.02),line(uv.y-.85,.02)));vec2 p=vec2(fract(uv.x*4.),uv.y);c=mix(c,GOLD,box(p,vec2(.5),vec2(.07,.40)));c=mix(c,RED,scroll((p-.5)*2.)*box(p,vec2(.5),vec2(.065,.36)));}
  else{c=timber(uv.yx)*.78;c=mix(c,vec3(.08,.07,.055),box(uv,vec2(.5),vec2(2.,.28)));c=mix(c,vec3(.52,.30,.15),scroll(vec2(fract(uv.x*4.)-.5,(uv.y-.5)*1.2)));c=mix(c,GOLD,max(line(uv.y-.1,.018),line(uv.y-.9,.018)));}
 }
 if(item==9){
  vec2 p=fract(uv*vec2(2,1));
  if(option==0){vec2 grid=p*vec2(3,4);vec2 h=hash(floor(grid));c=IVORY+(h.x-.5)*.065+.007*sin(p.x*37.7+p.y*12.56)*sin(p.y*25.13);c=mix(c,vec3(.35,.19,.12),edge(grid,.035));c=mix(c,vec3(.22,.115,.08),edge(grid,.015));}
  else{vec2 q=fract(p*vec2(1,2));c=IVORY+.012*sin(q.x*6.283)*cos(q.y*6.283);vec2 d=(q-.5)*vec2(1.1,1.);c=mix(c,vec3(.54,.48,.29),line(length(d)-.28,.009));
   for(int i=0;i<3;i++){float a=float(i)*2.094;vec2 at=vec2(cos(a),sin(a))*.22;vec2 flower=d-at;float fa=atan(flower.y,flower.x);float radius=.11+.025*cos(fa*5.);float petal=1.-smoothstep(radius,radius+.008,length(flower));c=mix(c,mix(RED,vec3(.64,.43,.20),float(i)*.18),petal);c=mix(c,GOLD,1.-smoothstep(.015,.025,length(flower)));vec2 leaf=d+at;c=mix(c,vec3(.25,.43,.32),1.-smoothstep(.12,.14,length(leaf*vec2(1.4,3.))));}
   c=mix(c,GOLD,edge(p*vec2(1,2),.05));c=mix(c,vec3(.30,.18,.09),edge(p*vec2(1,2),.02));
  }
  c=mix(c,redwood(p),edge(p,.05));c=mix(c,GOLD,box(min(p,1.-p),vec2(.055),vec2(.03)));
 }
 COLOR=vec4(c,1.0);
}
