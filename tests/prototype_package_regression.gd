extends SceneTree
## Run against the exported PCK, so imported assets cannot hide missing source fingerprints.
const Run = preload("res://scripts/prototype/zone_run.gd")
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const ActDocument = preload("res://scripts/act_editor/act_geometry.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
 var fingerprint := Bake.pipeline_hash("green_hill")
 check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/prototype_run.tscn", "Package starts at the player menu")
 var theme = load(Bake.theme_path("green_hill"))
 check(theme is Bake and theme.matches_pipeline("green_hill", fingerprint), "Packaged theme matches its source assets and pipeline")
 for path: String in Run.ACTS:
  var loaded := ActDocument.load_document(path)
  check(loaded.document != null, "Packaged authored Act loads: " + path)
  if loaded.document == null: continue
  var baked = load(Bake.path_for(path, "green_hill"))
  check(baked is Bake and baked.matches(loaded.document, "green_hill", fingerprint), "Packaged Act fingerprints match: " + path)
  check(baked is Bake and baked.has_validated_collisions(loaded.document) and baked.visual_recipe != null, "Packaged Act retains validated collisions and presentation: " + path)
 print("RESULT | Prototype package | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)
