extends SceneTree
## Run against the exported PCK, so imported assets cannot hide missing source fingerprints.
const Run = preload("res://scripts/prototype/zone_run.gd")
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const ActDocument = preload("res://scripts/act_editor/act_geometry.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
 check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/prototype_run.tscn", "Package starts at the player menu")
 var paths := Run.RunPlan.source_paths()
 check(paths.size() >= Run.RunPlan.ACTS_PER_ZONE, "Packaged authored folder contains a playable authored pool")
 for theme_id: String in Run.RunPlan.THEMES:
  var fingerprint := Bake.pipeline_hash(theme_id)
  var theme = load(Bake.theme_path(theme_id))
  check(theme is Bake and theme.matches_pipeline(theme_id, fingerprint), "Packaged theme matches its source assets and pipeline: " + theme_id)
  for path: String in paths:
   var loaded := ActDocument.load_document(path)
   check(loaded.document != null, "Packaged authored Act loads: " + path)
   if loaded.document == null: continue
   var baked = load(Bake.path_for(path, theme_id))
   check(baked is Bake and baked.matches(loaded.document, theme_id, fingerprint), "Packaged Act fingerprints match: " + path + " / " + theme_id)
   check(baked is Bake and baked.has_validated_collisions(loaded.document) and baked.visual_recipe != null and baked.visual_recipe.has_warm_manifest(), "Packaged Act retains validated collisions, presentation and warm-up metadata: " + path)
 print("RESULT | Prototype package | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)
