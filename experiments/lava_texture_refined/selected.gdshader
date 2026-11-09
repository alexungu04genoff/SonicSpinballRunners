shader_type canvas_item;
render_mode unshaded;
// Selected Phase 2 albedos. The output folder is never a runtime material source.
uniform int item = 2;
uniform sampler2D current_floor : filter_linear, repeat_enable;
const vec3 JOINT = vec3(0.17, 0.12, 0.24);
const vec3 VIOLET = vec3(0.43, 0.38, 0.56);
const vec3 PALE_VIOLET = vec3(0.58, 0.51, 0.70);
const vec3 STEEL_EDGE = vec3(0.31, 0.26, 0.43);
const vec3 BRASS = vec3(0.72, 0.48, 0.23);
const vec3 BRASS_FACE = vec3(0.85, 0.64, 0.32);
const vec3 BRASS_EDGE = vec3(0.49, 0.30, 0.19);

float hash(vec2 p) {
 // Integer lattice hash keeps the same period on every renderer.
 uvec2 q = uvec2(ivec2(p));
 uint n = q.x * 1597334677u ^ q.y * 3812015801u;
 n = (n ^ (n >> 16u)) * 2246822519u;
 return float(n & 0x00ffffffu) / 16777215.0;
}
float fill(float d) {
 float aa = max(fwidth(d) * 0.65, 0.00035);
 return 1.0 - smoothstep(-aa, aa, d);
}
float box(vec2 p, vec2 size) { return fill(max(abs(p.x)-size.x, abs(p.y)-size.y)); }
float band(float p, float width) { return fill(abs(p)-width); }
float octagon(vec2 p, vec2 size, float corner) {
 vec2 a = abs(p);
 return fill(max(max(a.x-size.x, a.y-size.y), (a.x+a.y-size.x-size.y+corner)*0.70710678));
}
float disk(vec2 p, float radius) { return fill(length(p)-radius); }
float triangle_wave(float p) { return abs(fract(p)*2.0-1.0); }

vec3 fastener(vec3 c, vec2 p, float radius) {
 c = mix(c, BRASS_EDGE, disk(p, radius));
 c = mix(c, BRASS_FACE, disk(p, radius*0.69));
 return mix(c, BRASS, band(p.x, radius*0.12)*disk(p, radius*0.43));
}

vec3 floor_current_quiet(vec2 uv) {
 vec3 original = texture(current_floor, uv).rgb;
 // Explicit user exception for 1C: preserve the live image's geometry and seams.
 // Contract stone-face value variation by 12%; do not blur or alter joint pixels.
 float stone = smoothstep(0.018, 0.065, original.g-original.b);
 vec3 quiet = mix(original, vec3(0.51,0.35,0.23), 0.12);
 return mix(original, quiet, stone);
}

vec3 pipe_body(float cross_axis) {
 float edge = abs(cross_axis);
 vec3 c = JOINT;
 c = mix(c, STEEL_EDGE, band(cross_axis, 0.47));
 c = mix(c, VIOLET, band(cross_axis, 0.40));
 c = mix(c, PALE_VIOLET*0.95, band(cross_axis, 0.30));
 c = mix(c, vec3(0.43,0.42,0.55), band(cross_axis, 0.17));
 // Broad symmetric alloy bands indicate the pipe profile without a painted light.
 return mix(c, PALE_VIOLET, band(edge-0.345, 0.012));
}

vec3 pipe_coping(vec2 uv) {
 vec2 q = vec2(fract(uv.x*2.0), uv.y)-0.5;
 vec3 c = pipe_body(q.y);
 float collar = abs(q.x);
 c = mix(c, JOINT, band(collar-0.44, 0.055));
 c = mix(c, BRASS_EDGE, band(collar-0.44, 0.045));
 c = mix(c, BRASS, band(collar-0.44, 0.034));
 c = mix(c, BRASS_FACE, band(collar-0.44, 0.021));
 c = fastener(c, vec2((collar-0.44)*4.0, abs(q.y)-0.29), 0.045);
 return c;
}

vec3 twin_conduit_crown(vec2 uv) {
 // Reworked 6B: paired upper conduits, a recessed spine, and one broad saddle.
 vec2 q = vec2(fract(uv.x), uv.y)-0.5;
 vec3 c = JOINT;
 float tube_axis = (abs(q.y)-0.245)*2.05;
 c = mix(c, pipe_body(tube_axis), band(tube_axis, 0.48));
 c = mix(c, STEEL_EDGE, band(q.y, 0.060));
 c = mix(c, vec3(0.23,0.20,0.33), band(q.y, 0.030));
 float saddle = octagon(q, vec2(0.090,0.48), 0.045);
 c = mix(c, BRASS_EDGE, saddle);
 c = mix(c, BRASS, octagon(q, vec2(0.076,0.465), 0.042));
 c = mix(c, BRASS_FACE, octagon(q, vec2(0.058,0.43), 0.036));
 c = mix(c, BRASS, box(q, vec2(0.058,0.075)));
 c = fastener(c, vec2(q.x*4.0, abs(q.y)-0.30), 0.050);
 return c;
}

float column_site(float id, float y) {
 float wrapped = mod(id,8.0);
 float tone = hash(vec2(wrapped,11.0));
 float phase = hash(vec2(wrapped,31.0));
 return id+0.5+(tone-0.5)*0.22+(triangle_wave(y*2.0+phase)-0.5)*0.17;
}

vec3 basalt_columns(vec2 uv) {
 float x = uv.x*8.0;
 float base = floor(x);
 float best = 100.0;
 float id = base;
 float site = 0.0;
 for(int index=-1;index<=1;index++) {
  float candidate = base+float(index);
  float position = column_site(candidate,uv.y);
  float distance = abs(position-x);
  if(distance<best) { best=distance; id=candidate; site=position; }
 }
 float left = (column_site(id-1.0,uv.y)+site)*0.5;
 float right = (column_site(id+1.0,uv.y)+site)*0.5;
 float horizontal = (x-left)/(right-left);
 float wrapped = mod(id,8.0);
 float tone = hash(vec2(wrapped,41.0));
 float vertical = uv.y*2.0+hash(vec2(wrapped,15.0))+horizontal*(tone-0.5)*0.22;
 vec2 q = vec2(horizontal,fract(vertical));
 float row = mod(floor(vertical),2.0);
 float cell_tone = hash(vec2(wrapped,row+27.0));
 vec3 c = mix(vec3(0.27,0.21,0.36),vec3(0.38,0.29,0.44),tone*0.7+cell_tone*0.3);
 float plane = floor(clamp(1.0-abs(horizontal*2.0-1.0),0.0,0.999)*3.0)/2.0;
 c *= 0.84+plane*0.17;
 // Large planes and one restrained inclusion per occasional column cell.
 float vertical_edge = min(q.x,1.0-q.x);
 float cross_edge = min(q.y,1.0-q.y);
 c = mix(STEEL_EDGE*0.78,c,smoothstep(0.025,0.065,vertical_edge));
 c = mix(JOINT*0.72,c,smoothstep(0.004,0.014,vertical_edge));
 c = mix(JOINT*0.79,c,smoothstep(0.006,0.018,cross_edge));
 vec2 ore = q-vec2(0.38+cell_tone*0.24,0.61);
 float lens = fill(abs(ore.x)*0.45+abs(ore.y)*2.8-0.12)*step(0.79,cell_tone);
 vec3 mineral = mix(BRASS,BRASS_FACE,step(0.0,ore.x+ore.y*0.8));
 return mix(c,mineral,lens);
}

vec3 service_panels(vec2 uv) {
 vec2 p=uv*vec2(2.0,4.0), q=fract(p)-0.5;
 vec2 id=mod(floor(p),vec2(2.0,4.0));
 float tone=hash(id+23.0);
 vec3 face=mix(vec3(0.34,0.30,0.44),vec3(0.39,0.35,0.48),tone);
 vec3 c=JOINT;
 c=mix(c,STEEL_EDGE,octagon(q,vec2(0.486,0.47),0.025));
 c=mix(c,VIOLET*0.98,octagon(q,vec2(0.468,0.448),0.027));
 c=mix(c,face,octagon(q,vec2(0.445,0.420),0.032));
 c=mix(c,JOINT*0.91,octagon(q,vec2(0.364,0.286),0.072));
 c=mix(c,PALE_VIOLET*0.81,octagon(q,vec2(0.345,0.267),0.066));
 c=mix(c,face*0.97,octagon(q,vec2(0.323,0.245),0.060));
 float transverse=min(abs(q.y-0.47),abs(q.y+0.47));
 c=mix(c,BRASS_EDGE,band(transverse,0.024));
 c=mix(c,BRASS_FACE,band(transverse,0.013));
 // Fasteners have the same physical radius in the module's two axes.
 c=fastener(c,vec2(abs(q.x)-0.385,(abs(q.y)-0.353)*0.5),0.025);
 return c;
}

vec3 basalt_causeway(vec2 uv) {
 vec2 p=uv*vec2(3.0,4.0);
 float row=floor(p.y);
 p.x+=mod(row,2.0)*0.5;
 vec2 id=mod(floor(p),vec2(3.0,4.0)), q=fract(p)-0.5;
 float tone=hash(id+71.0);
 vec3 face=mix(vec3(0.28,0.24,0.34),vec3(0.36,0.30,0.40),tone);
 vec3 c=JOINT*0.93;
 c=mix(c,STEEL_EDGE*0.88,octagon(q,vec2(0.487,0.481),0.024));
 c=mix(c,face*0.90,octagon(q,vec2(0.472,0.461),0.025));
 c=mix(c,face,octagon(q,vec2(0.449,0.435),0.028));
 float broad_plane=step(0.15+tone*0.1,q.x*0.65+q.y*0.85);
 c=mix(c,c*1.035,broad_plane*octagon(q,vec2(0.449,0.435),0.028));
 float vein=band(q.y-q.x*0.18-0.19,0.007)*step(0.79,tone);
 return mix(c,face*1.045,vein*octagon(q,vec2(0.42,0.40),0.028));
}

vec3 box_girder(vec2 uv) {
 vec2 q=vec2(fract(uv.x*2.0),uv.y)-0.5;
 // Two complete bays; plate thickness and circular fasteners share a 2:1 aspect.
 vec3 c=mix(JOINT,vec3(0.26,0.21,0.34),box(q,vec2(0.48,0.46)));
 float flange=max(band(abs(q.y)-0.435,0.065),band(abs(q.x)-0.445,0.055));
 float diagonal=q.y+q.x*0.72;
 float brace=band(diagonal,0.075)*box(q,vec2(0.44,0.43));
 c=mix(c,BRASS_EDGE,max(flange,brace));
 float flange_face=max(band(abs(q.y)-0.435,0.037),band(abs(q.x)-0.445,0.032));
 float brace_face=band(diagonal,0.046)*box(q,vec2(0.44,0.43));
 c=mix(c,BRASS,max(flange_face,brace_face));
 c=mix(c,BRASS_FACE,max(band(abs(q.y)-0.435,0.014),band(abs(q.x)-0.445,0.012))*0.7);
 vec2 plate=abs(q)-vec2(0.445,0.435);
 c=mix(c,BRASS_EDGE,octagon(plate,vec2(0.075,0.095),0.028));
 c=mix(c,BRASS_FACE,octagon(plate,vec2(0.061,0.077),0.026));
 return fastener(c,plate*vec2(2.0,1.0),0.030);
}

vec3 retaining_bays(vec2 uv) {
 vec3 c=basalt_columns(uv);
 vec2 q=vec2(fract(uv.x*2.0),uv.y)-0.5;
 // Every half-texture is a complete square retaining bay with full corner plates.
 float perimeter=min(0.5-abs(q.x),0.5-abs(q.y));
 c=mix(c,JOINT,1.0-smoothstep(0.090,0.098,perimeter));
 c=mix(c,STEEL_EDGE,1.0-smoothstep(0.072,0.080,perimeter));
 c=mix(c,VIOLET,1.0-smoothstep(0.046,0.058,perimeter));
 c=mix(c,PALE_VIOLET*0.91,band(perimeter-0.028,0.009));
 c=mix(c,STEEL_EDGE,1.0-smoothstep(0.010,0.018,perimeter));
 vec2 corner=abs(q)-vec2(0.439);
 c=mix(c,BRASS_EDGE,octagon(corner,vec2(0.060),0.019));
 c=mix(c,BRASS,octagon(corner,vec2(0.049),0.016));
 c=mix(c,BRASS_FACE,octagon(corner,vec2(0.036),0.013));
 c=fastener(c,corner,0.018);
 return c;
}

void fragment() {
 vec3 c=vec3(0.0);
 if(item==1) c=floor_current_quiet(UV);
 else if(item==2) c=pipe_coping(UV);
 else if(item==3) c=basalt_columns(UV);
 else if(item==5) c=service_panels(UV);
 else if(item==6) c=twin_conduit_crown(UV);
 else if(item==7) c=basalt_causeway(UV);
 else if(item==8) c=box_girder(UV);
 else if(item==9) c=retaining_bays(UV);
 COLOR=vec4(c,1.0);
}
