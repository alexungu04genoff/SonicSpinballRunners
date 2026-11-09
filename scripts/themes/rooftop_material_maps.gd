extends RefCounted
## Approved Rooftop Run materials. Color and relief share structural coordinates.
const ROOT := "res://assets/textures/rooftop_run/approved/"
const IDS := {"floor":"1A", "floor-border":"2A", "wall":"3C", "top":"5A", "top-border":"6C", "ramp":"7B", "guard":"8B", "facade":"9B", "foliage":"foliage"}
const STRENGTH := {"floor":0.65, "floor-border":1.50, "wall":0.45, "top":0.85, "top-border":0.65, "ramp":0.55, "guard":0.35, "facade":0.40, "foliage":0.65}
var textures := {}
var materials: Array[ShaderMaterial] = []
var enabled := true
var strength := 1.0
var ao_strength := 0.45
var special_materials := {}
var grass_height := 0.075
const GRASS_LAYERS := 10

func grass_shells() -> Array[ShaderMaterial]:
 if special_materials.has("grass_shells"): return special_materials.grass_shells
 var shells: Array[ShaderMaterial]=[]
 for layer in GRASS_LAYERS:
  var fraction:=float(layer+1)/float(GRASS_LAYERS+1)
  var material:=ShaderMaterial.new()
  var shader:=Shader.new()
  shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform sampler2D border_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D height_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float shell_height=0.01;
uniform float shell_fraction=0.1;
void vertex() {
 VERTEX.y+=shell_height;
}
void fragment() {
 vec2 uv=vec2(UV.x*1.5,UV.y*0.375);
 float height=clamp((texture(height_texture,uv).r-0.15)/0.65,0.0,1.0);
 ALPHA=step(shell_fraction,height);
 ALPHA_SCISSOR_THRESHOLD=0.5;
 ALBEDO=texture(border_texture,uv).rgb*mix(0.78,1.08,shell_fraction);
 ROUGHNESS=0.96;
}
"""
  material.shader=shader
  material.set_shader_parameter("border_texture",texture("2A",""))
  material.set_shader_parameter("height_texture",texture("2A","height"))
  material.set_shader_parameter("shell_height",grass_height*fraction)
  material.set_shader_parameter("shell_fraction",fraction)
  material=apply(material,"floor-border","border_texture")
  material.set_meta("grass_shell_fraction",fraction)
  shells.append(material)
 special_materials.grass_shells=shells
 return shells

func set_grass_height(value: float) -> void:
 grass_height=value
 if special_materials.has("grass_shells"):
  for material: ShaderMaterial in special_materials.grass_shells:
   material.set_shader_parameter("shell_height",grass_height*float(material.get_meta("grass_shell_fraction")))

func guard() -> ShaderMaterial:
 if special_materials.has("guard"): return special_materials.guard
 var material:=ShaderMaterial.new()
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform sampler2D color_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 route_uv;
void vertex() {
 int corner=VERTEX_ID % 6;
 float across=(corner==2 || corner==3 || corner==5) ? 1.0:0.0;
 route_uv=vec2(UV.y/0.55,1.0-across);
}
void fragment() {
 ALBEDO=texture(color_texture,vec2(route_uv.x,clamp(route_uv.y,0.0,1.0))).rgb;
 ROUGHNESS=0.85;
}
"""
 material.shader=shader
 material.set_shader_parameter("color_texture",texture("8B",""))
 special_materials.guard=apply(material,"guard","guard")
 return special_materials.guard

func foliage(original: StandardMaterial3D) -> ShaderMaterial:
 var key:=str(original.get_instance_id())+"/foliage"
 if special_materials.has(key): return special_materials[key]
 var material:=ShaderMaterial.new()
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/themes/rooftop_normal.gdshaderinc"
uniform sampler2D color_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color=vec4(1.0);
uniform float detail_mix=1.0;
uniform float cavity_strength=0.45;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec3 weights=pow(abs(world_normal),vec3(6.0));
 weights/=max(weights.x+weights.y+weights.z,0.001);
 vec3 p=world_position/0.65;
 vec3 color=texture(color_texture,p.zy).rgb*weights.x+texture(color_texture,p.xz).rgb*weights.y+texture(color_texture,p.xy).rgb*weights.z;
 ALBEDO=clamp(color*tint.rgb/vec3(0.27,0.52,0.21),vec3(0.0),vec3(1.0));
 vec3 nx=relief(VERTEX,NORMAL,p.zy,p.zy), ny=relief(VERTEX,NORMAL,p.xz,p.xz), nz=relief(VERTEX,NORMAL,p.xy,p.xy);
 NORMAL=normalize(nx*weights.x+ny*weights.y+nz*weights.z);
 ROUGHNESS=0.96;
 SPECULAR=0.15;
}
"""
 material.shader=shader
 material.set_shader_parameter("color_texture",texture("foliage",""))
 material.set_shader_parameter("relief_normal",texture("foliage","normal"))
 material.set_shader_parameter("tint",original.albedo_color)
 preload("res://scripts/themes/theme_atmosphere.gd").tag(material, "tint", "vegetation_tint", "tint", {"shader": true})
 material.set_meta("normal_strength",0.65)
 material.set_meta("approved_rooftop",true)
 materials.append(material)
 special_materials[key]=material
 update()
 return material

func solid_stone(original: StandardMaterial3D, size: Vector3, amount: float) -> ShaderMaterial:
 var material:=ShaderMaterial.new()
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/themes/rooftop_normal.gdshaderinc"
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec3 box_size = vec3(1.0);
uniform float detail_mix = 1.0;
uniform float cavity_strength = 0.45;
varying vec2 face_uv;
void vertex() {
 vec3 p=VERTEX/box_size;
 vec3 n=abs(NORMAL);
 face_uv=(n.x>0.5 ? p.zy : (n.y>0.5 ? p.xz : p.xy))+vec2(0.5);
}
void fragment() {
 ALBEDO=base_color.rgb;
 ROUGHNESS=0.88;
 SPECULAR=0.22;
 NORMAL=relief(VERTEX,NORMAL,face_uv,clamp(face_uv,vec2(0.002),vec2(0.998)));
}
"""
 material.shader=shader
 material.set_shader_parameter("base_color",original.albedo_color)
 preload("res://scripts/themes/theme_atmosphere.gd").tag(material, "base_color", "architecture_tint", "tint", {"shader": true})
 material.set_shader_parameter("box_size",size)
 if not textures.has("solid_block"):
  textures.solid_block=texture("block","normal")
 material.set_shader_parameter("relief_normal",textures.solid_block)
 material.set_meta("normal_strength",amount)
 material.set_meta("approved_rooftop",true)
 materials.append(material)
 update()
 return material

func texture(id: String, suffix: String) -> Texture2D:
 var key := id + ("_" + suffix if not suffix.is_empty() else "")
 if not OS.has_feature("editor"):
  return load(ROOT + key + ".png")
 if not textures.has(key):
  var image := Image.load_from_file(ProjectSettings.globalize_path(ROOT + key + ".png"))
  image.generate_mipmaps()
  textures[key] = ImageTexture.create_from_image(image)
 return textures[key]

func apply(material: ShaderMaterial, role: String, mapping: String) -> ShaderMaterial:
 if not IDS.has(role): return material
 var code: String = material.shader.code.replace(", specular_disabled", "")
 var helpers := """
#include "res://scripts/themes/rooftop_normal.gdshaderinc"
uniform sampler2D roughness_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cavity_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_mix = 1.0;
uniform float cavity_strength = 0.45;
vec3 material_properties(vec2 uv, vec2 sample_uv) {
 vec2 dx=dFdx(uv), dy=dFdy(uv);
 return vec3(textureGrad(roughness_map,sample_uv,dx,dy).r,
 textureGrad(cavity_map,sample_uv,dx,dy).r,
 textureGrad(metallic_map,sample_uv,dx,dy).r);
}
"""
 code = code.replace("void fragment() {", helpers + "\nvoid fragment() {")
 var assignment := ""
 if mapping == "wall_texture":
  var size := "vec2(1.7,0.85)" if role=="facade" else "vec2(3.4,1.45)"
  assignment = """
 vec2 a=vec2(world_position.z,depth)/%s;
 vec2 b=vec2(world_position.x,depth)/%s;
 vec2 sa=vec2(fract(a.x),clamp(a.y,0.001,0.999));
 vec2 sb=vec2(fract(b.x),clamp(b.y,0.001,0.999));
 vec3 na=relief(VERTEX,NORMAL,a,sa), nb=relief(VERTEX,NORMAL,b,sb);
 NORMAL=normalize(na*weights.x+nb*weights.y);
 vec3 properties=material_properties(a,sa)*weights.x+material_properties(b,sb)*weights.y;
""" % [size,size]
 else:
  var coordinates := "coordinates / repeat_size"
  if mapping=="border_texture": coordinates="vec2(UV.x * 1.5, UV.y * 0.375)" if role=="floor-border" else "UV"
  elif mapping=="guard": coordinates="route_uv"
  assignment="\n vec2 detail_uv="+coordinates+";\n"
  assignment+=" vec2 sample_uv=detail_uv;\n"
  if role in ["top-border","guard"]: assignment+=" sample_uv.y=clamp(sample_uv.y,0.002,0.998);\n"
  assignment+=" NORMAL=relief(VERTEX,NORMAL,detail_uv,sample_uv);\n vec3 properties=material_properties(detail_uv,sample_uv);\n"
 assignment+="""
 ROUGHNESS=mix(ROUGHNESS,properties.x,detail_mix);
 SPECULAR=0.28;
 AO=mix(1.0,properties.y,cavity_strength*detail_mix);
 AO_LIGHT_AFFECT=0.0;
 METALLIC=properties.z*detail_mix;
"""
 code=code.insert(code.rfind("}"),assignment)
 var shader:=Shader.new()
 shader.code=code
 var source_parameters := {}
 for parameter in material.shader.get_shader_uniform_list():
  source_parameters[parameter.name]=material.get_shader_parameter(parameter.name)
 material.shader=shader
 for parameter in source_parameters:
  material.set_shader_parameter(parameter,source_parameters[parameter])
 material.set_shader_parameter("relief_normal",texture(IDS[role],"normal"))
 material.set_shader_parameter("roughness_map",texture(IDS[role],"roughness"))
 material.set_shader_parameter("cavity_map",texture(IDS[role],"ao"))
 material.set_shader_parameter("metallic_map",texture(IDS[role],"metallic"))
 material.set_meta("normal_strength",STRENGTH[role])
 material.set_meta("approved_rooftop",true)
 materials.append(material)
 update()
 return material

func update() -> void:
 for material in materials:
  material.set_shader_parameter("relief_strength",float(material.get_meta("normal_strength"))*strength if enabled else 0.0)
  material.set_shader_parameter("detail_mix",1.0 if enabled else 0.0)
  material.set_shader_parameter("cavity_strength",ao_strength)
