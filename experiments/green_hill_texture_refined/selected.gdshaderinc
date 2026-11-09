// Phase-two colour artwork. Leaf shapes are shared for later structural maps.
vec3 selected_turf(vec2 uv,bool upper) {
 float pattern=upper?mod(floor(uv.x*4.0)+floor(uv.y*4.0),2.0):step(.5,fract(uv.x*4.0));
 vec3 low=upper?vec3(.27,.56,.075):vec3(.22,.49,.065);
 vec3 high=upper?vec3(.34,.64,.095):vec3(.29,.57,.085);

 vec3 color=mix(low,high,pattern);
 color*=.95+.08*turf_noise(uv,23.0);
 color*=.98+.04*turf_noise(uv,127.0);
 // Stripes vary across U only; V runs north-south during later placement.
 return color;
}
vec3 selected_leaves(vec2 uv,bool hanging) {
 vec2 p=vec2(uv.x*16.0,uv.y);
 float cover=0.0,pigment=.5;
 for(int i=-1;i<=1;i++) {
  float cell=floor(p.x)+float(i);
  float r=variation(vec2(cell,3),vec2(16.0));
  float s=variation(vec2(cell,11),vec2(16.0));
  float center=cell+.28+.4*r;
  float leaf_length=.60+.20*s;
  vec2 q=vec2((p.x-center)/(.48+.10*s),(p.y-.38)/leaf_length);
  q.x+=q.y*(r-.5)*.45;
  // Pointed, broad leaves, with irregular lengths and overlap rather than identical teeth.
  float shape=abs(q.x)*.65+abs(q.y)*1.25;
  float mask=1.0-smoothstep(.57,.62,shape);
  if(hanging) mask=max(mask,1.0-smoothstep(.32,.36,uv.y));
  if(mask>cover){cover=mask;pigment=r;}
 }
 return vec3(cover,pigment,0);
}
vec3 selected_border(vec2 uv,bool upper) {
 vec3 leaves=selected_leaves(vec2(uv.x,uv.y*.95),false);
 float field=turf_noise(vec2(uv.x*2.0,uv.y*.22),19.0);
 vec3 c=mix(vec3(.19,.42,.065),vec3(.25,.51,.08),field);
 vec3 leaf_color=mix(vec3(.23,.48,.065),vec3(.34,.59,.105),leaves.y);
 c=mix(c,leaf_color,leaves.x*.82);
 vec3 small=grass_cluster(vec2(uv.x*2.0,uv.y*.25));
 c+=vec3(.035,.045,.008)*small.x*(small.z-.35);
 return c*(upper?1.08:1.0);
}
vec3 selected_bamboo(vec2 uv) {
 vec2 p=vec2(uv.x*2.0,uv.y*4.0),q=fract(p);
 float r=variation(vec2(floor(p.y),0),vec2(4));
 vec3 c=mix(vec3(.55,.35,.12),vec3(.72,.51,.22),r);
 float seam=1.0-smoothstep(.012,.025,min(q.y,1.0-q.y));
 c=mix(c,vec3(.33,.21,.075),seam);
 float node=1.0-smoothstep(.032,.044,min(q.x,1.0-q.x));
 c=mix(c,vec3(.41,.27,.105),node*.8);
 // Quiet fibres along the trim, without painted cylindrical highlights.
 float fibre=1.0-smoothstep(.005,.012,abs(q.y-.36-.012*sin(uv.x*TAU*2.0)));
 return mix(c,c*.90,fibre);
}
void fragment() {
 vec2 uv=UV;
 vec3 color=vec3(0);float alpha=1.0;
 if(item==1 || item==5)color=selected_turf(uv,item==5);
 else if(item==2 || item==6)color=selected_border(uv,item==6);
 else if(item==3)color=gh_soil(uv,false);
 else if(item==4) {
  vec3 leaves=selected_leaves(uv,true);
  alpha=leaves.x;
  color=mix(vec3(.24,.48,.055),vec3(.34,.60,.08),leaves.y);
  color*=mix(1.05,.77,uv.y);
  color+=vec3(.025,.035,.005)*grass_cluster(vec2(uv.x*2.0,uv.y*.2)).x;
 } else if(item==8)color=selected_bamboo(uv);
 else if(item==10) {
  float n=.72*turf_noise(uv,7.0)+.23*turf_noise(uv,17.0)+.05*turf_noise(uv,31.0);
  color=mix(vec3(.13,.37,.11),vec3(.29,.56,.14),smoothstep(.25,.75,n));
 } else if(item==11)color=gh_rock(uv,true);
 COLOR=vec4(color,alpha);
}
