extends RefCounted
## Add the shared color uniforms once to explicitly opted-in surface programs.
## This preserves custom texture/relief code; slider edits only change uniforms.
const INCLUDE := '#include "res://scripts/atmosphere/hue.gdshaderinc"'
const TRIM_INCLUDE := '#include "res://scripts/atmosphere/trim.gdshaderinc"'
static var shaders := {}

static func prepare(material: Material) -> void:
 if not material is ShaderMaterial or material.shader == null: return
 var source: Shader = material.shader
 var code := source.code
 var sky := code.contains("shader_type sky;")
 var surface_emission := not sky
 var supported := code.contains("atmosphere_shift")
 var trim := bool(material.get_meta("atmosphere_trim_split", false))
 var has_trim := code.contains("atmosphere_border_shift")
 supported = supported or has_trim
 var has_emission := code.contains("// Atmosphere emission controls.")
 if supported and (not surface_emission or has_emission) and (not trim or has_trim): return
 var source_path: String = source.get_meta("atmosphere_source_path", source.resource_path)
 material.set_meta("atmosphere_shader_id", source_path.get_file().get_basename())
 var key := (source_path + code + str(surface_emission) + str(trim)).sha256_text()
 if not shaders.has(key):
  # Mask comments before locating the fragment's closing brace. Preserve all
  # indices and leave vertex/light functions and nested fragment blocks intact.
  var masked := code
  var comments := RegEx.create_from_string("(?s)/\\*.*?\\*/|//[^\\n]*")
  var matches := comments.search_all(masked)
  matches.reverse()
  for found: RegExMatch in matches:
   masked = masked.substr(0, found.get_start()) + " ".repeat(found.get_end() - found.get_start()) + masked.substr(found.get_end())
  var entry_point := "sky" if sky else "fragment"
  var fragment := RegEx.create_from_string("void\\s+" + entry_point + "\\s*\\(\\s*\\)\\s*\\{").search(masked)
  if fragment == null:
   push_error("Opted-in atmosphere material has no fragment: " + source_path)
   return
  var depth := 1
  var end := fragment.get_end()
  while end < masked.length() and depth > 0:
   if masked[end] == "{": depth += 1
   elif masked[end] == "}": depth -= 1
   if depth > 0: end += 1
  if depth != 0:
   push_error("Unbalanced atmosphere surface: " + source_path)
   return
  var shader := Shader.new()
  var output := "COLOR" if sky else "ALBEDO"
  var additions := "" if supported else "\n " + output + " = atmosphere_shift(" + output + ");\n"
  if surface_emission and not has_emission: additions += "\n // Atmosphere emission controls.\n EMISSION = atmosphere_emission_shift(EMISSION);\n"
  var adapted := code.substr(0, end) + additions + code.substr(end)
  if not supported:
   var declaration := "shader_type sky;" if sky else "shader_type spatial;"
   adapted = adapted.replace(declaration, declaration + "\n" + INCLUDE + "\n")
  if trim and not has_trim:
   adapted = adapted.replace(INCLUDE, INCLUDE + "\n" + TRIM_INCLUDE)
   adapted = adapted.replace("atmosphere_shift(ALBEDO)", "atmosphere_border_shift(ALBEDO, UV2.x)")
  shader.code = adapted
  shader.set_meta("atmosphere_source_path", source_path)
  shaders[key] = shader
 material.shader = shaders[key]

static func decor_copy(source: Material) -> Material:
 var result: Material = source.duplicate()
 result.set_meta("atmosphere_hue", "foliage" if preload("res://scripts/themes/theme_atmosphere.gd").is_foliage(source) else "decor")
 prepare(result)
 return result
