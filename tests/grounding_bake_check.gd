extends SceneTree
## Read-only freshness receipt for the seven-theme diagnostic package.
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Plan = preload("res://scripts/endless/endless_plan.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const THEMES := ["green_hill", "chemical_plant", "rooftop_run", "casino_night", "sky_sanctuary", "ice_cap", "aquarium_park"]
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var output := "res://grounding-freshness.json"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
 var paths: Array = Plan.PATHS.duplicate()
 paths.append_array(preload("res://scripts/prototype/run_plan.gd").source_paths())
 var rows: Array[Dictionary] = []
 var stale: Array[Dictionary] = []
 for theme: String in THEMES:
  var fingerprint := Bake.pipeline_hash(theme)
  var background: Resource = load(Bake.theme_path(theme)) if ResourceLoader.exists(Bake.theme_path(theme)) else null
  var shared_ok: bool = background is Bake and background.matches_pipeline(theme, fingerprint)
  for path: String in paths:
   var document: Resource = Document.load_document(path).document
   var bake_path := Bake.path_for(path, theme)
   var baked: Resource = load(bake_path) if ResourceLoader.exists(bake_path) else null
   var current: bool = shared_ok and baked is Bake and baked.matches(document, theme, fingerprint) and baked.has_validated_collisions(document) and baked.visual_recipe.has_warm_manifest()
   var row := {"act": path, "theme": theme, "bake": bake_path, "current": current, "pipeline": fingerprint}
   rows.append(row)
   if not current: stale.append(row)
   await process_frame
 FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"complete": stale.is_empty(), "variants": rows, "stale": stale}, "  "))
 print("GROUNDING_FRESHNESS | variants=", rows.size(), " | stale=", stale.size())
 quit(0 if stale.is_empty() else 1)
