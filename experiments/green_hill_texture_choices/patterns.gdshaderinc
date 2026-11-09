uniform int option=0;
vec3 gh_grass(vec2 uv,bool checker,bool raised) {
 float pattern=checker?mod(floor(uv.x*4.0)+floor(uv.y*4.0),2.0):step(.5,fract(uv.x*4.0));
 vec3 low=raised?vec3(.27,.56,.075):vec3(.22,.49,.065);
 vec3 high=raised?vec3(.34,.64,.095):vec3(.29,.57,.085);
 vec3 color=mix(low,high,pattern);
 vec3 cluster=grass_cluster(uv*2.0);
 // Blade colours cross pattern boundaries; there are no tile joints in turf.
 color*=.92+.12*turf_noise(uv,23.0);
 color+=vec3(.06,.085,.015)*cluster.x*(cluster.z-.25);
 return color;
}
vec3 gh_soil(vec2 uv,bool ochre) {
 vec2 p=uv*(ochre?6.0:4.0);
 float check=mod(floor(p.x)+floor(p.y),2.0);
 vec3 color=mix(ochre?vec3(.43,.26,.10):vec3(.35,.15,.065),ochre?vec3(.65,.39,.15):vec3(.74,.37,.12),check);
 // Sparse mineral variation, not separate raised checker bricks.
 float patch=turf_noise(uv,13.0);
 color*=.96+.08*patch;
 vec2 q=fract(uv*vec2(3.0,2.0));
 float crack=stroke(abs(q.x-(.48+.12*(q.y-.5))),.003,.004)*smoothstep(.05,.25,q.y)*(1.0-smoothstep(.7,.95,q.y));
 return mix(color,color*.68,crack);
}
vec3 gh_border(vec2 uv,bool leafy,bool bright) {
 vec3 c=gh_grass(uv*vec2(2.0,.22),false,bright);
 float fringe=.38+.10*sin(uv.x*TAU*8.0)+.07*sin(uv.x*TAU*13.0);
 c=mix(c*.72,c,smoothstep(fringe-.025,fringe+.025,uv.y));
 if(leafy) {
  vec2 q=fract(uv*vec2(16.0,2.0))-.5;
  float leaf=1.0-smoothstep(.28,.34,abs(q.x)*.8+abs(q.y));
  c=mix(c,vec3(.29,.57,.09),leaf*.65);
 }
 return c;
}
vec3 gh_wood(vec2 uv,bool bamboo) {
 vec2 p=uv*vec2(bamboo?7.0:5.0,2.0);
 vec2 q=fract(p);
 float seam=stroke(min(q.x,1.0-q.x),.015,.01);
 vec3 color=mix(bamboo?vec3(.55,.35,.12):vec3(.56,.30,.10),bamboo?vec3(.72,.51,.22):vec3(.69,.41,.17),variation(vec2(floor(p.x),0),vec2(7.0)));
 color=mix(color,vec3(.29,.17,.065),seam*.8);
 if(bamboo) color=mix(color,vec3(.40,.27,.10),stroke(min(q.y,1.0-q.y),.025,.02));
 else {
  float grain=stroke(abs(q.x-.3-.025*sin(uv.y*TAU*2.0)),.006,.008);
  color=mix(color,color*.82,grain);
 }
 return color;
}
vec3 gh_shrub(vec2 uv,bool leaves) {
 if(!leaves) {
  float n=.75*turf_noise(uv,7.0)+.25*turf_noise(uv,17.0);
  // Limited pigment patches; no directional highlights baked into the clusters.
  return mix(vec3(.13,.37,.11),vec3(.29,.56,.14),smoothstep(.25,.75,n));
 }
 vec2 p=uv*12.0;
 p.x+=mod(floor(p.y),2.0)*.5;
 vec2 q=fract(p)-.5;
 float leaf=1.0-smoothstep(.36,.42,abs(q.x)*.8+abs(q.y));
 vec3 c=mix(vec3(.13,.35,.11),vec3(.28,.51,.12),variation(floor(p),vec2(12.0)));
 return mix(vec3(.12,.31,.10),c,leaf);
}
vec3 gh_rock(vec2 uv,bool cool) {
 vec2 p=uv*4.0,cell=floor(p);
 float best=100.0;
 vec2 selected=vec2(0);
 for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++) {
  vec2 candidate=cell+vec2(float(x),float(y));
  vec2 center=candidate+vec2(.2+.6*variation(candidate,vec2(4)),.2+.6*variation(candidate+vec2(3,7),vec2(4)));
  float d=dot(p-center,p-center);
  if(d<best){best=d;selected=candidate;}
 }
 float v=variation(selected,vec2(4.0));
 return mix(cool?vec3(.48,.53,.51):vec3(.60,.51,.34),cool?vec3(.58,.62,.57):vec3(.71,.63,.43),v);
}
void fragment() {
 vec2 uv=UV;bool b=option==1;
 vec3 c=vec3(0);float alpha=1.0;
 if(item==1 || item==5)c=gh_grass(uv,b,item==5);
 else if(item==2 || item==6)c=gh_border(uv,b,item==6);
 else if(item==3 || item==9)c=gh_soil(uv,b);
 else if(item==4) {
  vec2 q=vec2(fract(uv.x*(b?16.0:24.0)),uv.y);
  float length_tip=.58+.20*variation(vec2(floor(uv.x*24.0),0),vec2(24.0));
  float edge=b?(.58+.22*(1.0-abs(q.x-.5)*2.0)):(length_tip-.19*abs(q.x-.5)*2.0);
  alpha=1.0-smoothstep(edge-.012,edge+.012,uv.y);
  c=gh_grass(uv*vec2(2,.18),false,true)*mix(1.0,.65,uv.y);
 } else if(item==7)c=gh_wood(uv,b);
 else if(item==8)c=b?gh_wood(uv.yx,true):gh_border(uv,false,true);
 else if(item==10)c=gh_shrub(uv,b);
 else if(item==11)c=gh_rock(uv,b);
 COLOR=vec4(c,alpha);
}
