shader_type spatial;
#include "res://scripts/atmosphere/hue.gdshaderinc"
#include "res://scripts/themes/rooftop_normal.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// 0: broad floor, 1: exterior projection, 2: contour strip, 3: ramp, 5: contour wall.
uniform int mapping=0;
uniform vec2 repeat_size=vec2(1.0);
uniform float top_height=0.325;
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_mix : hint_range(0.0,1.0)=1.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
vec3 sample_surface(vec2 uv,bool clamp_vertical){
 vec2 dx=dFdx(uv),dy=dFdy(uv);
 if(clamp_vertical)uv.y=clamp(uv.y,.002,.998);
 return textureGrad(albedo_texture,uv,dx,dy).rgb;
}
vec2 sample_coordinates(vec2 uv,bool clamp_vertical){
 if(clamp_vertical)uv.y=clamp(uv.y,.002,.998);
 return uv;
}
float surface_roughness(vec2 uv,vec2 sample_uv){
 return textureGrad(roughness_map,sample_uv,dFdx(uv),dFdy(uv)).r;
}
void fragment(){
 vec2 uv=UV/repeat_size;
 if(mapping==0)uv=world_position.xz/repeat_size;
 if(mapping==3)uv=vec2(clamp(UV2.x,.002,.998),UV.y/repeat_size.y);
 if(mapping==5)uv=vec2(UV.x/repeat_size.x,(top_height-world_position.y)/repeat_size.y);
 vec3 color;
 float roughness;
 vec3 geometric=NORMAL;
 if(mapping==1){
  float depth=top_height-world_position.y;
  vec2 weights=pow(abs(world_normal.xz),vec2(8.0));
  weights/=max(weights.x+weights.y,.001);
  color=sample_surface(vec2(world_position.z,depth)/repeat_size,true)*weights.x;
  color+=sample_surface(vec2(world_position.x,depth)/repeat_size,true)*weights.y;
  vec2 a=vec2(world_position.z,depth)/repeat_size;
  vec2 b=vec2(world_position.x,depth)/repeat_size;
  vec2 sa=sample_coordinates(a,true),sb=sample_coordinates(b,true);
  NORMAL=normalize(relief(VERTEX,geometric,a,sa)*weights.x+relief(VERTEX,geometric,b,sb)*weights.y);
  roughness=surface_roughness(a,sa)*weights.x+surface_roughness(b,sb)*weights.y;
 }else{
  bool clamped=mapping==2||mapping==5;
  color=sample_surface(uv,clamped);
  vec2 sample_uv=sample_coordinates(uv,clamped);
  NORMAL=relief(VERTEX,geometric,uv,sample_uv);
  roughness=surface_roughness(uv,sample_uv);
 }
 ALBEDO=atmosphere_shift(color);
 ROUGHNESS=mix(.75,roughness,detail_mix);
 SPECULAR=.22;
}
