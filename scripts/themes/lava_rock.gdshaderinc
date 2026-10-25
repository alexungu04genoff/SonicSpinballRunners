// Original beveled boulders: broad gold faces and purple interstices.
float reef_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
vec3 reef_boulder(vec2 p) {
 vec2 cell = floor(p), offset = vec2(0.0);
 float nearest = 8.0, second = 8.0, tone = 0.0;
 for (int y = -1; y <= 1; y++) {
  for (int x = -1; x <= 1; x++) {
   vec2 id = cell + vec2(float(x),float(y));
   vec2 site = id + 0.5 + (vec2(reef_hash(id),reef_hash(id+19.0))-0.5)*0.65;
   vec2 delta = p-site;
   float d = dot(delta,delta);
   if (d < nearest) { second = nearest; nearest = d; offset = delta; tone = reef_hash(id+41.0); }
   else { second = min(second,d); }
  }
 }
 float edge = second-nearest;
 float aa = max(fwidth(edge),0.006);
 // Clip cell corners into irregular octagons. Broad bevels are essential:
 // thin edge lines alone read as paving instead of the source's rounded rocks.
 float octagon = max(abs(offset.x)*0.85+abs(offset.y)*0.52,abs(offset.y)*0.85+abs(offset.x)*0.52);
 float silhouette = min(edge,0.68-octagon);
 float bevel = smoothstep(0.26-aa,0.26+aa,silhouette);
 float face = floor((atan(offset.y,offset.x)+3.14159)*0.95493);
 float light_face = 0.5+0.5*cos(face*1.0472+1.2);
 vec3 rim = mix(vec3(0.40,0.15,0.17),vec3(0.86,0.53,0.27),light_face);
 vec3 center = mix(vec3(0.88,0.65,0.32),vec3(1.0,0.86,0.48),tone);
 vec3 rock = mix(rim,center,bevel);
 return mix(vec3(0.18,0.065,0.29),rock,smoothstep(0.025,0.055+aa,silhouette));
}
