extends Resource
## Derived data only. Never owns or edits the authored document.
const VERSION := 1
const DEPENDENCIES := ["res://scripts/presentation.gd", "res://scripts/themes/themed_presentation.gd",
 "res://scripts/themes/terrain_border.gd", "res://scripts/endless/template_presenter.gd",
 "res://scripts/authored_act/act_runtime_compiler.gd", "res://scripts/act_dimensions.gd"]
@export var version := VERSION
@export var source_fingerprint := ""
@export var pipeline_fingerprint := ""
@export var theme_id := ""
@export var geometry: Dictionary = {}
@export var collisions: Array = []

static func path_for(act_path: String, theme: String) -> String:
 return act_path.get_basename() + ".bake/" + theme + ".res"

static func pipeline_hash(theme: String) -> String:
 var content := str(VERSION) + str(Engine.get_version_info().hex)
 for path: String in DEPENDENCIES + ["res://scripts/themes/" + theme + "_theme.gd"]:
  content += FileAccess.get_file_as_string(path).replace("\r", "").sha256_text()
 return content.sha256_text()

func matches(document: Resource, theme: String) -> bool:
 return version == VERSION and theme_id == theme and source_fingerprint == document.fingerprint() and pipeline_fingerprint == pipeline_hash(theme)

static func without_materials(value: Variant) -> Variant:
 if value is ArrayMesh:
  var mesh: ArrayMesh = value.duplicate()
  for i in mesh.get_surface_count(): mesh.surface_set_material(i, null)
  return mesh
 if value is Array:
  var result: Array = []
  for item: Variant in value: result.append(without_materials(item))
  return result
 if value is Dictionary:
  var result := {}
  for key: Variant in value: result[key] = without_materials(value[key])
  return result
 return value
