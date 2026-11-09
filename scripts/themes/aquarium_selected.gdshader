shader_type spatial;
#include "res://scripts/atmosphere/hue.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cap_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D relief_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D response_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cap_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cap_response : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float relief_strength : hint_range(0.0,2.0)=.65;
uniform float cap_strength : hint_range(0.0,2.0)=.60;
uniform float detail_mix : hint_range(0.0,1.0)=1.0;
// 0 world surface, 1 exterior projection, 2 contour border, 3 ramp deck,
// 5 contour wall, 6 route strip. All maps share these exact coordinates.
uniform int mapping=0;
uniform vec2 repeat_size=vec2(1.0);
uniform float top_height=.325;
uniform float cap_height=.065;
varying vec3 world_position;
varying vec3 world_normal;
varying vec2 strip_uv;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 // Authored rail strips supply path distance / .48 in U and full strip width in V.
 strip_uv=vec2(UV.x*.48/repeat_size.x,UV.y);
}
vec3 sample_surface(vec2 uv,bool clamp_y){
 vec2 dx=dFdx(uv),dy=dFdy(uv);
 if(clamp_y)uv.y=clamp(uv.y,.002,.998);
 return textureGrad(albedo_texture,uv,dx,dy).rgb;
}
vec2 sample_coordinates(vec2 uv,bool clamp_y){
 if(clamp_y)uv.y=clamp(uv.y,.002,.998);
 return uv;
}
vec3 mapped_normal(sampler2D map_texture,vec3 position,vec3 geometric,vec2 coordinates,vec2 sample_uv,float strength){
 // Same derivative-frame convention as rooftop_normal.gdshaderinc, with an
 // explicit sampler so the wall cap uses its own aligned structural map.
 vec3 n=normalize(geometric);
 vec3 dx=dFdx(position),dy=dFdy(position);
 vec2 sx=dFdx(coordinates),sy=dFdy(coordinates);
 float determinant=sx.x*sy.y-sx.y*sy.x;
 if(abs(determinant)<.00000001||strength==0.)return n;
 vec3 map=textureGrad(map_texture,sample_uv,sx,sy).xyz*2.-1.;
 map.z=sqrt(max(1.-dot(map.xy,map.xy),.001));
 vec3 t=(dx*sy.y-dy*sx.y)/determinant;
 vec3 b=(dy*sx.x-dx*sy.x)/determinant;
 t=normalize(t-n*dot(n,t));
 b=normalize(b-n*dot(n,b));
 // Image V runs down; OpenGL normal-map Y runs up.
 return normalize(n*map.z+(t*map.x-b*map.y)*strength);
}
void fragment(){
 vec2 uv=UV/repeat_size;
 if(mapping==0)uv=world_position.xz/repeat_size;
 if(mapping==3)uv=vec2(clamp(UV2.x,.002,.998),UV.y/repeat_size.y);
 if(mapping==5)uv=vec2(UV.x/repeat_size.x,(top_height-cap_height-world_position.y)/(top_height-cap_height));
 if(mapping==6)uv=strip_uv;
 vec3 color;
 vec2 response;
 vec3 geometric=NORMAL;
 if(mapping==1){
  float depth=top_height-world_position.y;
  vec2 weights=pow(abs(world_normal.xz),vec2(8.));
  weights/=max(weights.x+weights.y,.001);
  vec2 a=vec2(world_position.z,depth)/repeat_size,b=vec2(world_position.x,depth)/repeat_size;
  vec2 sa=sample_coordinates(a,true),sb=sample_coordinates(b,true);
  color=sample_surface(a,true)*weights.x+sample_surface(b,true)*weights.y;
  NORMAL=normalize(mapped_normal(relief_normal,VERTEX,geometric,a,sa,relief_strength)*weights.x+mapped_normal(relief_normal,VERTEX,geometric,b,sb,relief_strength)*weights.y);
  response=textureGrad(response_texture,sa,dFdx(a),dFdy(a)).rg*weights.x+textureGrad(response_texture,sb,dFdx(b),dFdy(b)).rg*weights.y;
 }else{
  bool clamped=mapping==2||mapping==5||mapping==6;
  vec2 sample_uv=sample_coordinates(uv,clamped);
  color=sample_surface(uv,clamped);
  NORMAL=mapped_normal(relief_normal,VERTEX,geometric,uv,sample_uv,relief_strength);
  response=textureGrad(response_texture,sample_uv,dFdx(uv),dFdy(uv)).rg;
 }
 if(mapping==5&&world_position.y>top_height-cap_height){
  vec2 cap_uv=vec2(UV.x/repeat_size.x,(top_height-world_position.y)/cap_height);
  vec2 sample_uv=sample_coordinates(cap_uv,true);
  color=textureGrad(cap_texture,sample_uv,dFdx(cap_uv),dFdy(cap_uv)).rgb;
  NORMAL=mapped_normal(cap_normal,VERTEX,geometric,cap_uv,sample_uv,cap_strength);
  response=textureGrad(cap_response,sample_uv,dFdx(cap_uv),dFdy(cap_uv)).rg;
 }
 ALBEDO=atmosphere_shift(color);
 ROUGHNESS=mix(.68,response.r,detail_mix);
 // Restrained metallic response keeps brass readable under the approved lighting.
 METALLIC=response.g*.25*detail_mix;
 SPECULAR=.25;
}
