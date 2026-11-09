shader_type canvas_item;
render_mode unshaded;
uniform int item = 1;
uniform int option = 0;

float tint(vec2 cell, vec2 period) {
 vec2 c = mod(cell, period);
 return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
}
float line_mask(float distance, float width, float aa) {
 return 1.0 - smoothstep(width, width + aa, distance);
}
float edge_distance(float x) { return min(fract(x), 1.0 - fract(x)); }
vec3 blocks(vec2 uv, vec2 count, vec3 low, vec3 high, vec3 mortar, float joint) {
 vec2 p = uv * count;
 p.x += mod(floor(p.y), 2.0) * 0.5;
 vec2 edge = min(fract(p), 1.0 - fract(p));
 float distance = min(edge.x, edge.y);
 float aa = max(length(fwidth(p)) * 0.55, 0.001);
 float seam = line_mask(distance, joint, aa);
 return mix(mix(low, high, tint(floor(p), count)), mortar, seam);
}
vec3 paving(vec2 uv, bool diagonal) {
 if (!diagonal) return blocks(uv, vec2(8.0, 10.0), vec3(0.57,0.57,0.52), vec3(0.66,0.65,0.59), vec3(0.40,0.39,0.34), 0.018);
 vec2 p = vec2(uv.x + uv.y, uv.y - uv.x) * 8.0;
 vec2 edge = min(fract(p), 1.0 - fract(p));
 float seam = line_mask(min(edge.x, edge.y), 0.025, length(fwidth(p)) * 0.55);
 return mix(mix(vec3(0.46,0.52,0.53), vec3(0.59,0.63,0.60), tint(floor(p),vec2(16.0))), vec3(0.33,0.37,0.35), seam);
}
float segment(vec2 p, vec2 a, vec2 b) {
 vec2 d = b - a;
 return length(p - a - d * clamp(dot(p-a,d)/dot(d,d),0.0,1.0));
}
vec3 lawn(vec2 uv, bool clover) {
 float broad = sin(TAU * (uv.x * 3.0 + uv.y)) * sin(TAU * (uv.y * 4.0 - uv.x));
 vec3 base = clover ? mix(vec3(0.24,0.44,0.19),vec3(0.32,0.51,0.23),smoothstep(-0.55,0.55,broad)) : mix(vec3(0.34,0.54,0.18),vec3(0.40,0.60,0.22),smoothstep(-0.55,0.55,broad));
 vec2 p = uv * 5.0;
 vec2 cell = floor(p);
 vec2 q = fract(p) - vec2(0.45 + 0.10 * tint(cell,vec2(5.0)),0.52);
 float aa = length(fwidth(p)) * 0.6;
 if (clover) {
  float leaf = min(min(length(q-vec2(-0.055,-0.03)),length(q-vec2(0.055,-0.03))),length(q-vec2(0.0,-0.105)));
  base = mix(base,vec3(0.37,0.55,0.27),1.0-smoothstep(0.065,0.065+aa,leaf));
 } else {
  float blade = min(segment(q,vec2(0.0,0.07),vec2(-0.07,-0.055)),segment(q,vec2(0.01,0.07),vec2(0.04,-0.12)));
  blade = min(blade,segment(q,vec2(0.025,0.07),vec2(0.11,-0.035)));
  base = mix(base,vec3(0.28,0.47,0.16),line_mask(blade,0.013,aa));
 }
 return base;
}
vec3 masonry(vec2 uv, bool brick) {
 return brick ? blocks(uv,vec2(8.0,10.0),vec3(0.58,0.36,0.28),vec3(0.67,0.43,0.33),vec3(0.48,0.43,0.35),0.025) : blocks(uv,vec2(6.0,8.0),vec3(0.72,0.65,0.50),vec3(0.82,0.75,0.59),vec3(0.57,0.50,0.37),0.018);
}
vec3 trim(vec2 uv, bool alternate, bool red) {
 float p = uv.x * (alternate ? 8.0 : 4.0);
 float joint = line_mask(edge_distance(p),0.014,max(fwidth(p)*0.65,0.001));
 vec3 color = red ? mix(vec3(0.61,0.21,0.12),vec3(0.70,0.28,0.16),mod(floor(p),2.0)) : mix(vec3(0.82,0.73,0.54),vec3(0.88,0.80,0.64),alternate ? mod(floor(p),2.0) : 0.5);
 color = mix(color, red ? vec3(0.43,0.19,0.12) : vec3(0.62,0.53,0.37),joint*0.7);
 float band = 1.0-smoothstep(0.10,0.11,min(uv.y,1.0-uv.y));
 return mix(color,vec3(0.91,0.83,0.65),band);
}
vec3 roof(vec2 uv, bool scallop) {
 vec2 p = uv * vec2(12.0,10.0);
 float row = floor(p.y);
 if (scallop) p.x += mod(row,2.0)*0.5;
 vec2 f = fract(p);
 float aa = max(length(fwidth(p))*0.5,0.001);
 float seam;
 if (scallop) {
  float arc = 0.22 + 0.67 * sqrt(max(0.0,1.0-pow(f.x*2.0-1.0,2.0)));
  seam = max(line_mask(abs(f.y-arc),0.015,aa),line_mask(edge_distance(p.x),0.018,aa)*(1.0-smoothstep(0.20,0.24,f.y)));
 } else {
  float curve = 0.12 + 0.14 * pow(f.x*2.0-1.0,2.0);
  seam = max(line_mask(edge_distance(p.y-curve),0.018,aa),line_mask(edge_distance(p.x),0.018,aa));
  row = floor(p.y-curve);
 }
 vec3 color = mix(vec3(0.62,0.19,0.10),vec3(0.73,0.27,0.15),tint(vec2(floor(p.x),row),vec2(12.0,10.0)));
 return mix(color,vec3(0.40,0.14,0.09),seam*0.75);
}
vec3 ramp(vec2 uv, bool red) {
 if (red) {
  vec2 p = uv*vec2(8.0,8.0);
  p.x += mod(floor(p.y),2.0)*0.5;
  float dark = step(0.80,tint(floor(p),vec2(8.0)));
  vec3 color = mix(mix(vec3(0.66,0.30,0.18),vec3(0.74,0.37,0.23),tint(floor(p),vec2(8.0))),vec3(0.46,0.22,0.20),dark);
  float joint = line_mask(min(edge_distance(p.x),edge_distance(p.y)),0.020,length(fwidth(p))*0.5);
  return mix(color,vec3(0.43,0.29,0.19),joint);
 }
 vec2 p = vec2(uv.x+uv.y,uv.y-uv.x)*6.0;
 vec2 f = fract(p);
 if (mod(floor(p.x)+floor(p.y),2.0)>0.5) f=f.yx;
 float d=min(min(f.x,1.0-f.x),min(edge_distance(f.y),abs(f.y-0.5)));
 float seam=line_mask(d,0.012,length(fwidth(p))*0.5);
 return mix(mix(vec3(0.72,0.65,0.49),vec3(0.81,0.75,0.59),tint(floor(p),vec2(12.0))),vec3(0.51,0.46,0.34),seam);
}
vec3 railing(vec2 uv, bool metal) {
 vec3 face = metal ? vec3(0.22,0.44,0.42) : vec3(0.83,0.75,0.58);
 float seam=line_mask(edge_distance(uv.x*2.0),0.010,fwidth(uv.x*2.0)*0.7);
 face=mix(face,metal?vec3(0.14,0.31,0.30):vec3(0.62,0.55,0.41),seam);
 return mix(face,vec3(0.91,0.83,0.66),1.0-smoothstep(0.11,0.12,uv.y));
}
float window_distance(vec2 p, bool arch) {
 if (!arch) return max(abs(p.x)-0.20,abs(p.y)-0.24);
 float d=max(abs(p.x)-0.20,p.y-0.24);
 if (p.y < -0.10) d=max(d,length(vec2(p.x,p.y+0.10))-0.20);
 return d;
}
vec3 facade(vec2 uv, bool arch) {
 vec3 color=arch?masonry(uv,false):vec3(0.77,0.61,0.36);
 if (!arch && uv.y>0.78) color=blocks(uv,vec2(8.0,10.0),vec3(0.54,0.54,0.45),vec3(0.65,0.64,0.53),vec3(0.43,0.43,0.35),0.025);
 vec2 p=vec2(fract(uv.x*2.0)-0.5,uv.y-0.44);
 float d=window_distance(p,arch);
 float aa=max(length(fwidth(p)),0.001);
 color=mix(color,vec3(0.86,0.77,0.58),1.0-smoothstep(0.035,0.035+aa,d));
 color=mix(color,vec3(0.20,0.34,0.32),1.0-smoothstep(0.0,aa,d));
 if (d < -0.012) {
  float bars=arch?line_mask(abs(p.x),0.010,aa):max(line_mask(abs(p.x),0.012,aa),line_mask(edge_distance((p.y+0.24)*16.0),0.065,aa*16.0));
  color=mix(color,vec3(0.30,0.44,0.39),bars);
 }
 float sill=max(abs(p.x)-0.245,abs(p.y-0.265)-0.018);
 return mix(color,vec3(0.88,0.79,0.61),1.0-smoothstep(0.0,aa,sill));
}
void fragment() {
 vec3 color=vec3(0.5);
 if(item==1)color=paving(UV,option==1);
 else if(item==2)color=lawn(UV,option==1);
 else if(item==3)color=masonry(UV,option==1);
 else if(item==4)color=trim(UV,option==1,false);
 else if(item==5)color=roof(UV,option==1);
 else if(item==6)color=trim(UV,false,option==1);
 else if(item==7)color=ramp(UV,option==1);
 else if(item==8)color=railing(UV,option==1);
 else if(item==9)color=facade(UV,option==1);
 COLOR=vec4(color,1.0);
}
