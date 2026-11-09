shader_type canvas_item;
render_mode unshaded;
uniform int item = 1;

// Periodic integer-cell variation. No lighting or height is baked into these colors.
float variation(vec2 cell, vec2 period) {
 vec2 c = mod(cell, period);
 return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
}
float edge(float x) { return min(fract(x), 1.0-fract(x)); }
float stroke(float d, float width, float aa) {
 return 1.0-smoothstep(width, width+aa, d);
}
float segment(vec2 p, vec2 a, vec2 b) {
 vec2 v=b-a;
 return length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0));
}
float mortar(vec2 p, float width, float radius) {
 // Small corner rounding and a soft raster edge match the retained textures.
 vec2 q=abs(fract(p)-0.5)-(vec2(0.5-width)-radius);
 float d=length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-radius;
 float aa=max(length(fwidth(p))*0.45,0.001);
 return smoothstep(-aa,aa,d);
}
vec3 floor_color(vec2 uv) {
 vec2 p=uv*vec2(8.0,10.0);
 p.x+=mod(floor(p.y),2.0)*0.5;
 vec3 color=mix(vec3(0.57,0.565,0.515),vec3(0.65,0.64,0.58),variation(floor(p),vec2(8.0,10.0)));
 return mix(color,vec3(0.43,0.42,0.36),mortar(p,0.022,0.042));
}
// Periodic random fields avoid directional waves and repeated tuft glyphs.
float turf_noise(vec2 uv, float cells) {
 vec2 p=uv*cells, c=floor(p), f=fract(p);
 f=f*f*(3.0-2.0*f);
 return mix(mix(variation(c,vec2(cells)),variation(c+vec2(1.0,0.0),vec2(cells)),f.x),
 mix(variation(c+vec2(0.0,1.0),vec2(cells)),variation(c+vec2(1.0),vec2(cells)),f.x),f.y);
}
float turf_blades(vec2 uv, float cells, vec2 offset) {
 vec2 p=(uv+offset)*cells, c=floor(p);
 float r=variation(c,vec2(cells));
 float s=variation(c+vec2(13.0,7.0),vec2(cells));
 vec2 q=fract(p)-vec2(0.27+0.46*r,0.27+0.46*s);
 float angle=r*TAU;
 q=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*q;
 // A short tapered blade, not a three-pronged stamped grass symbol.
 float length_blade=0.10+0.11*s;
 float d=segment(q,vec2(0.0,-length_blade),vec2(0.0,length_blade));
 float width=0.025+0.035*r;
 return (1.0-smoothstep(width,width+0.055,d))*(0.55+0.45*s);
}
float turf_detail(vec2 uv) {
 return max(turf_blades(uv,26.0,vec2(0.0)),turf_blades(uv,33.0,vec2(0.173,0.397))*0.75);
}
// Shared blade geometry for color and relief. The UV warp is periodic.
vec3 grass_cluster(vec2 uv) {
 vec2 warp=vec2(turf_noise(uv,7.0),turf_noise(uv+vec2(0.271,0.613),9.0))-0.5;
 vec2 p=(uv+warp*0.045)*18.0;
 vec2 c=floor(p);
 float cover=0.0, height=0.0, shade=0.5;
 for(int iy=-1;iy<=1;iy++) {
  for(int ix=-1;ix<=1;ix++) {
   vec2 cell=c+vec2(float(ix),float(iy));
   float r=variation(cell,vec2(18.0));
   float s=variation(cell+vec2(11.0,5.0),vec2(18.0));
   vec2 center=cell+vec2(0.25+0.50*r,0.25+0.50*s);
   vec2 q=p-center;
   float angle=r*TAU;
   q=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*q;
   for(int blade=0;blade<4;blade++) {
    float j=float(blade)-1.5;
    float length_blade=0.55+0.35*variation(cell+vec2(float(blade)*7.0,3.0),vec2(18.0));
    float y=(q.y+0.42)/length_blade;
    float x=q.x-j*0.14-j*y*0.16;
    float width=mix(0.115,0.008,clamp(y,0.0,1.0));
    float ridge=clamp(1.0-abs(x)/width,0.0,1.0);
    float blade_mask=smoothstep(0.0,0.16,ridge)*smoothstep(0.0,0.05,y)*(1.0-smoothstep(0.96,1.0,y));
    float raised=blade_mask*(0.30+0.55*ridge)*(0.50+0.50*clamp(y,0.0,1.0));
    cover=max(cover,blade_mask);
    if(raised>height) {height=raised; shade=s*0.7+0.3*(float(blade)/3.0);}
   }
  }
 }
 return vec3(cover,height,shade);
}
vec3 grass_color(vec2 uv) {
 vec3 cluster=grass_cluster(uv);
 vec3 undergrowth=mix(vec3(0.20,0.39,0.10),vec3(0.27,0.46,0.13),turf_noise(uv,37.0));
 vec3 blades=mix(vec3(0.28,0.48,0.12),vec3(0.44,0.62,0.19),cluster.z);
 return mix(undergrowth,blades,cluster.x);
}
vec3 foliage_color(vec2 uv) {
 float patch=0.65*turf_noise(uv,9.0)+0.25*turf_noise(uv,21.0)+0.10*turf_noise(uv,43.0);
 return mix(vec3(0.13,0.29,0.10),vec3(0.43,0.63,0.19),smoothstep(0.29,0.70,patch));
}
vec3 roof_color(vec2 uv) {
 vec2 p=uv*vec2(12.0,10.0);
 float x=fract(p.x);
 float curve=0.12+0.14*pow(x*2.0-1.0,2.0);
 float row=floor(p.y-curve);
 float aa=max(length(fwidth(p))*0.4,0.001);
 float seam=max(stroke(edge(p.x),0.016,aa),stroke(edge(p.y-curve),0.018,aa));
 vec3 color=mix(vec3(0.63,0.205,0.12),vec3(0.72,0.265,0.155),variation(vec2(floor(p.x),row),vec2(12.0,10.0)));
 return mix(color,vec3(0.45,0.17,0.105),seam*0.80);
}
vec3 ramp_color(vec2 uv) {
 vec2 p=uv*8.0;
 p.x+=mod(floor(p.y),2.0)*0.5;
 float r=variation(floor(p),vec2(8.0));
 vec3 color=mix(vec3(0.66,0.31,0.195),vec3(0.735,0.365,0.23),r);
 // Burgundy accents are whole, flush tiles, not recessed marks.
 color=mix(color,vec3(0.51,0.255,0.225),step(0.80,r));
 return mix(color,vec3(0.46,0.31,0.22),mortar(p,0.020,0.025));
}
vec3 railing_color(vec2 uv) {
 float p=uv.x*2.0;
 vec3 color=mix(vec3(0.225,0.435,0.415),vec3(0.24,0.45,0.425),mod(floor(p),2.0));
 color=mix(color,vec3(0.17,0.345,0.325),stroke(edge(p),0.006,fwidth(p)*0.65));
 return mix(color,vec3(0.91,0.81,0.63),1.0-smoothstep(0.105,0.115,uv.y));
}
float arch_distance(vec2 p) {
 float d=max(abs(p.x)-0.20,p.y-0.24);
 if(p.y < -0.10) d=max(d,length(vec2(p.x,p.y+0.10))-0.20);
 return d;
}
vec3 facade_color(vec2 uv) {
 vec2 p=uv*vec2(8.0,6.0);
 p.x+=mod(floor(p.y),2.0)*0.5;
 vec3 color=mix(vec3(0.73,0.66,0.51),vec3(0.81,0.74,0.58),variation(floor(p),vec2(8.0,6.0)));
 color=mix(color,vec3(0.59,0.53,0.40),mortar(p,0.018,0.018)*0.75);
 vec2 bay=vec2(fract(uv.x*2.0)-0.5,uv.y-0.46);
 float d=arch_distance(bay);
 float aa=max(length(fwidth(bay))*0.55,0.001);
 color=mix(color,vec3(0.87,0.78,0.59),1.0-smoothstep(0.030,0.030+aa,d));
 color=mix(color,vec3(0.22,0.35,0.32),1.0-smoothstep(0.0,aa,d));
 float interior=1.0-smoothstep(-0.012,-0.009,d);
 color=mix(color,vec3(0.34,0.46,0.38),stroke(abs(bay.x),0.009,aa)*interior);
 float sill=max(abs(bay.x)-0.24,abs(bay.y-0.265)-0.017);
 return mix(color,vec3(0.87,0.78,0.59),1.0-smoothstep(0.0,aa,sill));
}
void fragment() {
 vec3 color=vec3(0.5);
 if(item==1) color=floor_color(UV);
 else if(item==2) color=grass_color(UV);
 else if(item==5) color=roof_color(UV);
 else if(item==7) color=ramp_color(UV);
 else if(item==8) color=railing_color(UV);
 else if(item==9) color=facade_color(UV);
 COLOR=vec4(color,1.0);
}
