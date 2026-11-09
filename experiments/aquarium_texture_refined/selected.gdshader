shader_type canvas_item;
render_mode unshaded;
uniform int item=1;
const vec3 RED=vec3(.59,.145,.105);
const vec3 DARK_RED=vec3(.28,.065,.050);
const vec3 GOLD=vec3(.77,.585,.275);
const vec3 WOOD=vec3(.365,.185,.115);
const vec3 IVORY=vec3(.865,.835,.715);
const vec3 SLATE=vec3(.22,.34,.38);
float stroke(float d,float w){float aa=max(fwidth(d)*.8,.0006);return 1.-smoothstep(w-aa,w+aa,abs(d));}
float rect(vec2 p,vec2 c,vec2 h){vec2 d=abs(p-c)-h;float v=max(d.x,d.y);float aa=max(fwidth(v),.0006);return 1.-smoothstep(-aa,aa,v);}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float segment(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.,1.));}
float spiral_distance(vec2 p){
 float d=2.;vec2 a=vec2(.35,0.);
 for(int i=1;i<=64;i++){float t=float(i)/64.;float angle=t*9.35;vec2 b=vec2(cos(angle),sin(angle))*(.35-.295*t);d=min(d,segment(p,a,b));a=b;}
 return d;
}
vec3 lacquer(vec2 p){return RED+vec3(.009,.006,.004)*sin(p.x*TAU*2.)*cos(p.y*TAU);}
vec3 brass(vec2 p){return GOLD+vec3(.012,.010,.006)*sin(p.x*TAU)*cos(p.y*TAU);}
float border(vec2 p,float w){vec2 d=min(p,1.-p);return 1.-smoothstep(w-.001,w+.001,min(d.x,d.y));}
vec3 panel_floor(vec2 uv){
 vec2 p=vec2(uv.x,fract(uv.y*2.));
 vec3 c=vec3(.10,.375,.52);
 c+=vec3(.008,.016,.018)*sin(p.x*TAU*3.+sin(p.y*TAU))*sin(p.y*TAU*2.);
 float shoulder=pow(abs(p.x*2.-1.),5.);c=mix(c,vec3(.30,.67,.70),shoulder*.58);
 float center=.5+.205*sin(p.y*TAU);
 float ribbon=1.-smoothstep(.145,.19,abs(p.x-center));
 c=mix(c,vec3(.27,.58,.65),ribbon*.32);
 vec2 grid=p*vec2(24,18);grid.x+=mod(floor(grid.y),2.)*.5;
 vec2 cell=fract(grid)-.5;float scale=1.-smoothstep(.25,.36,abs(cell.x)+abs(cell.y)*1.3);
 c=mix(c,vec3(.105,.32,.44),ribbon*scale*.36);
 float frame=max(1.-smoothstep(.028,.032,min(p.x,1.-p.x)),1.-smoothstep(.014,.019,min(p.y,1.-p.y)));
 c=mix(c,lacquer(p),frame);
 float edging=max(stroke(min(p.x,1.-p.x)-.033,.002),stroke(min(p.y,1.-p.y)-.020,.002));
 c=mix(c,DARK_RED,edging*.65);return c;
}
vec3 scroll_strip(vec2 uv){
 vec3 c=lacquer(uv);float inset=rect(uv,vec2(.5),vec2(2.,.29));
 c=mix(c,vec3(.265,.14,.085),inset);
 vec2 p=vec2(fract(uv.x*6.)-.5,(uv.y-.5)*1.5);
 float d=spiral_distance(p);c=mix(c,vec3(.42,.28,.12),stroke(d,.026)*inset);
 c=mix(c,brass(p),stroke(d,.019)*inset);
 c=mix(c,GOLD,max(stroke(uv.y-.18,.016),stroke(uv.y-.82,.016)));
 return c;
}
vec3 wood_panel(vec2 p){
 float board=floor(p.x*3.);float h=hash(vec2(board,1));
 float x=fract(p.x*3.);float bend=.8*sin(p.y*TAU+h*TAU);
 vec3 c=WOOD+(h-.5)*vec3(.065,.045,.025);
 c+=vec3(.015,.009,.004)*sin(x*TAU*2.+bend);
 float grain=pow(.5+.5*sin(x*TAU*6.+bend),12.);
 c=mix(c,c*vec3(.93,.94,.96),grain*.6);
 c=mix(c,vec3(.245,.12,.075),stroke(min(x,1.-x),.013));return c;
}
vec3 wall(vec2 uv){
 vec2 p=vec2(fract(uv.x*2.),uv.y);vec3 c=wood_panel(p);
 c=mix(c,vec3(.23,.115,.065),border(p,.066));
 c=mix(c,lacquer(p),border(p,.043));
 c=mix(c,GOLD,max(stroke(p.y-.052,.006),stroke(p.y-.948,.006)));
 vec2 corner=min(p,1.-p);
 float bracket=max(rect(corner,vec2(.103,.16),vec2(.010,.075)),rect(corner,vec2(.16,.103),vec2(.075,.010)));
 float curl=stroke(spiral_distance((corner-vec2(.185,.185))*3.6),.018);
 c=mix(c,brass(p),max(bracket,curl));return c;
}
vec3 roof(vec2 uv){
 vec2 p=uv*vec2(6,4),f=fract(p),id=mod(floor(p),vec2(6,4));float h=hash(id);
 float rib=1.-smoothstep(.17,.235,abs(f.x-.5));
 vec3 c=RED+(h-.5)*vec3(.050,.027,.021);
 c+=vec3(.012,.007,.005)*sin(f.y*TAU)*sin(f.x*TAU);
 c=mix(c,RED+vec3(.035,.023,.017)+(h-.5)*.035,rib);
 float rib_seam=stroke(abs(f.x-.5)-.238,.010);
 c=mix(c,RED*.68,rib_seam);
 float end=.83+.056*cos((f.x-.5)*TAU);
 c=mix(c,RED*.81,stroke(f.y-end+.026,.014));
 c=mix(c,DARK_RED,stroke(f.y-end,.009));
 c=mix(c,DARK_RED,stroke(min(f.y,1.-f.y),.006));
 c=mix(c,DARK_RED,stroke(min(f.x,1.-f.x),.006));return c;
}
vec3 fascia(vec2 uv){
 vec3 c=lacquer(uv)*.70;c=mix(c,GOLD,stroke(uv.y-.87,.012));
 vec2 p=vec2(fract(uv.x*6.)-.5,(uv.y-.40)*1.5);float r=length(p);
 c=mix(c,SLATE,rect(vec2(fract(uv.x*6.),uv.y),vec2(.5,.085),vec2(.275,.085)));
 vec3 disk=SLATE+vec3(.012)*cos(r*5.);
 disk=mix(disk,SLATE*.67,stroke(r-.255,.011));
 disk=mix(disk,SLATE+vec3(.075,.08,.075),stroke(spiral_distance(p*1.55),.016));
 c=mix(c,disk,1.-smoothstep(.295,.305,r));return c;
}
vec3 ramp(vec2 uv){
 vec2 p=uv*vec2(3,4);p.x+=mod(floor(p.y),2.)*.5;
 vec2 f=fract(p),id=mod(floor(p),vec2(3,4));float h=hash(id);
 vec3 face=vec3(.70,.735,.695)+(h-.5)*vec3(.075,.067,.053);
 face+=vec3(.006,.007,.006)*sin(f.x*TAU)*sin(f.y*TAU);
 vec2 d=min(f,1.-f);float near=min(d.x,d.y);
 vec3 c=mix(vec3(.41,.48,.45),face,smoothstep(.009,.020,near));
 c=mix(c,face*.92,stroke(near-.025,.006));
 float side=min(uv.x,1.-uv.x);c=mix(c,lacquer(uv),1.-smoothstep(.037,.041,side));
 c=mix(c,GOLD,stroke(side-.042,.003));return c;
}
vec3 guard(vec2 uv){
 vec3 c=lacquer(uv);c=mix(c,GOLD,max(stroke(uv.y-.15,.016),stroke(uv.y-.85,.016)));
 vec2 p=vec2(fract(uv.x*4.),uv.y);float strap=rect(p,vec2(.5),vec2(.065,.39));
 c=mix(c,brass(p),strap);
 float scroll=stroke(spiral_distance((p-.5)*vec2(7.0,1.5)),.016)*strap;
 c=mix(c,RED,scroll);
 c=mix(c,GOLD*.75,stroke(abs(p.x-.5)-.057,.003)*strap);return c;
}
vec3 facade(vec2 uv){
 vec2 p=vec2(fract(uv.x*2.),uv.y),grid=p*vec2(3,4),f=fract(grid),id=floor(grid);
 float h=hash(id);vec3 c=IVORY+(h-.5)*vec3(.035,.030,.022);
 c+=vec3(.003)*sin(f.x*TAU)*sin(f.y*TAU);
 vec2 d=min(f,1.-f);float seam=min(d.x,d.y);
 c=mix(vec3(.35,.205,.135),c,smoothstep(.023,.035,seam));
 c=mix(c,vec3(.25,.13,.085),1.-smoothstep(.012,.020,seam));
 c=mix(c,lacquer(p),border(p,.046));
 vec2 corner=min(p,1.-p);
 float fitting=max(rect(corner,vec2(.055,.075),vec2(.015,.040)),rect(corner,vec2(.075,.055),vec2(.040,.015)));
 c=mix(c,brass(p),fitting);return c;
}
void fragment(){
 vec3 c=vec3(0.);
 if(item==1)c=panel_floor(UV);
 else if(item==2)c=scroll_strip(UV);
 else if(item==3)c=wall(UV);
 else if(item==4)c=fascia(UV);
 else if(item==5)c=roof(UV);
 else if(item==6){c=roof(vec2(UV.x,UV.y*.25));c=mix(c,DARK_RED,step(.92,UV.y));c=mix(c,GOLD,stroke(UV.y-.945,.012));vec2 p=vec2(fract(UV.x*6.)-.5,(UV.y-.77)*1.5);c=mix(c,RED+vec3(.035),stroke(length(p)-.14,.008));}
 else if(item==7)c=ramp(UV);
 else if(item==8)c=guard(UV);
 else if(item==9)c=facade(UV);
 COLOR=vec4(c,1.);
}
