shader_type spatial;
#include "res://scripts/atmosphere/hue.gdshaderinc"
#include "res://scripts/themes/rooftop_normal.gdshaderinc"
render_mode cull_disabled;
// Canonical structural response shares the approved albedo coordinates.
// No inherited terrain emission maps or parallax are used.
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cavity_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool cavity_enabled=false;
uniform float detail_mix : hint_range(0.0,1.0)=1.0;
uniform bool visual_relief=false;
uniform float geometry_strength : hint_range(0.0,1.5)=0.0;
uniform float recess_depth=0.0;
// 0: world floor, 1: projected wall/facade, 2: contour band, 3: route deck,
// 6: route guard. Existing strip UVs encode distance divided by 0.48.
uniform int mapping = 0;
uniform vec2 repeat_size = vec2(1.0);
uniform float top_height = 0.325;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 if(visual_relief) {
  VERTEX.y+=UV2.x*(geometry_strength-1.0);
  NORMAL=normalize(vec3(NORMAL.x*geometry_strength,NORMAL.y,NORMAL.z*geometry_strength));
 }
 VERTEX.y-=recess_depth*geometry_strength*detail_mix;
 world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
vec3 sample_surface(vec2 uv, bool clamp_y) {
 vec2 dx=dFdx(uv), dy=dFdy(uv);
 if(clamp_y) uv.y=clamp(uv.y,0.002,0.998);
 return textureGrad(albedo_texture,uv,dx,dy).rgb;
}
void fragment() {
 if(visual_relief && (detail_mix<0.5 || geometry_strength<0.001))discard;
 vec2 uv=(mapping==0 ? world_position.xz : UV)/repeat_size;
 if(mapping==2 || mapping==6) uv=vec2(UV.x*0.48/repeat_size.x,UV.y);
 vec3 color;
 float roughness;
 float cavity=1.0;
 vec3 geometric=NORMAL;
 if(mapping==1) {
  float depth=top_height-world_position.y;
  vec2 weights=pow(abs(world_normal.xz),vec2(6.0));
  weights/=max(weights.x+weights.y,0.001);
  color=sample_surface(vec2(world_position.z,depth)/repeat_size,true)*weights.x;
  color+=sample_surface(vec2(world_position.x,depth)/repeat_size,true)*weights.y;
  vec2 a=vec2(world_position.z,depth)/repeat_size;
  vec2 b=vec2(world_position.x,depth)/repeat_size;
  vec2 sa=vec2(a.x,clamp(a.y,0.002,0.998));
  vec2 sb=vec2(b.x,clamp(b.y,0.002,0.998));
  NORMAL=normalize(relief(VERTEX,geometric,a,sa)*weights.x+relief(VERTEX,geometric,b,sb)*weights.y);
  roughness=textureGrad(roughness_map,sa,dFdx(a),dFdy(a)).r*weights.x;
  roughness+=textureGrad(roughness_map,sb,dFdx(b),dFdy(b)).r*weights.y;
 } else {
  color=sample_surface(uv,mapping==2 || mapping==6);
  vec2 sample_uv=uv;
  if(mapping==2 || mapping==6)sample_uv.y=clamp(sample_uv.y,0.002,0.998);
  NORMAL=relief(VERTEX,geometric,uv,sample_uv);
  roughness=textureGrad(roughness_map,sample_uv,dFdx(uv),dFdy(uv)).r;
  if(cavity_enabled)cavity=textureGrad(cavity_map,sample_uv,dFdx(uv),dFdy(uv)).r;
 }
 ALBEDO=atmosphere_shift(color);
 ROUGHNESS=mix(0.9,roughness,detail_mix);
 AO=mix(1.0,cavity,detail_mix);
 AO_LIGHT_AFFECT=0.0;
 SPECULAR=0.2;
}
