extends RefCounted

static func create(original: Material, normal_style: String, height_style: String, map_name := "floor", mapping := "surface_texture") -> ShaderMaterial:
 var result: ShaderMaterial
 var code: String
 if original is ShaderMaterial:
  result = original.duplicate()
  code = original.shader.code
 else:
  result = ShaderMaterial.new()
  if mapping == "route_strip":
   code = preload("res://experiments/rooftop_lighting/scene_guard.gdshader").code
   code = code.replace('#include "res://experiments/rooftop_lighting/scene_normal.gdshaderinc"', '')
  else:
   code = """shader_type spatial;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float base_roughness = 1.0;
uniform float base_specular = 0.5;
void fragment() {}"""
   if original.cull_mode == BaseMaterial3D.CULL_DISABLED:
    code = code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode cull_disabled;")
 var fragment := ""
 match mapping:
  "surface_texture":
   fragment = """
 vec2 uv = (world_mapping ? world_position.xz : UV) / repeat_size;
 vec2 at = crossed_uv(VERTEX, NORMAL, uv, VIEW);
 ALBEDO = textureGrad(surface_texture, at, dFdx(uv), dFdy(uv)).rgb;
 ROUGHNESS = 1.0;
 NORMAL = relief(VERTEX, NORMAL, uv, at);
"""
  "wall_texture":
   fragment = """
 vec2 weights = pow(abs(world_normal.xz), vec2(8.0));
 weights /= max(weights.x + weights.y, 0.001);
 float depth = top_height - world_position.y;
 vec2 a = vec2(world_position.z, depth) / vec2(3.4, 1.45);
 vec2 b = vec2(world_position.x, depth) / vec2(3.4, 1.45);
 vec2 pa = relief_sample(crossed_uv(VERTEX, NORMAL, a, VIEW));
 vec2 pb = relief_sample(crossed_uv(VERTEX, NORMAL, b, VIEW));
 ALBEDO = textureGrad(wall_texture, pa, dFdx(a), dFdy(a)).rgb * weights.x + textureGrad(wall_texture, pb, dFdx(b), dFdy(b)).rgb * weights.y;
 ROUGHNESS = 0.95;
 NORMAL = normalize(relief(VERTEX, NORMAL, a, pa) * weights.x + relief(VERTEX, NORMAL, b, pb) * weights.y + NORMAL * max(0.0, 1.0 - weights.x - weights.y));
"""
  "border_texture":
   fragment = """
 vec2 at = relief_sample(crossed_uv(VERTEX, NORMAL, UV, VIEW));
 ALBEDO = textureGrad(border_texture, at, dFdx(UV), dFdy(UV)).rgb;
 ROUGHNESS = 1.0;
 NORMAL = relief(VERTEX, NORMAL, UV, at);
"""
  "route_strip", "box":
   fragment = """
 vec2 uv = COORDINATES;
 vec2 at = relief_sample(crossed_uv(VERTEX, NORMAL, uv, VIEW));
 ALBEDO = base_color.rgb;
 ROUGHNESS = base_roughness;
 SPECULAR = base_specular;
 NORMAL = relief(VERTEX, NORMAL, uv, at);
""".replace("COORDINATES", "route_uv" if mapping == "route_strip" else "UV")
 code = code.left(code.find("void fragment()")) + '#include "res://experiments/rooftop_lighting/scene_parallax.gdshaderinc"\nvoid fragment() {\n' + fragment + "\n}"
 var shader := Shader.new()
 shader.code = code
 result.shader = shader
 if original is StandardMaterial3D:
  result.set_shader_parameter("base_color", original.albedo_color)
  result.set_shader_parameter("base_roughness", original.roughness)
  result.set_shader_parameter("base_specular", original.metallic_specular)
 var prefix: String = "res://experiments/rooftop_lighting/scene_maps/" + map_name + "_"
 result.set_shader_parameter("relief_normal", load(prefix + normal_style + "_normal.png"))
 result.set_shader_parameter("height_texture", load(prefix + height_style + "_height.png"))
 result.set_shader_parameter("relief_boundary", 0 if mapping == "surface_texture" else (2 if mapping == "box" else 1))
 return result
