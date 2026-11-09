shader_type canvas_item;
render_mode unshaded;
uniform int item=1;
uniform int option=0;
const vec3 PALE=vec3(.83,.84,.75);
const vec3 SEAM=vec3(.48,.54,.42);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float box(vec2 p,vec2 c,vec2 h){vec2 d=abs(p-c)-h;return 1.0-smoothstep(-.002,.003,max(d.x,d.y));}
float line(float d,float w){return 1.0-smoothstep(w,w+.004,abs(d));}
vec3 face(vec2 p,vec3 base,float seed){
 float broad=noise(p*1.2+seed*15.0)-.5;
 float plane=smoothstep(.46,.58,noise(p*2.3+seed*8.0))-.5;
 return base+vec3(broad*.032+plane*.009)+vec3(.016,.012,-.012)*(seed-.5);
}
float block_id(vec2 p){
 ivec2 q=ivec2(mod(p,8.0));
 const float cells[64]=float[64](
  0.,0.,0.,1.,1.,1.,2.,2.,
  0.,0.,0.,1.,1.,1.,2.,2.,
  3.,3.,0.,1.,4.,4.,2.,2.,
  3.,3.,3.,4.,4.,4.,5.,5.,
  6.,6.,3.,4.,4.,4.,5.,5.,
  6.,6.,7.,7.,7.,5.,5.,5.,
  6.,6.,7.,7.,8.,8.,8.,8.,
  9.,9.,9.,7.,8.,8.,8.,8.);
 vec2 m=floor(p/8.0);
 return cells[q.y*8+q.x]+m.x*13.0+m.y*173.0;
}
vec3 keyed_stone(vec2 uv){
 vec2 p=uv*8.0,cell=floor(p),q=fract(p);float id=block_id(cell),d=2.0;
 if(block_id(cell+vec2(-1,0))!=id)d=min(d,q.x);
 if(block_id(cell+vec2(1,0))!=id)d=min(d,1.0-q.x);
 if(block_id(cell+vec2(0,-1))!=id)d=min(d,q.y);
 if(block_id(cell+vec2(0,1))!=id)d=min(d,1.0-q.y);
 for(int x=-1;x<=1;x+=2){for(int y=-1;y<=1;y+=2){
  if(block_id(cell+vec2(float(x),float(y)))!=id)d=min(d,length(q-vec2(x<0?0.0:1.0,y<0?0.0:1.0)));
 }}
 float seed=hash(vec2(mod(id,13.0),mod(id,173.0)));
 vec3 c=face(p,PALE+(seed-.5)*.055,seed);
 c=mix(c,PALE-.045,(1.0-smoothstep(.015,.070,d))*.48);
 c=mix(SEAM,c,smoothstep(.006,.018,d));
 // A few deliberately localized green joint patches, not full-face grime.
 float green=(1.0-smoothstep(.025,.085,d))*smoothstep(.67,.79,noise(p*1.3+vec2(3,7)));
 c=mix(c,vec3(.46,.58,.27),green*.6);
 return c;
}
vec3 rectangular(vec2 uv,vec3 base){
 vec2 p=uv; p.x+=mod(floor(p.y),2.0)*.5;
 vec2 q=fract(p),edge=min(q,1.0-q);float d=min(edge.x,edge.y);
 float seed=hash(mod(floor(p),vec2(8)));
 vec3 c=face(p,base+(seed-.5)*.045,seed);
 c=mix(c,base*.91,1.0-smoothstep(.012,.055,d));
 return mix(SEAM,c,smoothstep(.007,.020,d));
}
vec3 grass(vec2 uv){
 vec2 p=uv*10.0,cell=floor(p);
 vec3 c=vec3(.31,.45,.13)+vec3(.018,.024,.005)*(noise(uv*7.0)-.5);
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){
  vec2 tile=cell+vec2(float(x),float(y));vec2 key=mod(tile,10.0);
  vec2 center=tile+vec2(.25)+vec2(hash(key),hash(key+6.7))*.5;
  for(int blade=0;blade<12;blade++){
   float seed=hash(key+float(blade)*vec2(4.2,7.9));
   float a=seed*6.283185;
   vec2 direction=vec2(cos(a),sin(a)),across=vec2(-direction.y,direction.x);
   vec2 base=center+across*(hash(key+float(blade)*8.3)-.5)*.80;
   vec2 v=p-base;float length_blade=.82+hash(key+float(blade)*5.1+2.0)*.58;
   float t=dot(v,direction)/length_blade;
   float side=dot(v,across)-t*t*(seed-.5)*.25;
   float width=(.075+seed*.065)*(1.0-t);
   float mask=(1.0-smoothstep(width-.008,width+.008,abs(side)))*smoothstep(-.02,.035,t)*(1.0-smoothstep(.93,1.0,t));
   vec3 leaf=mix(vec3(.27,.42,.105),vec3(.45,.60,.20),seed);
   leaf+=vec3(.018,.026,.006)*smoothstep(-.01,.01,side);
   c=mix(c,leaf,mask);
  }
 }}
 return c;
}
vec3 inlaid_court(vec2 uv){
 vec3 c=rectangular(uv*vec2(6,6),PALE);
 vec2 q=fract(uv*2.0);
 // Complete rectangular courts replace the earlier repeated circular icons.
 float outer=box(q,vec2(.5),vec2(.34,.34));
 c=mix(c,SEAM,outer);
 c=mix(c,PALE+.035,box(q,vec2(.5),vec2(.315)));
 vec3 inlay=face(q*5.0,vec3(.19,.39,.43),hash(floor(uv*2.0)));
 vec2 p=q*4.0;vec2 e=min(fract(p),1.0-fract(p));
 inlay=mix(inlay,vec3(.29,.60,.61),1.0-smoothstep(.008,.018,min(e.x,e.y)));
 c=mix(c,inlay,box(q,vec2(.5),vec2(.27)));
 // Stepped pale keys borrow the reference's fitted stone edges.
 for(int i=0;i<4;i++){
  float a=float(i)*1.5707963;vec2 v=q-.5;
  vec2 local=vec2(cos(a)*v.x-sin(a)*v.y,sin(a)*v.x+cos(a)*v.y);
  c=mix(c,PALE,box(local,vec2(.05,.27),vec2(.07,.045)));
 }
 return c;
}
vec3 cornice(vec2 uv){
 vec3 c=rectangular(vec2(uv.x*6.0,uv.y),PALE);
 // Broad apron, lower return and a small throat: a cap face, not top-border grass.
 float joint=line(uv.y-.17,.010)+line(uv.y-.73,.010)+line(uv.y-.89,.008);
 c=mix(c,SEAM,joint*.6);
 c=mix(c,PALE+.025,box(uv,vec2(.5,.08),vec2(.6,.055)));
 c=mix(c,PALE*.94,box(uv,vec2(.5,.81),vec2(.6,.05)));
 vec2 q=vec2(fract(uv.x*6.0),uv.y);
 // One recessed rectangular panel per block, referencing supplied image 8.
 c=mix(c,PALE*.88,box(q,vec2(.5,.45),vec2(.35,.15)));
 c=mix(c,face(q*2.0,PALE-.015,.3),box(q,vec2(.5,.45),vec2(.31,.115)));
 return c;
}
void fragment(){
 vec3 c=keyed_stone(UV);
 if(item==4)c=cornice(UV);
 if(item==5)c=option==0?grass(UV):inlaid_court(UV);
 COLOR=vec4(c,1.0);
}
