extends SceneTree
## Explicit offline audit of the published pool. Does not bake or repair assets.
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Plan = preload("res://scripts/endless/endless_plan.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
var checks := 0
var failures := 0
var variants := 0

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var paths: Array = Plan.PATHS
 if "--prototype" in OS.get_cmdline_user_args():
  paths = preload("res://scripts/prototype/run_plan.gd").source_paths()
 check(not paths.is_empty(), "The selected pool contains authored Acts")
 for theme: String in Plan.Registry.IDS:
  var fingerprint := Bake.pipeline_hash(theme)
  var background: Resource = load(Bake.theme_path(theme))
  check(background is Bake and background.matches_pipeline(theme, fingerprint), "Fresh shared theme: " + theme)
  if not background is Bake: continue
  check(background.surface_detail == "flat" and background.visual_recipe.has_warm_manifest(), "Flat theme has an offline warm manifest: " + theme)
  for material: Material in background.preload_materials:
   if material is ShaderMaterial and material.shader:
    check(not material.shader.code.contains("rooftop_normal.gdshaderinc") and not material.shader.code.contains("NORMAL=normalize(NORMAL-gradient)"), "Saved shader omits recognized relief: " + theme)
    check(material.get_shader_parameter("relief_normal") == null, "Saved shader omits normal texture: " + theme)
   elif material is BaseMaterial3D:
    check(not material.normal_enabled and not material.heightmap_enabled, "Saved standard material has no relief: " + theme)
  for path: String in paths:
   var document: Resource = Document.load_document(path).document
   var baked: Resource = load(Bake.path_for(path, theme))
   check(baked is Bake and baked.matches(document, theme, fingerprint), "Fresh Act: " + path + " / " + theme)
   if not baked is Bake: continue
   check(baked.has_validated_collisions(document), "Act includes successful physics validation and complete collisions")
   check(baked.surface_detail == "flat" and baked.visual_recipe.has_warm_manifest(), "Flat Act has an offline warm manifest")
   check(not baked.collisions.is_empty() and not baked.visual_recipe.records.is_empty(), "Saved Act contains collisions and visual records")
   variants += 1
   await process_frame
 check(variants == paths.size() * Plan.Registry.IDS.size(), "Every published Act/theme variant exists")
 print("ENDLESS_BAKE_AUDIT | variants=%d checks=%d failures=%d" % [variants, checks, failures])
 quit(1 if failures else 0)
