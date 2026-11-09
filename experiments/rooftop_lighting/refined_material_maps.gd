extends RefCounted
## Session-only material maps, sharing the approved color textures' coordinates.
const ROOT := "res://experiments/rooftop_lighting/texture-procedural-refined/"
const IDS := {"floor":"1A", "floor-border":"2A", "wall":"3C", "top":"5A", "top-border":"6C", "ramp":"7B", "guard":"8B", "facade":"9B"}
const STRENGTH := {"floor":0.65, "floor-border":0.25, "wall":0.45, "top":0.85, "top-border":0.65, "ramp":0.55, "guard":0.35, "facade":0.40}
var textures := {}
var materials: Array[ShaderMaterial] = []
var enabled := true
var strength := 1.0
var ao_strength := 0.45

func solid_stone(original: StandardMaterial3D, size: Vector3, amount: float) -> ShaderMaterial:
 var material:=ShaderMaterial.new()
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode cull_disabled;
#include "res://experiments/rooftop_lighting/scene_normal.gdshaderinc"
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
 material.set_shader_parameter("box_size",size)
 if not textures.has("solid_block"):
  var image:=Image.load_from_file("res://experiments/rooftop_lighting/scene_maps/block_beveled_normal.png")
  image.generate_mipmaps()
  textures.solid_block=ImageTexture.create_from_image(image)
 material.set_shader_parameter("relief_normal",textures.solid_block)
 material.set_meta("normal_strength",amount)
 materials.append(material)
 update()
 return material

func texture(id: String, suffix: String) -> Texture2D:
 var key := id + "_" + suffix
 if not textures.has(key):
  var image := Image.load_from_file(ROOT + key + ".png")
  image.generate_mipmaps()
  textures[key] = ImageTexture.create_from_image(image)
 return textures[key]

func apply(material: ShaderMaterial, role: String, mapping: String) -> ShaderMaterial:
 if not IDS.has(role): return material
 var code: String = material.shader.code.replace(", specular_disabled", "")
 var helpers := """
#include "res://experiments/rooftop_lighting/scene_normal.gdshaderinc"
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
 materials.append(material)
 update()
 return material

func update() -> void:
 for material in materials:
  material.set_shader_parameter("relief_strength",float(material.get_meta("normal_strength"))*strength if enabled else 0.0)
  material.set_shader_parameter("detail_mix",1.0 if enabled else 0.0)
  material.set_shader_parameter("cavity_strength",ao_strength)
