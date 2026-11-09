shader_type canvas_item;
render_mode unshaded;
uniform int item = 1;
uniform int option = 0;
const vec3 STEEL = vec3(.62,.66,.69);
const vec3 PALE = vec3(.76,.78,.76);
const vec3 DARK = vec3(.14,.18,.23);
const vec3 SEAM = vec3(.25,.30,.34);
const vec3 YELLOW = vec3(.95,.73,.13);
const vec3 BLUE = vec3(.10,.27,.64);
const vec3 CYAN = vec3(.26,.79,.83);
const vec3 RED = vec3(.82,.19,.16);
float box(vec2 p,vec2 c,vec2 h) {
 vec2 d=abs(p-c)-h;
 return 1.0-smoothstep(-.002,.002,max(d.x,d.y));
}
float line(float x,float w) {return 1.0-smoothstep(w,w+.003,abs(x));}
float disc(vec2 p,vec2 c,float r) {return 1.0-smoothstep(r,r+.003,length(p-c));}
float joint(vec2 p,float w) {vec2 e=min(fract(p),1.0-fract(p));return 1.0-smoothstep(w,w+.005,min(e.x,e.y));}
vec3 plate(vec2 p,vec3 color) {
 vec2 q=fract(p);
 color=mix(color,SEAM,joint(p,.014));
 vec2 b=abs(q-.5);
 float bolts=disc(b,vec2(.425),.018);
 return mix(color,vec3(.39,.43,.46),bolts);
}
float chamfer(vec2 q,vec2 halfsize,float cut) {
 vec2 d=abs(q-.5);
 return 1.0-smoothstep(-.002,.002,max(max(d.x-halfsize.x,d.y-halfsize.y),d.x+d.y-halfsize.x-halfsize.y+cut));
}
vec3 housing(vec2 p,vec3 color,bool vents) {
 vec2 q=fract(p);
 vec3 c=SEAM;
 c=mix(c,color*.87,chamfer(q,vec2(.478),.075));
 c=mix(c,color,chamfer(q,vec2(.455),.075));
 float vent=box(q,vec2(.5,.72),vec2(.27,.105))*step(.43,fract(q.y*24.0));
 if(vents) c=mix(c,DARK,vent);
 c=mix(c,RED,box(q,vec2(.83,.16),vec2(.045,.016)));
 return c;
}
vec3 warning(vec2 uv,bool diagonal) {
 float stripe=step(.5,fract(uv.x*8.0+(diagonal ? uv.y*.65 : 0.0)));
 return mix(DARK,YELLOW,stripe);
}
vec3 trim(vec2 uv,int kind) {
 vec2 q=vec2(fract(uv.x*4.0),uv.y);
 vec3 c=STEEL;
 if(kind==0) {
  c=mix(c,warning(uv,true),box(uv,vec2(.5),vec2(1,.24)));
  c=mix(c,PALE,line(uv.y-.10,.035)+line(uv.y-.90,.035));
 } else if(kind==1) {
  c=YELLOW;
  c=mix(c,DARK,box(uv,vec2(.5),vec2(1,.20)));
  c=mix(c,CYAN,box(q,vec2(.5),vec2(.28,.065)));
 } else if(kind==2) {
  c=mix(c,DARK,line(uv.y-.55,.11));
  c=mix(c,vec3(.42,.48,.52),box(q,vec2(.5,.55),vec2(.31,.06)));
  c=mix(c,YELLOW,line(uv.y-.14,.045));
 } else {
  c=BLUE;
  c=mix(c,STEEL,line(q.x-.5,.035));
  c=mix(c,PALE,line(uv.y-.12,.055)+line(uv.y-.88,.055));
  c=mix(c,YELLOW,box(q,vec2(.78,.5),vec2(.08,.13)));
 }
 return c;
}
void fragment() {
 vec2 uv=UV;
 bool b=option==1;
 vec3 c=STEEL;
 if(item==1) {
  if(!b) c=plate(uv*vec2(3,3),PALE);
  else {
   vec2 q=fract(uv*vec2(2,3));
   c=housing(uv*vec2(2,3),STEEL,false);
   float ribs=box(q,vec2(.5),vec2(.30,.22))*step(.82,fract(q.y*10.0));
   c=mix(c,vec3(.43,.48,.52),ribs);
   c=mix(c,YELLOW,box(q,vec2(.5,.16),vec2(.18,.018)));
  }
 } else if(item==2) c=trim(uv,b?1:0);
 else if(item==3) {
  vec2 p=uv*vec2(3,2);
  vec2 q=fract(p);
  c=housing(p,b?vec3(.64,.67,.65):PALE,b);
  if(!b) {
   float path=line(q.y-(.43+clamp(q.x-.4,0.0,.2)),.009);
   c=mix(c,SEAM,path);
   c=mix(c,RED,box(q,vec2(.19,.77),vec2(.055,.016)));
  } else {
   c=mix(c,YELLOW,box(q,vec2(.16,.45),vec2(.035,.20)));
   c=mix(c,DARK,box(q,vec2(.68,.35),vec2(.13,.09)));
   c=mix(c,CYAN,box(q,vec2(.68,.35),vec2(.095,.045)));
  }
 } else if(item==4) c=trim(uv,b?3:2);
 else if(item==5) {
  vec2 p=uv*vec2(3,3);vec2 q=fract(p);
  if(!b) {
   c=housing(p,YELLOW,false);
   c=mix(c,DARK,box(q,vec2(.5),vec2(.26,.30)));
   c=mix(c,vec3(.32,.34,.32),box(q,vec2(.5),vec2(.22,.26)));
   c=mix(c,DARK,box(q,vec2(.5),vec2(.22,.26))*line(fract(q.y*9.0)-.5,.08));
  } else {
   c=plate(p,vec3(.32,.43,.54));
   c=mix(c,STEEL,box(q,vec2(.5),vec2(.33,.30)));
   c=mix(c,YELLOW,box(q,vec2(.5,.13),vec2(.28,.022)));
  }
 } else if(item==6) c=trim(uv,b?2:0);
 else if(item==7) {
  if(!b) {
   c=plate(uv*vec2(2,5),STEEL);
   c=mix(c,YELLOW,step(.43,abs(uv.x-.5)));
   c=mix(c,DARK,line(abs(uv.x-.5)-.40,.009));
  } else {
   c=plate(uv*vec2(1,7),vec3(.23,.29,.34));
   vec2 q=fract(uv*vec2(4,7));
   c=mix(c,STEEL,box(q,vec2(.5),vec2(.29,.055)));
   c=mix(c,YELLOW,step(.42,abs(uv.x-.5)));
  }
 } else if(item==8) {
  c=b?trim(uv,3):plate(vec2(uv.x*4.0,uv.y),YELLOW);
  if(!b)c=mix(c,PALE,box(uv,vec2(.5),vec2(1,.09)));
 } else if(item==9) {
  vec2 p=uv*vec2(3,2),q=fract(p);
  if(!b){
   c=housing(p,PALE,true);
   c=mix(c,DARK,box(q,vec2(.5,.32),vec2(.16,.105)));
   c=mix(c,CYAN,box(q,vec2(.5,.32),vec2(.125,.07)));
  }else{
   c=plate(p,vec3(.38,.43,.48));
   c=mix(c,BLUE,box(q,vec2(.3,.5),vec2(.065,.5)));
   c=mix(c,STEEL,box(q,vec2(.3,.2),vec2(.095,.025))+box(q,vec2(.3,.8),vec2(.095,.025)));
   c=mix(c,YELLOW,box(q,vec2(.73,.5),vec2(.19,.26)));
   c=mix(c,DARK,box(q,vec2(.73,.5),vec2(.12,.10)));
   c=mix(c,RED,disc(q,vec2(.73,.28),.024));
  }
 } else if(item==10) {
  c=b?vec3(.70,.72,.72):BLUE;
  c=mix(c,b?YELLOW:STEEL,line(fract(uv.x*3.0)-.5,.07));
  c=mix(c,DARK,line(fract(uv.x*3.0)-.39,.012)+line(fract(uv.x*3.0)-.61,.012));
  if(b)c=mix(c,RED,box(vec2(fract(uv.x*3.0),uv.y),vec2(.18,.5),vec2(.04,.12)));
 } else if(item==11) {
  vec2 q=uv*vec2(5,4);
  float ripple=sin(q.x*6.283+sin(q.y*6.283)*.65);
  c=mix(b?vec3(.08,.27,.49):vec3(.24,.08,.35),b?vec3(.19,.53,.69):vec3(.49,.20,.59),smoothstep(.55,.85,ripple)*.55);
  if(option==2){float r=sin(uv.x*3.2+uv.y*1.7)*.5+.5;c=mix(vec3(.055,.025,.15),vec3(.16,.035,.24),r*.35);}
 }
 COLOR=vec4(c,1.0);
}
