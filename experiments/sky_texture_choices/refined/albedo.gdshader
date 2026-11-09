shader_type canvas_item;
render_mode unshaded;
uniform int item=1;
// Selected structural designs rebuilt for periodic, supersampled albedo output.
// Palette changes are pigment only. No cast lighting or response maps are baked.
const vec3 PALE=vec3(.83,.84,.75);
const vec3 IVORY=vec3(.78,.79,.69);
const vec3 CREAM=vec3(.86,.83,.61);
const vec3 JOINT=vec3(.46,.51,.41);
const vec3 GREEN=vec3(.40,.53,.23);
const vec3 BLUE=vec3(.22,.28,.38);
const vec3 TEAL=vec3(.26,.60,.59);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float pnoise(vec2 p,vec2 period){
 vec2 cell=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(mod(cell,period)),hash(mod(cell+vec2(1,0),period)),f.x),mix(hash(mod(cell+vec2(0,1),period)),hash(mod(cell+vec2(1,1),period)),f.x),f.y);
}
float band(float d,float width){float aa=max(fwidth(d)*.65,.0005);return 1.0-smoothstep(width-aa,width+aa,abs(d));}
float inside(float d){float aa=max(fwidth(d)*.65,.0005);return 1.0-smoothstep(-aa,aa,d);}
float box(vec2 p,vec2 center,vec2 halfsize){vec2 d=abs(p-center)-halfsize;return inside(max(d.x,d.y));}
float box_distance(vec2 p,vec2 center,vec2 halfsize){vec2 d=abs(p-center)-halfsize;return max(d.x,d.y);}
vec3 pigment(vec2 uv,vec3 base,float seed){
 float broad=pnoise(uv*8.0,vec2(8))-.5;
 float facet=smoothstep(.43,.60,pnoise(uv*16.0,vec2(16)))-.5;
 return base+vec3(broad*.022+facet*.007)+vec3(.016,.012,-.012)*(seed-.5);
}
vec3 cut_stone(vec2 uv,vec3 base,float seed,float d,bool azure){
 vec3 face=pigment(uv,base+(seed-.5)*.052,seed);
 vec3 joint=azure?BLUE*.78:JOINT;
 // Small, non-directional edge color transitions; no simulated cast shadow.
 face=mix(face,mix(face,joint,.16),1.0-smoothstep(.018,.070,d));
 float aa=max(fwidth(d)*.60,.001);
 face=mix(joint,face,smoothstep(.009-aa,.021+aa,d));
 if(azure)face=mix(face,TEAL,band(d-.016,.004)*.58);
 return face;
}
float keyed_id(vec2 cell){
 ivec2 q=ivec2(mod(cell,8.0));
 const float cells[64]=float[64](
 0.,0.,0.,1.,1.,1.,2.,2.,
 0.,0.,0.,1.,1.,1.,2.,2.,
 3.,3.,0.,1.,4.,4.,2.,2.,
 3.,3.,3.,4.,4.,4.,5.,5.,
 6.,6.,3.,4.,4.,4.,5.,5.,
 6.,6.,7.,7.,7.,5.,5.,5.,
 6.,6.,7.,7.,8.,8.,8.,8.,
 9.,9.,9.,7.,8.,8.,8.,8.);
 return cells[q.y*8+q.x];
}
float azure_id(vec2 cell){
 vec2 q=mod(cell,4.0);
 if(q.y<1.0)return q.x<2.0?0.0:1.0;
 if(q.y<2.0)return q.x<1.0?0.0:(q.x<3.0?2.0:1.0);
 if(q.y<3.0)return q.x<1.0?3.0:(q.x<2.0?2.0:4.0);
 return q.x<3.0?3.0:4.0;
}
float structural_id(vec2 cell,bool azure){
 float size=azure?4.0:8.0;
 return (azure?azure_id(cell):keyed_id(cell))+floor(cell.x/size)*13.0+floor(cell.y/size)*173.0;
}
float fitted_distance(vec2 p,bool azure){
 vec2 cell=floor(p),q=fract(p);float id=structural_id(cell,azure),d=2.0;
 if(structural_id(cell+vec2(-1,0),azure)!=id)d=min(d,q.x);
 if(structural_id(cell+vec2(1,0),azure)!=id)d=min(d,1.0-q.x);
 if(structural_id(cell+vec2(0,-1),azure)!=id)d=min(d,q.y);
 if(structural_id(cell+vec2(0,1),azure)!=id)d=min(d,1.0-q.y);
 for(int x=-1;x<=1;x+=2){for(int y=-1;y<=1;y+=2){
  if(structural_id(cell+vec2(float(x),float(y)),azure)!=id)d=min(d,length(q-vec2(x<0?0.0:1.0,y<0?0.0:1.0)));
 }}
 return d;
}
vec3 fitted(vec2 uv,vec2 cells,vec3 base,bool azure){
 vec2 p=uv*cells,cell=floor(p);float d=fitted_distance(p,azure);
 float id=azure?azure_id(cell):keyed_id(cell);
 float seed=hash(vec2(id,azure?1.0:0.0)+floor(mod(cell,cells)/4.0)*.37);
 if(!azure)seed=hash(vec2(id,id*.31));
 vec3 c=cut_stone(uv,base,seed,d,azure);
 if(!azure){
  float green=(1.0-smoothstep(.024,.075,d))*smoothstep(.68,.80,pnoise(uv*16.0+vec2(3,7),vec2(16)));
  c=mix(c,vec3(.46,.58,.27),green*.40);
 }
 return c;
}
vec3 courses(vec2 uv,vec2 counts,vec3 base){
 vec2 p=uv*counts;p.x+=mod(floor(p.y),2.0)*.5;
 vec2 q=fract(p),edge=min(q,1.0-q);
 float seed=hash(mod(floor(p),counts));
 return cut_stone(uv,base,seed,min(edge.x,edge.y),false);
}
vec3 molding(vec2 uv,vec3 base){
 float e=min(uv.y,1.0-uv.y);vec3 c=pigment(uv,base,.3);
 c=mix(JOINT,c,smoothstep(.008,.045,e));
 c=mix(c,base+.035,band(e-.10,.025));
 return mix(c,base*.90,band(e-.20,.013));
}
vec3 crown(vec2 uv){
 vec3 c=courses(uv,vec2(8,1),IVORY);
 c=mix(c,courses(uv,vec2(8,1),GREEN),box(uv,vec2(.5),vec2(.6,.25)));
 return mix(c,CREAM,clamp(band(uv.y-.22,.024)+band(uv.y-.78,.024),0.0,1.0));
}
vec3 blue_panel_run(vec2 uv){
 vec3 c=fitted(uv,vec2(8),PALE,false);float across=abs(uv.x-.52);
 c=mix(c,vec3(.36,.45,.29),inside(across-.135));
 c=mix(c,PALE-.025,band(across-.143,.005));
 vec2 p=vec2((uv.x-.407)/.226,uv.y*4.0),q=fract(p);
 float row=mod(floor(p.y),4.0),seed=hash(vec2(3,row));
 vec3 blue=pigment(uv,mix(vec3(.22,.41,.50),vec3(.34,.56,.63),seed),seed);
 float key=.48+.13*step(.27,q.y)-.13*step(.66,q.y);
 float joint=band(q.x-key,.007);
 joint=max(joint,band(q.y-.27,.006)*box(q,vec2(.545,.27),vec2(.065,.03)));
 joint=max(joint,band(q.y-.66,.006)*box(q,vec2(.545,.66),vec2(.065,.03)));
 blue=mix(blue,vec3(.38,.68,.70),joint*.60);
 float end=min(q.y,1.0-q.y);
 blue=mix(blue,vec3(.32,.44,.32),1.0-smoothstep(.012,.022,end));
 blue=mix(blue,vec3(.48,.65,.61),band(end-.032,.004));
 return mix(c,blue,inside(across-.114));
}
vec3 grass_layer(vec2 uv,vec3 base,float density,float strength){
 vec2 p=uv*density,cell=floor(p);vec3 c=base;
 for(int y=-2;y<=2;y++){for(int x=-2;x<=2;x++){
  vec2 tile=cell+vec2(float(x),float(y)),key=mod(tile,density);
  vec2 center=tile+vec2(.25)+vec2(hash(key),hash(key+6.7))*.5;
  for(int blade=0;blade<9;blade++){
   float seed=hash(key+float(blade)*vec2(4.2,7.9));float a=seed*6.283185;
   vec2 direction=vec2(cos(a),sin(a)),across=vec2(-direction.y,direction.x);
   vec2 origin=center+across*(hash(key+float(blade)*8.3)-.5)*.80;
   vec2 v=p-origin;float length_blade=.78+hash(key+float(blade)*5.1+2.0)*.58;
   float t=dot(v,direction)/length_blade;
   float side=dot(v,across)-t*t*(seed-.5)*.25;
   float width=(.058+seed*.055)*(1.0-t);
   float mask=inside(abs(side)-width)*smoothstep(-.02,.035,t)*(1.0-smoothstep(.94,1.0,t));
   vec3 leaf=mix(vec3(.28,.43,.11),vec3(.43,.58,.19),seed);
   leaf+=vec3(.012,.017,.004)*smoothstep(-.012,.012,side);
   c=mix(c,leaf,mask*strength);
  }
 }}
 return c;
}
bool lawn_cell(vec2 cell){float id=keyed_id(cell);return id==3.0||id==6.0||id==8.0;}
float lawn_mask(vec2 uv){
 vec2 p=uv*8.0,cell=floor(p),q=fract(p);bool lawn=lawn_cell(cell);float d=2.0;
 if(lawn_cell(cell+vec2(-1,0))!=lawn)d=min(d,q.x);
 if(lawn_cell(cell+vec2(1,0))!=lawn)d=min(d,1.0-q.x);
 if(lawn_cell(cell+vec2(0,-1))!=lawn)d=min(d,q.y);
 if(lawn_cell(cell+vec2(0,1))!=lawn)d=min(d,1.0-q.y);
 return inside(lawn?-d:d);
}
vec3 garden(vec2 uv){
 vec3 stone=fitted(uv,vec2(8),PALE,false);
 vec3 turf=vec3(.31,.45,.13)+vec3(.012,.017,.004)*(pnoise(uv*8.0,vec2(8))-.5);
 turf=grass_layer(uv,turf,12.0,1.0);
 turf=grass_layer(uv,turf,22.0,.38);
 return mix(stone,turf,lawn_mask(uv));
}
vec3 column_wall(vec2 uv){
 vec3 c=courses(uv,vec2(12,8),CREAM);
 vec2 q=vec2(fract(uv.x*3.0),uv.y);
 vec3 column=courses(vec2(q.x,uv.y),vec2(5,6),GREEN);
 column=mix(column,CREAM,clamp(band(q.x-.36,.017)+band(q.x-.64,.017),0.0,1.0));
 column=mix(column,IVORY,band(q.x-.5,.032)*.55);
 c=mix(c,column,box(q,vec2(.5),vec2(.18,.43)));
 for(int end=0;end<2;end++){
  float y=end==0?.16:.84;float d=box_distance(q,vec2(.5,y),vec2(.24,.040));
  c=mix(c,IVORY*.91,inside(d+.001));
  c=mix(c,pigment(uv,IVORY,.4),inside(d+.008));
  float collar=end==0?.23:.77;
  c=mix(c,GREEN*.66,box(q,vec2(.5,collar),vec2(.18,.021)));
 }
 if(uv.y<.08)c=molding(vec2(uv.x,uv.y/.08),CREAM);
 if(uv.y>.92)c=molding(vec2(uv.x,(uv.y-.92)/.08),CREAM);
 return c;
}
vec3 guard(vec2 uv){
 vec3 c=molding(uv,IVORY);
 c=mix(c,fitted(uv,vec2(8,4),BLUE,true),box(uv,vec2(.5),vec2(.6,.19)));
 return mix(c,IVORY+.035,clamp(band(uv.y-.29,.016)+band(uv.y-.71,.016),0.0,1.0));
}
vec3 facade(vec2 uv){
 vec3 c=courses(uv,vec2(8,4),CREAM);vec2 q=vec2(fract(uv.x*4.0),uv.y);
 float d=box_distance(q,vec2(.5,.54),vec2(.37,.30));
 float seed=hash(vec2(mod(floor(uv.x*4.0),4.0),9));
 c=mix(c,JOINT,inside(d));
 c=mix(c,pigment(uv,IVORY+.025,seed),inside(d+.032));
 c=mix(c,pigment(uv,IVORY*.91,seed),inside(d+.075));
 c=mix(c,pigment(uv,GREEN*.86,seed),inside(d+.105));
 c=mix(c,pigment(uv,IVORY,seed),inside(d+.151));
 if(uv.y<.19)c=molding(vec2(uv.x,uv.y/.19),IVORY);
 if(uv.y<.055)c=pigment(uv,GREEN,.7);
 return c;
}
void fragment(){
 vec2 uv=UV;vec3 c=PALE;
 if(item==1)c=blue_panel_run(uv);
 else if(item==2||item==6)c=crown(uv);
 else if(item==3)c=column_wall(uv);
 else if(item==5)c=garden(uv);
 else if(item==7)c=fitted(uv,vec2(4,8),BLUE,true);
 else if(item==8)c=guard(uv);
 else if(item==9)c=facade(uv);
 COLOR=vec4(c,1.0);
}
