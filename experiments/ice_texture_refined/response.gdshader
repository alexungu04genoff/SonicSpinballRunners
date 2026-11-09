shader_type canvas_item;
render_mode unshaded;
uniform int item = 1;
uniform bool response_map = false;
// User-requested softer trim, livelier ice, and reflective ice with matte snow.
// Response masks come from these shapes, never from albedo brightness.
const vec3 SNOW = vec3(.87,.935,.965);
const vec3 FROST = vec3(.66,.81,.90);
const vec3 BLUE = vec3(.26,.48,.72);
const vec3 CYAN = vec3(.34,.65,.81);
const vec3 VIOLET = vec3(.39,.43,.68);
const vec3 JOINT = vec3(.22,.32,.51);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float periodic_noise(vec2 p,vec2 period){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 float a=hash(mod(i,period)),b=hash(mod(i+vec2(1,0),period));
 float c=hash(mod(i+vec2(0,1),period)),d=hash(mod(i+vec2(1,1),period));
 return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
float pn(vec2 uv,float count,float seed){return periodic_noise(uv*count+seed,vec2(count));}
float stripe(float d,float width){return 1.0-smoothstep(width,width+.009,abs(d));}
float noise1(float p,float period,float seed){
 float i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(hash(vec2(mod(i,period),seed)),hash(vec2(mod(i+1.0,period),seed)),f);
}
// Connected drift shapes use several deliberately low-frequency periodic fields.
// No uniquely recognizable two-patch stamp or isolated regular oval is repeated.
vec3 snow_field(vec2 uv,bool upper,out float ice_mask){
 ice_mask=0.0;
 float broad=pn(uv,3.0,2.3);
 vec3 snow=mix(vec3(.80,.88,.925),SNOW,.45+broad*.55);
 float folds=pn(uv+vec2(pn(uv,3.0,7.0)*.07,0),7.0,4.1);
 snow+=vec3(.014)*(folds-.5);
 // More openings on the main floor, at approximately the existing feature size.
 // Elevated snow keeps its calmer established distribution.
 float count=upper?5.0:7.0;
 vec2 p=uv*vec2(count),cell=floor(p);
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  vec2 g=vec2(float(x),float(y)),key=mod(cell+g,vec2(count));
  float seed=hash(key+22.6),seed2=hash(key+7.3);
  if(seed>(upper?.43:.15)){
   vec2 center=vec2(.5)+(vec2(hash(key+1.1),hash(key+31.5))-.5)*.82;
   vec2 q=p-cell-g-center;
   float angle=seed2*TAU;q=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*q;
   float size=(.16+seed*.22)*(upper?.74:1.25);
   q/=vec2(size,size*(.65+seed2*.7));
   // Several connected rounded lobes make each opening a different shape.
   float a=length(q*vec2(.78,1.0))-.78;
   float b=length((q-vec2(.48,-.32))*vec2(1.0,1.35))-(.45+seed2*.25);
   float d=min(a,b);
   d+=.065*sin(q.x*4.0+seed*5.0)*cos(q.y*3.0);
   float cover=1.0-smoothstep(-.04,.055,d);
   vec3 ice=mix(vec3(.38,.65,.81),vec3(.52,.77,.88),seed2);
   // Broad internal planes suggest clear ice without changing the snow outline.
   ice=mix(ice,vec3(.66,.86,.94),smoothstep(-.03,.03,q.y-q.x*.44-.12)*.26);
   ice=mix(ice,vec3(.37,.53,.78),smoothstep(-.04,.04,-q.y-q.x*.67-.26)*.17);
   if(upper)ice=mix(ice,mix(FROST,SNOW,.30),.64);
   snow=mix(snow,ice,cover);
   ice_mask=mix(ice_mask,1.0,cover);
  }
 }}return snow;
}
// Staggered, fitted crystal masses retain the selected Sonic 3 motif. Rim
// facets vary in width and color; smaller junction crystals fill the interstices.
vec4 crystal_shape(vec2 uv,vec2 count){
 vec2 p=uv*count;p.x+=.25+mod(floor(p.y),2.0)*.5;
 vec2 cell=mod(floor(p),count),q=fract(p)*2.0-1.0;
 float seed=hash(cell+2.8),seed2=hash(cell+19.4);
 q-=vec2(seed-.5,seed2-.5)*.10;
 float d=max(max(abs(q.x)*(.96+seed*.05),abs(q.y)),(abs(q.x)+abs(q.y))*.714);
 return vec4(q,d,seed);
}
vec3 crystals(vec2 uv,vec2 count){
 vec4 shape=crystal_shape(uv,count);
 vec2 q=shape.xy;float d=shape.z,seed=shape.w;
 float angle=atan(q.y,q.x),sector=floor((angle+PI)*4.0/PI);
 vec3 base=mix(vec3(.22,.54,.77),vec3(.39,.57,.82),seed);
 float facet=hash(vec2(sector,seed*17.0));
 vec3 rim=mix(vec3(.28,.51,.76),vec3(.72,.89,.97),facet);
 rim+=vec3(.025)*(1.0-d);
 float inner_d=max(max(abs(q.x+.05),abs(q.y-.03)),(abs(q.x+.05)+abs(q.y-.03))*.76);
 float inner=1.0-smoothstep(.51+seed*.08,.535+seed*.08,inner_d);
 base=mix(base,vec3(.53,.81,.93),smoothstep(-.012,.012,q.y-q.x*.59+.08)*.45);
 base=mix(base,vec3(.39,.43,.74),smoothstep(-.012,.012,-q.y-q.x*.73-.26)*.25);
 base+=vec3(.016)*(q.y*.4-q.x*.3);
 vec3 face=mix(rim,base,inner);
 // Closed octagonal boundaries have a narrow, soft structural edge.
 face=mix(face,FROST,stripe(d-.91,.012)*.14);
 vec3 interstice=mix(vec3(.22,.39,.59),VIOLET,.18);
 float junction=abs(q.x)+abs(q.y);
 interstice=mix(interstice,mix(BLUE,FROST,step(q.x*q.y,0.0)*.50),smoothstep(1.50,1.69,junction));
 return mix(interstice,face,1.0-smoothstep(.975,1.005,d));
}
vec4 block_shape(vec2 uv,vec2 count){
 vec2 p=uv*count;p.x+=mod(floor(p.y),2.0)*.5;
 vec2 q=fract(p),cell=mod(floor(p),count),edge=min(q,1.0-q);
 float seed=hash(cell+11.3);
 float d=min(min(edge.x,edge.y),(edge.x+edge.y-.073)*.7071);
 return vec4(q,d,seed);
}
vec3 cut_blocks(vec2 uv,vec2 count){
 vec4 shape=block_shape(uv,count);
 vec2 q=shape.xy;float d=shape.z,seed=shape.w;
 vec3 center=mix(vec3(.28,.60,.79),vec3(.40,.66,.85),seed);
 if(item==7)center=mix(vec3(.54,.78,.89),vec3(.66,.85,.94),seed);
 float plane=smoothstep(-.01,.01,q.y-q.x*.65-.1);
 center=mix(center,item==7?vec3(.71,.90,.97):vec3(.44,.77,.90),plane*.28);
 center=mix(center,VIOLET,smoothstep(-.01,.01,.35-q.x*.83-q.y)*.13);
 float diagonal=q.y-q.x*.74;
 float band=stripe(diagonal-.03-seed*.12,.037)+stripe(diagonal-.27-seed*.1,.014);
 center=mix(center,FROST,band*.24);
 float facet=step(q.x,q.y)*.38+step(1.0-q.x,q.y)*.20;
 vec3 bevel=mix(vec3(.36,.51,.73),vec3(.68,.82,.91),facet+.2);
 if(item==7)bevel=mix(vec3(.46,.70,.86),vec3(.80,.92,.98),facet+.2);
 vec3 c=mix(bevel,center,smoothstep(.08,.10,d));
 return mix(item==7?vec3(.40,.63,.79):JOINT,c,smoothstep(.007,.025,d));
}
float snowline(float u,float base,float span,float seed){
 return base+(noise1(u*6.0,6.0,seed)-.5)*span+(noise1(u*13.0,13.0,seed+9.3)-.5)*span*.28;
}
float cap_ice_mask(vec2 uv,float base,float span,float seed){
 return 1.0-smoothstep(-.012,.012,snowline(uv.x,base,span,seed)-uv.y);
}
vec3 snow_cap(vec3 face,vec2 uv,float base,float span,float seed){
 float lip=snowline(uv.x,base,span,seed);
 float thickness=lip-uv.y;
 vec3 snow=mix(FROST,SNOW,smoothstep(-.012,.095,thickness));
 snow+=vec3(.008)*(noise1(uv.x*5.0,5.0,seed+17.0)-.5);
 return mix(face,snow,smoothstep(-.012,.012,thickness));
}
vec3 diamond_band(vec2 uv){
 // The small repeating module is intentional trim, with periodic color rhythm.
 vec2 p=vec2(uv.x*12.0+.25,(uv.y-.12)/.76*2.0);
 p.x+=mod(floor(p.y),2.0)*.5;vec2 q=fract(p)*2.0-1.0;
 vec2 cell=mod(floor(p),vec2(12,2));float seed=hash(cell+6.8);
 float d=abs(q.x)+abs(q.y);
 vec3 c=mix(vec3(.46,.62,.76),VIOLET,.12);
 vec3 facet=mix(vec3(.48,.65,.79),vec3(.64,.79,.89),step(q.x,.0)*.34+step(q.y,.0)*.48);
 facet=mix(facet,VIOLET,(seed-.2)*.15);
 facet+=vec3(.025)*(1.0-d);
 c=mix(c,facet,1.0-smoothstep(.91,.97,d));
 c=mix(c,FROST,stripe(d-.88,.025)*.18);
 float zone=smoothstep(.10,.13,uv.y)*(1.0-smoothstep(.87,.90,uv.y));
 vec3 rim=mix(FROST,SNOW,smoothstep(.0,.05,min(uv.y,1.0-uv.y)));
 return mix(rim,c,zone);
}
vec3 outer_cliff(vec2 uv){
 vec3 c=crystals(uv,vec2(6,4));
 vec2 p=vec2(uv.x*6.0,uv.y);float cell=floor(p.x),seed=hash(vec2(mod(cell,6.0),17.3));
 float x=fract(p.x)-(.40+seed*.20);
 float start=.21+seed*.10,end=.78+seed*.20;
 float t=clamp((uv.y-start)/(end-start),0.0,1.0);
 float width=(.075+seed*.065)*(1.0-t*.62);
 float curtain=(1.0-smoothstep(width,width+.012,abs(x)))*smoothstep(start,start+.03,uv.y)*(1.0-smoothstep(end-.02,end,uv.y));
 vec3 prism=mix(vec3(.28,.60,.80),vec3(.66,.88,.96),smoothstep(-.006,.006,x)*.80);
 prism=mix(prism,FROST,stripe(x+width*.55,.008)*.30);
 c=mix(c,prism,curtain*.88);
 return snow_cap(c,uv,.105,.07,7.6);
}
float needle(vec2 p,vec2 a,vec2 b,float width){
 vec2 v=b-a;float t=clamp(dot(p-a,v)/dot(v,v),0.0,1.0);
 return 1.0-smoothstep(width*(1.0-t)+.002,width*(1.0-t)+.009,length(p-a-v*t));
}
vec3 boughs(vec2 uv,out float shape_height){
 shape_height=.2;
 vec3 c=vec3(.16,.29,.32);vec2 p=uv*vec2(4.0),cell=floor(p);
 // Enlarged, rotated, overlapping boughs have no isolated glyph silhouettes.
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  vec2 g=vec2(float(x),float(y)),key=mod(cell+g,vec2(4.0));
  float seed=hash(key+1.9),seed2=hash(key+8.3);
  vec2 center=vec2(.5)+(vec2(seed,seed2)-.5)*.68;
  vec2 q=p-cell-g-center;
  float a=(seed-.5)*1.30;q=mat2(vec2(cos(a),-sin(a)),vec2(sin(a),cos(a)))*q;
  q/=vec2(.78+seed*.38,.90+seed2*.36);
  float cover=needle(q,vec2(0,.92),vec2(0,-.94),.028),tips=0.0;
  for(int j=0;j<12;j++){
   float f=float(j)/11.0;
   for(int s=-1;s<=1;s+=2){
    float jitter=hash(vec2(float(j+s*19),seed*23.0));
    vec2 start=vec2(0.0,-.63+f*1.42);
    vec2 end=vec2(float(s)*(.22+sqrt(f)*.60)*( .90+jitter*.18),start.y-.29-jitter*.12);
    float blade=needle(q,start,end,.052);
    cover=max(cover,blade);
    tips=max(tips,needle(q,mix(start,end,.64),end,.022));
   }
  }
  vec3 green=mix(vec3(.19,.35,.36),vec3(.27,.44,.43),seed2);
  green+=vec3(.018)*smoothstep(-.5,.5,q.x);
  green=mix(green,vec3(.37,.52,.53),tips*.22);
  c=mix(c,green,cover);
  shape_height=max(shape_height,.2+cover*(.20+seed*.05));
 }}
 // Snow lies across connected bough masses rather than coloring identical tips.
 float snow=pn(uv,8.0,17.4)*.72+pn(uv,13.0,1.9)*.28;
 float mask=smoothstep(.605,.665,snow);
 vec3 powder=mix(FROST,SNOW,smoothstep(.59,.80,snow));
 shape_height=mix(shape_height,.70,mask);
 return mix(c,powder,mask);
}
vec3 floe_lake(vec2 uv,out float ice_mask){
 ice_mask=1.0;
 vec3 c=mix(vec3(.20,.34,.53),vec3(.23,.39,.59),pn(uv,3.0,4.4));
 c+=vec3(.009)*pn(uv,7.0,2.1);
 // A longer 8-by-8 placement cycle belongs to the broad lake, not to small
 // gameplay-scale tile repeats. The 1024 export preserves individual floes.
 vec2 p=uv*vec2(8.0),cell=floor(p);
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  vec2 g=vec2(float(x),float(y)),key=mod(cell+g,vec2(8.0));
  float seed=hash(key+7.8),shape=hash(key+31.4);
  if(seed>.34){
   vec2 center=vec2(.5)+(vec2(hash(key+2.7),hash(key+19.6))-.5)*.85;
   vec2 q=p-cell-g-center;
   float angle=shape*TAU;q=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*q;
   float size=.18+hash(key+43.7)*.26;
   q/=vec2(size,size*(.48+seed*.90));
   float d=-10.0;
   int sides=5+int(floor(shape*4.0));
   for(int side=0;side<8;side++){
    if(side<sides){
     float a=float(side)*TAU/float(sides);
     float radius=.64+hash(vec2(float(side),shape*41.0))*.38;
     d=max(d,dot(q,vec2(cos(a),sin(a)))-radius);
    }
   }
   float cover=1.0-smoothstep(-.015,.015,d);
   vec3 snow=mix(FROST,SNOW,smoothstep(.0,.22,-d));
   snow+=vec3(.012)*(shape-.5);
   snow=mix(snow,vec3(.80,.89,.94),smoothstep(-.012,.012,q.y-q.x*.47)*.16);
   c=mix(c,snow,cover);
   ice_mask=mix(ice_mask,0.0,cover);
  }
 }}return c;
}
void fragment(){
 vec2 uv=UV;vec3 c=SNOW;float ice_mask=0.0;
 if(item==1)c=snow_field(uv,false,ice_mask);
 else if(item==2){
  c=diamond_band(uv);
  ice_mask=smoothstep(.10,.13,uv.y)*(1.0-smoothstep(.87,.90,uv.y));
 }
 else if(item==3){
  c=snow_cap(crystals(uv,vec2(6,4)),uv,.10,.065,3.4);
  ice_mask=cap_ice_mask(uv,.10,.065,3.4);
 }
 else if(item==5)c=snow_field(uv+vec2(.31,.19),true,ice_mask);
 else if(item==6){
  c=snow_cap(cut_blocks(uv,vec2(6,1)),uv,.64,.16,9.2);
  ice_mask=cap_ice_mask(uv,.64,.16,9.2);
 }
 else if(item==7){
  c=cut_blocks(uv,vec2(3,6));
  float edge=min(uv.x,1.0-uv.x);
  float lip=.074+(noise1(uv.y*8.0,8.0,7.6)-.5)*.021;
  vec3 powder=mix(FROST,SNOW,smoothstep(.0,.040,lip-edge));
  c=mix(c,powder,1.0-smoothstep(lip-.008,lip+.008,edge));
  ice_mask=smoothstep(lip-.008,lip+.008,edge);
 }
 else if(item==8){
  c=snow_cap(crystals(uv,vec2(6,1)),uv,.255,.11,5.8);
  ice_mask=cap_ice_mask(uv,.255,.11,5.8);
 }
 else if(item==9){c=outer_cliff(uv);ice_mask=cap_ice_mask(uv,.105,.07,7.6);}
 else if(item==11){float shape_height;c=boughs(uv,shape_height);}
 else if(item==12)c=floe_lake(uv,ice_mask);
 // Packed linear response: R roughness, G specular, B structural ice mask.
 // Ice remains dielectric. Snow uses its existing calm, rough response.
 if(response_map)c=vec3(mix(.93,.16,ice_mask),mix(.18,.62,ice_mask),ice_mask);
 COLOR=vec4(clamp(c,vec3(0.0),vec3(1.0)),1.0);
}
