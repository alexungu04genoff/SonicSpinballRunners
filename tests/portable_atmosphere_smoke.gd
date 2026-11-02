extends Node
## Invoke the release EXE with -- --portable-atmosphere-smoke --workspace=<isolated folder>.
const Workspace = preload("res://scripts/portable_workspace.gd")
const Variants = preload("res://scripts/atmosphere/variants.gd")
const Scenery = preload("res://scripts/themes/scenery_settings.gd")
var failures := 0
var checks := 0

func _ready() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func run() -> void:
 check(Workspace.enabled(), "Portable workspace is enabled in the export")
 var registry := Variants.new()
 check(registry.directory == Workspace.atmosphere_directory() and not registry.directory.begins_with("res://"), "Variant saves target the external Atmospheres folder")
 for theme: String in Variants.THEMES:
  var records := registry.read(theme)
  check(registry.error.is_empty() and not records.is_empty(), "Bundled atmosphere copies load: " + theme)
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 get_tree().root.add_child(game)
 await get_tree().process_frame
 await get_tree().process_frame
 check(is_instance_valid(game.lighting_controls) and is_instance_valid(game.presentation), "Standalone Atmosphere Lab opens its full inspector and 3D scene")
 var act_path: String = game.authored_act_path
 check(act_path.begins_with(Workspace.act_directory()) and FileAccess.file_exists(act_path), "Lab starts with an editable external Act")
 var panel = game.lighting_controls
 var variants = panel.variants
 variants.context.selected = "default"
 variants.load_selected()
 var original: PackedByteArray = FileAccess.get_file_as_bytes(registry.path("green_hill"))
 var weight: float = variants.selected_record().weight + 0.25
 variants.weight.value = weight
 variants.save_variant()
 var saved := Variants.new().read("green_hill")
 check(is_equal_approx(float(saved[0].weight), weight), "Save Variant persists through the real inspector")
 var revision := registry.revision("green_hill")
 check(Workspace.prepare() == OK and registry.revision("green_hill") == revision, "Reopening a tool never replaces existing atmosphere edits")
 var scenery = panel.scenery
 scenery.change({"seed": 123456, "density": 1.25})
 await get_tree().process_frame
 await get_tree().process_frame
 scenery.seed_field.get_line_edit().text = "123456"
 scenery.save()
 var stored := Scenery.read(act_path, "green_hill")
 check(stored.error.is_empty() and stored.seed == 123456 and stored.density == 1.25, "Scenery saves beside the external Act")
 check(Workspace.prepare() == OK and Scenery.read(act_path, "green_hill").seed == 123456, "Workspace initialization preserves scenery sidecars")
 panel.save_preset()
 check(FileAccess.file_exists(panel.settings_path), "User-local Lab drafts save successfully")
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  get_tree().root.get_texture().get_image().save_png("user://portable-atmosphere.png")
 game.queue_free()
 await get_tree().process_frame
 game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 get_tree().root.add_child(game)
 await get_tree().process_frame
 await get_tree().process_frame
 check(game.lighting_controls.scenery.values.seed == 123456 and is_equal_approx(float(Variants.new().read("green_hill")[0].weight), weight), "A fresh Lab instance reloads saved scenery and variants")
 for theme: String in ["chemical_plant", "casino_night", "rooftop_run"]:
  check(game.set_theme(theme), "Theme selector accepts " + theme)
  await get_tree().process_frame
  await get_tree().process_frame
  check(game.lighting_controls.variants.theme_id == theme and game.presentation.theme_definition.theme_id == theme, "Exported art and inspector switch to " + theme)
  if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
 FileAccess.open(registry.path("green_hill"), FileAccess.WRITE).store_buffer(original)
 game.queue_free()
 await get_tree().process_frame
 print("RESULT | Portable Atmosphere Lab | %d checks | %d failures" % [checks, failures])
 get_tree().quit(1 if failures else 0)
