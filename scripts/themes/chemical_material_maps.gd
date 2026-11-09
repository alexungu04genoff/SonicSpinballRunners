extends RefCounted
## Structural maps share each surface's albedo coordinates. No parallax or displacement.
const ROOT := "res://assets/textures/chemical_plant/selected/"
const STRENGTH := {"1C":0.65,"2A":0.30,"3C":0.45,"5A":0.65,"6B":0.40,"7C-yellow":0.55,"8B":0.30,"9C":0.40}
var strength := 1.0
var enabled := true
var neon_strength := 1.5
var neon_spread := 1.5
var floor_neon_spread := 2.7
var textures := {}

func texture(id: String, suffix: String) -> Texture2D:
 var key := id+"_"+suffix
 if textures.has(key): return textures[key]
 var path := ROOT+key+".png"
 if OS.has_feature("editor"):
  var image := Image.load_from_file(ProjectSettings.globalize_path(path))
  image.generate_mipmaps()
  textures[key] = ImageTexture.create_from_image(image)
 else:
  textures[key] = load(path)
 return textures[key]

func apply(material: ShaderMaterial, id: String, terrain := false) -> ShaderMaterial:
 var code: String = material.shader.code
 var helper := """
#include "res://scripts/themes/rooftop_normal.gdshaderinc"
uniform sampler2D detail_roughness : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D detail_ao : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D detail_metallic : filter_linear_mipmap_anisotropic, repeat_disable;
uniform float detail_mix = 1.0;
vec3 detail_properties(vec2 uv,vec2 wrapped) {
 vec2 dx=dFdx(uv),dy=dFdy(uv);
 return vec3(textureGrad(detail_roughness,wrapped,dx,dy).r,textureGrad(detail_ao,wrapped,dx,dy).r,textureGrad(detail_metallic,wrapped,dx,dy).r);
}
"""
 if id in ["1C","3C"]:
  helper += "\nuniform float neon_strength : hint_range(0.0, 3.0) = 1.5;\nuniform float neon_spread : hint_range(0.1, 3.0) = 1.5;\nuniform float floor_neon_spread : hint_range(0.1, 4.0) = 2.7;\n"
 code=code.replace("void fragment() {",helper+"\nvoid fragment() {")
 var detail := ""
 if terrain:
  detail="""
 vec3 dp;
 if(mapping==1) {
  vec2 a=vec2(world_position.z,top_height-world_position.y)/repeat_size;
  vec2 b=vec2(world_position.x,top_height-world_position.y)/repeat_size;
  vec2 sa=vec2(fract(a.x),clamp(a.y,0.001,0.999));
  vec2 sb=vec2(fract(b.x),clamp(b.y,0.001,0.999));
  vec2 weights=pow(abs(world_normal.xz),vec2(normal_power));
  weights/=max(weights.x+weights.y,.001);
  NORMAL=normalize(relief(VERTEX,NORMAL,a,sa)*weights.x+relief(VERTEX,NORMAL,b,sb)*weights.y);
  dp=detail_properties(a,sa)*weights.x+detail_properties(b,sb)*weights.y;
 } else {
  NORMAL=relief(VERTEX,NORMAL,uv,fract(uv));
  dp=detail_properties(uv,fract(uv));
 }
"""
 else:
  detail="\n NORMAL=relief(VERTEX,NORMAL,uv,wrapped);\n vec3 dp=detail_properties(uv,wrapped);\n"
 detail+="""
 ROUGHNESS=mix(ROUGHNESS,dp.x,detail_mix);
 METALLIC=mix(METALLIC,dp.z,detail_mix);
 SPECULAR=mix(SPECULAR,.30,detail_mix);
 AO=mix(1.0,dp.y,detail_mix*.65);
 AO_LIGHT_AFFECT=0.0;
"""
 if id=="1C":
  detail+="""
 // The original floor uses six panels per three-world-unit texture repeat.
 // Alternate lamp colour by physical panel, without recolouring the panel itself.
 vec2 lamp_grid=world_position.xz*2.0;
 vec2 lamp_q=fract(lamp_grid);
 float lamp_mask=(1.0-smoothstep(.022,.030286,abs(lamp_q.y-.10)))*step(.12,lamp_q.x)*step(lamp_q.x,.36);
 float lamp_alternate=mod(floor(lamp_grid.x)+floor(lamp_grid.y),2.0);
 vec3 lamp_color=mix(vec3(.015,.45,1.0),vec3(1.0,.60,.015),lamp_alternate);
 ALBEDO=mix(ALBEDO,lamp_color,lamp_mask);
 // Soft surface spill around the original rectangles. Neighbor cells prevent
 // glow being clipped or changing hue at panel boundaries.
 vec3 lamp_halo=vec3(0.0);
 float lamp_radius=.085*floor_neon_spread;
 for(int y=-1;y<=1;y++) {
  for(int x=-1;x<=1;x++) {
   vec2 cell=floor(lamp_grid)+vec2(float(x),float(y));
   vec2 distance_to_rect=max(abs(lamp_grid-cell-vec2(.24,.10))-vec2(.12,.026),vec2(0.0));
   float falloff=exp(-dot(distance_to_rect,distance_to_rect)*2.0/(lamp_radius*lamp_radius));
   vec3 halo_color=mix(vec3(.015,.45,1.0),vec3(1.0,.60,.015),mod(cell.x+cell.y,2.0));
   lamp_halo+=halo_color*falloff;
  }
 }
 EMISSION=(lamp_color*lamp_mask*2.0+lamp_halo*.65)*neon_strength;
"""
 elif id=="3C":
  detail+="""
 // Match only the existing cyan ledge strip; hazard paint and green wall indicators remain intact.
 float neon_depth=top_height-world_position.y;
 float neon_rim=1.0-smoothstep(.014,.024,abs(neon_depth-.012));
 float rim_distance=max(abs(neon_depth-.012)-.024,0.0);
 float rim_radius=.045*neon_spread;
 float rim_halo=exp(-rim_distance*rim_distance*2.0/(rim_radius*rim_radius));
 EMISSION+=vec3(.015,.55,1.0)*(neon_rim*2.5+rim_halo*.70)*neon_strength;
"""
 code=code.insert(code.rfind("}"),detail)
 var parameters := {}
 for parameter in material.shader.get_shader_uniform_list():
  parameters[parameter.name]=material.get_shader_parameter(parameter.name)
 var shader := Shader.new()
 shader.code=code
 material.shader=shader
 for key in parameters: material.set_shader_parameter(key,parameters[key])
 material.set_shader_parameter("relief_normal",texture(id,"normal"))
 material.set_shader_parameter("detail_roughness",texture(id,"roughness"))
 material.set_shader_parameter("detail_ao",texture(id,"ao"))
 material.set_shader_parameter("detail_metallic",texture(id,"metallic"))
 material.set_meta("chemical_relief",float(STRENGTH[id]))
 material.set_meta("chemical_neon",id in ["1C","3C"])
 _update_material(material)
 return material

func _update_material(material: Material) -> void:
 if not material is ShaderMaterial or not material.has_meta("chemical_relief"): return
 material.set_shader_parameter("relief_strength",float(material.get_meta("chemical_relief"))*strength if enabled else 0.0)
 material.set_shader_parameter("detail_mix",1.0 if enabled else 0.0)
 if material.get_meta("chemical_neon",false):
  material.set_shader_parameter("neon_strength",neon_strength)
  material.set_shader_parameter("neon_spread",neon_spread)
  material.set_shader_parameter("floor_neon_spread",floor_neon_spread)

func update(root: Node) -> void:
 # Geometry generators duplicate materials; update the actual bound instances too.
 if root is GeometryInstance3D and root.material_override:
  _update_material(root.material_override)
 elif root is MeshInstance3D and root.mesh:
  for surface in root.mesh.get_surface_count(): _update_material(root.get_active_material(surface))
 for child in root.get_children(): update(child)
