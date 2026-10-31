extends SceneTree
## Rendered coverage: semantic bindings, exact restore, shared resources and v1 saves.
const Palette := preload("res://scripts/themes/theme_atmosphere.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(description)

func frames(count: int) -> void:
 for frame in count: await process_frame

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Atmosphere regression requires a real renderer for shader uniforms.")
  quit(1)
  return
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(game)
 paused = true
 await frames(12)
 var panel = game.lighting_controls
 panel.settings_path = "res://test-results/atmosphere/regression-presets.cfg"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(panel.settings_path.get_base_dir()))
 panel.saved = ConfigFile.new()
 panel.drafts.clear()
 panel.reset_values()
 var world_id: int = game.world.get_instance_id()
 var position: Vector2 = game.ball.position
 var score: int = game.score
 for theme: String in game.ThemeRegistry.IDS:
  game.set_theme(theme)
  panel.reset_values()
  check(panel.palette_fields.size() >= 4, "Semantic controls available: " + theme)
  var authored: Dictionary = panel.originals.duplicate(true)
  var nodes: int = game.presentation.find_children("*", "", true, false).size()
  var copies: Dictionary = panel.emission.materials.duplicate()
  var modified: Dictionary = authored.duplicate(true)
  for spec: Array in panel.palette_fields:
   modified[spec[1]] = Color("481c68") if spec[2] == "color" else 0.31
  panel.values = modified
  panel.apply_values()
  for entry: Dictionary in panel.emission.palette_parameters:
   var actual = entry.target.get_shader_parameter(entry.property) if entry.shader else entry.target.get(entry.property)
   check(actual != entry.base, "Live binding changes: " + theme + "/" + entry.key + "/" + entry.property)
  check(panel.emission.materials == copies, "Palette edits reuse the same shared material copies: " + theme)
  copies.clear()
  check(game.presentation.find_children("*", "", true, false).size() == nodes, "Palette edits preserve scene topology: " + theme)
  panel.compare.button_pressed = true
  for entry: Dictionary in panel.emission.palette_parameters:
   var actual = entry.target.get_shader_parameter(entry.property) if entry.shader else entry.target.get(entry.property)
   check(actual == entry.base, "Original comparison restores exact property: " + theme + "/" + entry.key)
  check(panel.values == modified, "Comparison preserves complete draft: " + theme)
  panel.compare.button_pressed = false
  panel.reset_values()
  if not panel.emission.cloud_lights.is_empty():
   panel.set_value("sun_yaw", 127.0)
   for entry: Dictionary in panel.emission.cloud_lights:
    check(entry.material.get_shader_parameter("fake_light_direction").is_equal_approx(game.presentation._key_light.basis.z.normalized()), "Analytic clouds follow selected sun: " + theme)
   panel.reset_values()
   for entry: Dictionary in panel.emission.cloud_lights:
    var direction = entry.material.get_shader_parameter("fake_light_direction")
    check(direction == entry.base, "Authored cloud direction restores exactly: " + theme)
  panel.set_scenery_visible("far", false)
  for child: Node3D in game.presentation.scenery_root.get_children():
   if child.get_meta("atmosphere_scenery", "far") == "local": check(child.visible, "Far inspection preserves local framing: " + theme)
  panel.set_scenery_visible("far", true)
  panel.set_scenery_visible("local", false)
  for child: Node3D in game.presentation.scenery_root.get_children():
   if child.get_meta("atmosphere_scenery", "far") == "far": check(child.visible, "Local inspection preserves far environment: " + theme)
  panel.set_scenery_visible("local", true)
  var night: Dictionary = panel.LightingLooks.create("Night", authored, theme)
  if theme == "sky_sanctuary":
   check(night["palette/bank_highlight"].v < 0.65 and night["palette/sea_shadow"].v < 0.25, "Night recipe subdues unshaded clouds")
  if theme == "ice_cap":
   check(game.presentation._world_environment.environment.sky.process_mode == Sky.PROCESS_MODE_QUALITY, "Ice retains cached quality radiance")
   check(not panel.sky_material.shader.code.contains("TIME"), "Ice sky has no per-frame radiance dependency")
  check(game.world.get_instance_id() == world_id and game.ball.position == position and game.score == score, "Atmosphere preserves gameplay: " + theme)
  print("ATMOSPHERE_FIELDS | ", theme, " | ", panel.palette_fields.size())
  if "--capture-atmosphere-ui" in OS.get_cmdline_user_args():
   var tabs: TabContainer = panel.palette_controls.get_parent().get_parent()
   tabs.current_tab = 2
   await frames(12)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/atmosphere/palette-" + theme + ".png")
 game.set_theme("green_hill")
 var old := ConfigFile.new()
 old.set_value("format", "version", 1)
 old.set_value(panel.preset_key, "values", {"env/tonemap_exposure": 0.73, "legacy_unknown": "preserve"})
 old.set_value("other_renderer/green_hill", "values", {"env/tonemap_exposure": 1.27})
 old.save(panel.settings_path)
 panel.reload_preset()
 check(is_equal_approx(panel.values["env/tonemap_exposure"], 0.73), "v1 lighting survives additive migration")
 check(panel.values["palette/ocean_deep"] == panel.originals["palette/ocean_deep"], "v1 missing palette inherits authored values")
 panel.set_value("palette/ocean_deep", Color("361d52"))
 panel.compare.button_pressed = true
 panel.save_preset()
 check(FileAccess.file_exists(panel.settings_path + ".v1-backup"), "First v2 save preserves a v1 backup")
 var saved := ConfigFile.new()
 saved.load(panel.settings_path)
 check(saved.get_value("format", "version") == 2, "Save records format v2")
 check(saved.get_value(panel.preset_key, "values")["legacy_unknown"] == "preserve", "Save preserves unknown old fields")
 check(saved.get_value("other_renderer/green_hill", "values")["env/tonemap_exposure"] == 1.27, "Save preserves other renderer sections")
 panel.reload_preset()
 check(panel.values["palette/ocean_deep"].is_equal_approx(Color("361d52")), "Save during comparison stores the tuned palette")
 panel.set_value("palette/ocean_wave", Color("713a53"))
 game.set_theme("ice_cap")
 game.set_theme("green_hill")
 check(panel.values["palette/ocean_wave"] == Color("713a53"), "Unsaved palette survives theme switch")
 panel.restore_original()
 game.free()
 paused = false
 await frames(3)
 print("ATMOSPHERE_REGRESSION | ", checks - failures, "/", checks, " checks passed")
 quit(0 if failures == 0 else 1)
