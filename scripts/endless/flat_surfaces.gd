extends RefCounted
## Offline trial policy. Only recognized surface-relief shaders are simplified.
## Originals stay intact for the editor; water, animation and screen effects remain.
const RELIEF_INCLUDE := '#include "res://scripts/themes/rooftop_normal.gdshaderinc"'
const FLAT_RELIEF := "vec3 relief(vec3 position, vec3 geometric, vec2 coordinates, vec2 sample_uv) { return normalize(geometric); }"
var shaders := {}
var error := ""

func material(source: Material) -> Material:
 if source is BaseMaterial3D:
  if not source.normal_enabled and not source.heightmap_enabled: return source
  var result: BaseMaterial3D = source.duplicate()
  result.normal_enabled = false
  result.heightmap_enabled = false
  result.normal_texture = null
  result.heightmap_texture = null
  return result
 if not source is ShaderMaterial or source.shader == null: return source
 var code: String = source.shader.code
 var flat := code.replace(RELIEF_INCLUDE, FLAT_RELIEF)
 if source.shader.resource_path.get_file() == "green_hill_turf.gdshader":
  var start := flat.find(" vec2 p=world_position.xz*grass_density;")
  var end := flat.find(" ALBEDO=", start)
  if start < 0 or end < 0:
   error = "The grass relief shader changed. Update the offline flat-surface conversion before baking."
   return source
  flat = flat.substr(0, start) + flat.substr(end)
 if flat == code: return source
 if not shaders.has(flat):
  var shader := Shader.new()
  shader.code = flat
  shaders[flat] = shader
 var result: ShaderMaterial = source.duplicate()
 result.shader = shaders[flat]
 # Only copy surviving uniforms. Removed normal maps must not stay in the bake.
 result.set_shader_parameter("relief_normal", null)
 result.set_shader_parameter("relief_strength", null)
 for uniform: Dictionary in result.shader.get_shader_uniform_list():
  result.set_shader_parameter(uniform.name, source.get_shader_parameter(uniform.name))
 return result
