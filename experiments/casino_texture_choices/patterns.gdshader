shader_type canvas_item;
render_mode unshaded;
uniform int item=1;
uniform int option=0;
const vec3 GOLD=vec3(.73,.51,.18);
const vec3 PALE_GOLD=vec3(.87,.68,.32);
const vec3 NAVY=vec3(.045,.065,.15);
const vec3 BLUE=vec3(.085,.22,.56);
const vec3 RED=vec3(.65,.07,.18);
const vec3 PINK=vec3(.91,.12,.40);
const vec3 AQUA=vec3(.08,.66,.86);
const vec3 IVORY=vec3(.82,.76,.56);
float box(vec2 p,vec2 c,vec2 h){vec2 d=abs(p-c)-h;return 1.0-smoothstep(-.002,.002,max(d.x,d.y));}
float line(float p,float w){return 1.0-smoothstep(w,w+.003,abs(p));}
float disk(vec2 p,float r){return 1.0-smoothstep(r,r+.003,length(p));}
float diamond(vec2 p,float r){return 1.0-smoothstep(r,r+.004,abs(p.x)+abs(p.y));}
float frame(vec2 p,vec2 c,vec2 h,float w){return max(0.0,box(p,c,h)-box(p,c,h-vec2(w)));}
float star(vec2 p,float size){float a=atan(p.y,p.x);float r=size*(.68+.23*cos(a*5.0));return 1.0-smoothstep(r,r+.004,length(p));}
float seam(vec2 p,float w){vec2 q=min(fract(p),1.0-fract(p));return 1.0-smoothstep(w,w+.004,min(q.x,q.y));}
vec3 floor_color(vec2 uv,bool b){
 vec2 p=uv*2.0,q=fract(p);float parity=mod(floor(p.x)+floor(p.y),2.0);
 vec3 c=mix(BLUE*.77,BLUE,.35+.2*parity);
 if(!b){
  c=mix(c,NAVY,seam(p,.006));
  float oct=max(max(abs(q.x-.5),abs(q.y-.5))-.43,abs(q.x-.5)+abs(q.y-.5)-.72);
  c=mix(c,GOLD*.7,line(oct,.006));
  c=mix(c,BLUE*1.23,star(q-.5,.13)*parity);
  c=mix(c,AQUA,box(q,vec2(.5,.09),vec2(.10,.007))*(1.0-parity));
 }else{
  c=NAVY*1.25;
  c=mix(c,BLUE*.75,diamond(q-.5,.46));
  c=mix(c,BLUE*1.1,diamond(q-.5,.33)*.25);
  c=mix(c,GOLD*.85,diamond(q-.5,.035));
  c=mix(c,PINK*.75,box(q,vec2(.5,.045),vec2(.08,.008)));
 }
 return c;
}
vec3 strip(vec2 uv,int role,bool b){
 vec2 q=vec2(fract(uv.x*4.0),uv.y);
 vec3 c=NAVY;
 if(role==2){
  c=mix(c,b?BLUE:RED,box(q,vec2(.5),vec2(.5,.31)));
  c=mix(c,PALE_GOLD,line(q.y-.1,.045)+line(q.y-.9,.045));
  if(!b)c=mix(c,IVORY,disk((q-vec2(.5,.5))*vec2(1.,.35),.045));
  else {c=mix(c,PINK,line(q.y-.30,.025));c=mix(c,AQUA,diamond((q-vec2(.5,.61))*vec2(1.,.4),.10));}
 }else if(role==4){
  if(!b){
   c=RED;
   float edge=.60+.15*sqrt(max(0.0,1.0-pow((q.x-.5)*2.0,2.0)));
   c=mix(c,GOLD,step(edge,q.y));c=mix(c,PALE_GOLD,line(q.y-edge,.03)+line(q.y-.12,.045));
  }else{
   c=GOLD;c=mix(c,NAVY,box(q,vec2(.5,.53),vec2(.43,.26)));
   c=mix(c,PINK,box(q,vec2(.5,.49),vec2(.34,.055)));
   c=mix(c,AQUA,line(q.y-.83,.025));
  }
 }else if(role==6){
  c=b?NAVY:RED;
  c=mix(c,PALE_GOLD,line(q.y-.1,.035)+line(q.y-.9,.035));
  if(!b)c=mix(c,GOLD,diamond((q-vec2(.5,.5))*vec2(1.,.5),.16));
  else {c=mix(c,GOLD,star((q-vec2(.5,.5))*vec2(1.,.45),.19));c=mix(c,AQUA,line(q.y-.25,.02));c=mix(c,PINK,line(q.y-.75,.02));}
 }else{
  c=b?BLUE:GOLD;c=mix(c,PALE_GOLD,line(q.y-.12,.035)+line(q.y-.88,.035));
  if(!b){c=mix(c,NAVY,box(q,vec2(.5),vec2(.32,.24)));c=mix(c,PINK,box(q,vec2(.5),vec2(.26,.12)));}
  else {c=mix(c,RED,box(q,vec2(.5),vec2(.40,.24)));c=mix(c,AQUA,diamond((q-vec2(.5))*vec2(1.,.5),.13));}
 }
 return c;
}
vec3 wall_color(vec2 uv,bool b,bool exterior){
 vec2 p=vec2(uv.x*3.0,uv.y*(exterior?2.0:1.0)),q=fract(p);
 vec3 c=b?NAVY:GOLD;
 if(!b){
  c=mix(c,NAVY,box(q,vec2(.5,.51),vec2(.31,.33)));
  c=mix(c,PALE_GOLD,frame(q,vec2(.5,.51),vec2(.34,.36),.026));
  c=mix(c,GOLD*.65,line(q.x-.08,.012)+line(q.x-.92,.012));
  c=mix(c,BLUE,box(q,vec2(.5,.50),vec2(.23,.25)));
  c=mix(c,AQUA,line(q.x-.5,.018)*box(q,vec2(.5,.50),vec2(.24,.24)));
  c=mix(c,PINK,box(q,vec2(.5,.06),vec2(.35,.016)));
 }else{
  c=mix(c,GOLD,frame(q,vec2(.5),vec2(.46,.46),.022));
  c=mix(c,BLUE,box(q,vec2(.5),vec2(.29,.34)));
  if(!exterior){
   c=mix(c,NAVY,diamond((q-.5)*vec2(1.,.65),.28));
   c=mix(c,AQUA,diamond((q-.5)*vec2(1.,.65),.075));
  }else{
   c=mix(c,NAVY,box(q,vec2(.5),vec2(.15,.34)));
   c=mix(c,AQUA,box(q,vec2(.31,.5),vec2(.023,.28)));
   c=mix(c,PINK,box(q,vec2(.69,.5),vec2(.023,.28)));
  }
  c=mix(c,PINK,box(q,vec2(.5,.08),vec2(.25,.017)));
 }
 return c;
}
vec3 upper(vec2 uv,bool b){
 vec2 p=uv*2.0,q=fract(p);vec3 c=b?IVORY:RED;
 if(!b){c=mix(c,RED*.65,seam(p,.012));c=mix(c,GOLD,frame(q,vec2(.5),vec2(.44),.009));c=mix(c,RED*1.13,diamond(q-.5,.10));}
 else{c=mix(c,PALE_GOLD*.68,seam(p,.008));c=mix(c,GOLD*.85,line(abs(q.x-.5)+abs(q.y-.5)-.40,.006));c=mix(c,BLUE*.65,diamond(q-.5,.035));}
 return c;
}
vec3 ramp(vec2 uv,bool b){
 vec3 c=b?BLUE:RED;vec2 q=vec2(uv.x,fract(uv.y*3.0));
 c=mix(c,GOLD,line(uv.x-.09,.028)+line(uv.x-.91,.028));
 c=mix(c,b?PINK:PALE_GOLD,line(uv.x-.15,.006)+line(uv.x-.85,.006));
 if(!b){c=mix(c,RED*.72,line(q.y,.01));c=mix(c,GOLD*.85,diamond((q-.5)*vec2(1.,.6),.06));}
 else{float arrow=line(q.y-.5-abs(q.x-.5)*.7,.014)*box(q,vec2(.5,.5),vec2(.22,.18));c=mix(c,AQUA,arrow);}
 return c;
}
void fragment(){
 bool b=option==1;vec2 uv=UV;vec3 c=NAVY;
 if(item==1)c=floor_color(uv,b);
 else if(item==2 || item==4 || item==6 || item==8)c=strip(uv,item,b);
 else if(item==3 || item==9)c=wall_color(uv,b,item==9);
 else if(item==5)c=upper(uv,b);
 else if(item==7)c=ramp(uv,b);
 else if(item==10){
  vec2 q=fract(uv*vec2(4.,2.));c=b?vec3(.27,.15,.43):GOLD;
  if(!b){c=mix(c,GOLD*.72,box(q,vec2(.5),vec2(.16,.39)));c=mix(c,PALE_GOLD,line(q.y-.06,.035));}
  else {c=mix(c,GOLD,line(q.y-.12,.055)+line(q.y-.88,.055));c=mix(c,RED,diamond((q-.5)*vec2(1.,.6),.18));}
 }else if(item==11){
  vec2 q=vec2(fract(uv.x*8.),uv.y);float k=mod(floor(uv.x*8.),4.);
  vec3 tint=k<.5?PINK:(k<1.5?AQUA:(k<2.5?vec3(.13,.72,.36):vec3(1.,.62,.14)));
  c=NAVY;
  if(!b){c=mix(c,GOLD,box(q,vec2(.5),vec2(.46,.39)));c=mix(c,tint,box(q,vec2(.5),vec2(.39,.28)));}
  else{c=mix(c,GOLD,disk((q-.5)*vec2(1.,.4),.22));c=mix(c,tint,disk((q-.5)*vec2(1.,.4),.17));}
 }
 COLOR=vec4(c,1.);
}

