extends Resource
## Derived data only. Never owns or edits the authored document.
const VERSION := 4
const DEPENDENCIES := ["res://scripts/presentation.gd", "res://scripts/themes/themed_presentation.gd",
 "res://scripts/themes/terrain_border.gd", "res://scripts/endless/template_presenter.gd",
 "res://scripts/authored_act/act_runtime_compiler.gd", "res://scripts/act_dimensions.gd"]
@export var version := VERSION
@export var source_fingerprint := ""
@export var pipeline_fingerprint := ""
@export var theme_id := ""
@export var geometry: Dictionary = {}
@export var collisions: Array = []
@export var visual_recipe: Resource
@export var environment: Environment
@export var light: Dictionary = {}
@export var kind := "act"
@export var preload_materials: Array[Material] = []

static func path_for(act_path: String, theme: String) -> String:
 return act_path.get_basename() + ".bake/" + theme + ".res"

static func pipeline_hash(theme: String) -> String:
 var content := str(VERSION) + str(Engine.get_version_info().hex)
 var pending: Array = DEPENDENCIES + ["res://scripts/themes/" + theme + "_theme.gd",
  "res://scripts/endless/visual_recipe.gd", "res://scripts/endless/geometry_bake.gd",
  "res://scripts/endless/bake_assets.gd", "res://scripts/endless/static_batches.gd",
  "res://scripts/pinball_models.gd", "res://scripts/authored_act/mechanics_presentation.gd"]
 var visited := {}
 var references := RegEx.create_from_string("res://[^\"'\\s]+")
 var includes := RegEx.create_from_string('#include\\s+"([^\"]+)"')
 while not pending.is_empty():
  var path: String = pending.pop_back()
  if visited.has(path) or path == "res://": continue
  # The base presenter mentions its default theme; only the selected theme's
  # generators and assets participate in this bake.
  if path.ends_with("_theme.gd") and path != "res://scripts/themes/" + theme + "_theme.gd": continue
  visited[path] = true
  if path.begins_with("res://assets/") and DirAccess.dir_exists_absolute(path):
   for file: String in DirAccess.get_files_at(path):
    if not file.ends_with(".import"): pending.append(path.path_join(file))
   for directory: String in DirAccess.get_directories_at(path): pending.append(path.path_join(directory))
  elif FileAccess.file_exists(path):
   if path.get_extension() in ["gd", "gdshader", "gdshaderinc"]:
    var source := FileAccess.get_file_as_string(path).replace("\r", "")
    visited[path] = source.sha256_text()
    for found: RegExMatch in references.search_all(source): pending.append(found.get_string())
    for found: RegExMatch in includes.search_all(source): pending.append(path.get_base_dir().path_join(found.get_string(1)))
   else:
    visited[path] = FileAccess.get_sha256(path)
 var paths := visited.keys()
 paths.sort()
 for path: String in paths: content += path + str(visited[path])
 return content.sha256_text()

func matches(document: Resource, theme: String, fingerprint := "") -> bool:
 return kind == "act" and source_fingerprint == document.fingerprint() and matches_pipeline(theme, fingerprint)

func matches_pipeline(theme: String, fingerprint := "") -> bool:
 return version == VERSION and theme_id == theme and pipeline_fingerprint == (pipeline_hash(theme) if fingerprint.is_empty() else fingerprint)

static func theme_path(theme: String) -> String:
 return "res://data/endless/themes.bake/" + theme + ".res"

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
