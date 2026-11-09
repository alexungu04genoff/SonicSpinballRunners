extends SceneTree
## Explicit offline audit of the published pool. Does not bake or repair assets.
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Plan = preload("res://scripts/endless/endless_plan.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const SELECTED_TAGS := {"sky_sanctuary": "sky_selected", "ice_cap": "ice_selected",
 "lava_reef": "lava_selected", "aquarium_park": "aquarium_selected"}
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
  var expected_detail := "selected_relief" if SELECTED_TAGS.has(theme) else "flat"
  var fingerprint := Bake.pipeline_hash(theme)
  var background: Resource = load(Bake.theme_path(theme))
  check(background is Bake and background.matches_pipeline(theme, fingerprint), "Fresh shared theme: " + theme)
  if not background is Bake: continue
  check(background.surface_detail == expected_detail and background.visual_recipe.has_warm_manifest(), "Theme retains its approved surface policy and offline warm manifest: " + theme)
  var selected_count := 0
  for material: Material in background.preload_materials:
   if material is ShaderMaterial and material.shader:
    var selected_tag := ""
    for tag: String in SELECTED_TAGS.values():
     if material.get_meta(tag, false): selected_tag = tag
    if not selected_tag.is_empty():
     selected_count += 1
     check(selected_tag == SELECTED_TAGS.get(theme, ""), "Selected relief belongs to its own theme: " + theme)
     check(material.shader.code.contains("rooftop_normal.gdshaderinc"), "Approved selected shader retains structural relief: " + theme)
     check(material.get_shader_parameter("relief_normal") is Texture2D, "Approved selected normal texture survives baking: " + theme)
     continue
    check(not material.shader.code.contains("rooftop_normal.gdshaderinc") and not material.shader.code.contains("NORMAL=normalize(NORMAL-gradient)"), "Saved shader omits recognized relief: " + theme)
    check(material.get_shader_parameter("relief_normal") == null, "Saved shader omits normal texture: " + theme)
   elif material is BaseMaterial3D:
    check(not material.normal_enabled and not material.heightmap_enabled, "Saved standard material has no relief: " + theme)
  if SELECTED_TAGS.has(theme): check(selected_count > 0, "Published theme includes its approved selected materials: " + theme)
  for path: String in paths:
   var document: Resource = Document.load_document(path).document
   var baked: Resource = load(Bake.path_for(path, theme))
   check(baked is Bake and baked.matches(document, theme, fingerprint), "Fresh Act: " + path + " / " + theme)
   if not baked is Bake: continue
   check(baked.has_validated_collisions(document), "Act includes successful physics validation and complete collisions")
   check(baked.surface_detail == expected_detail and baked.visual_recipe.has_warm_manifest(), "Act retains its approved surface policy and offline warm manifest")
   check(not baked.collisions.is_empty() and not baked.visual_recipe.records.is_empty(), "Saved Act contains collisions and visual records")
   variants += 1
   await process_frame
 check(variants == paths.size() * Plan.Registry.IDS.size(), "Every published Act/theme variant exists")
 print("ENDLESS_BAKE_AUDIT | variants=%d checks=%d failures=%d" % [variants, checks, failures])
 quit(1 if failures else 0)
