extends SceneTree
## Ownership, live controls and legacy compatibility; never benchmarks a winner.
const Options := preload("res://scripts/rendering_options.gd")
const Fields := preload("res://scripts/atmosphere/fields.gd")
const Variants := preload("res://scripts/atmosphere/variants.gd")
const Runtime := preload("res://scripts/atmosphere/runtime.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)

func device_unchanged(label: String, light: DirectionalLight3D) -> void:
 check(Options.shadow_resolution() == 4096 and Options.shadow_cascades() == 2 and Options.smooth_shadows_enabled(), label + " preserves device preferences")
 check(light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, label + " preserves actual light mode")

func run() -> void:
 Options.settings_path = "user://device-shadow-regression.cfg"
 if "--reload-only" in OS.get_cmdline_user_args():
  var light := DirectionalLight3D.new()
  Options.register_light(light)
  device_unchanged("Fresh process", light)
  light.free()
  finish()
  return
 if FileAccess.file_exists(Options.settings_path): DirAccess.remove_absolute(Options.settings_path)
 check(Options.shadow_resolution() == int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")) and Options.shadow_cascades() == 4 and not Options.smooth_shadows_enabled(), "No preference preserves shipped defaults")
 var invalid := ConfigFile.new()
 invalid.set_value("rendering", "directional_shadow_resolution", "4096")
 invalid.set_value("rendering", "directional_shadow_cascades", 3)
 invalid.set_value("rendering", "smooth_shadows", "true")
 invalid.set_value("unrelated", "keep", 17)
 invalid.save(Options.settings_path)
 Options._loaded = false
 check(Options.shadow_resolution() == 8192 and Options.shadow_cascades() == 4 and not Options.smooth_shadows_enabled(), "Invalid saved values fall back without coercion")
 check(Options.set_shadow_resolution(3000) == ERR_INVALID_PARAMETER and Options.set_shadow_cascades(3) == ERR_INVALID_PARAMETER, "Invalid setters reject unsupported choices")
 root.size = Vector2i(1600, 1100)
 var lab = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 lab.authored_act_path = "res://data/acts/Experiments/Lockbox.tres"
 root.add_child(lab)
 for frame in 8: await process_frame
 var panel = lab.lighting_controls
 panel.settings_path = "user://device-shadow-lab-regression.cfg"
 DirAccess.make_dir_recursive_absolute("user://device-shadow-variants")
 for theme: String in Variants.THEMES:
  DirAccess.copy_absolute(Variants.new().path(theme), "user://device-shadow-variants/" + theme + ".cfg")
 panel.variants.registry.directory = "user://device-shadow-variants"
 var baseline: Dictionary = panel.values.duplicate(true)
 check(not baseline.has(Fields.LEGACY_SHADOW_MODE) and not panel.widgets.has(Fields.LEGACY_SHADOW_MODE), "New authoring excludes cascade mode")
 var shadowless := DirectionalLight3D.new()
 Options.register_light(shadowless)
 for size: int in Options.SHADOW_RESOLUTIONS:
  panel.shadow_resolution.item_selected.emit(panel.shadow_resolution.get_item_index(size))
  check(Options.shadow_resolution() == size and panel.shadow_quality_status.text.begins_with(str(size)), "Live resolution status " + str(size))
  for count: int in Options.SHADOW_CASCADES:
   panel.shadow_cascades.item_selected.emit(panel.shadow_cascades.get_item_index(count))
   check(lab.presentation._key_light.directional_shadow_mode == Options.SHADOW_CASCADES.find(count) and shadowless.directional_shadow_mode == Options.SHADOW_CASCADES.find(count), "All live lights inherit " + str(count))
   check(not shadowless.shadow_enabled and panel.values == baseline, "Quality preserves shadowless lights and appearance")
  for frame in 3: await process_frame
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   print("LIVE_ATLAS | size=", size, " | texture_bytes=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))
 Options.set_shadow_resolution(4096)
 Options.set_shadow_cascades(2)
 panel.smooth_shadows.button_pressed = true
 var settings := ConfigFile.new()
 settings.load(Options.settings_path)
 check(settings.get_value("unrelated", "keep") == 17, "Device saves preserve unrelated settings")
 var hashes := {}
 var registry := Variants.new()
 for theme: String in Variants.THEMES: hashes[theme] = registry.revision(theme)
 for theme: String in Variants.THEMES:
  lab.set_theme(theme)
  for frame in 2: await process_frame
  device_unchanged("Theme " + theme, lab.presentation._key_light)
  panel.variants.context.selected = "default"
  panel.variants.load_selected()
  panel.variants.save_variant()
  device_unchanged("Variant load/save", lab.presentation._key_light)
  panel.compare.button_pressed = true
  device_unchanged("Show Original", lab.presentation._key_light)
  panel.reset_values()
  panel.save_preset()
  panel.reload_preset()
  for frame in 2: await process_frame
  device_unchanged("Reset/Save/Reload", lab.presentation._key_light)
  var draft := ConfigFile.new()
  draft.load(panel.settings_path)
  check(not draft.get_value(panel.preset_key, "values", {}).has(Fields.LEGACY_SHADOW_MODE), "Saved draft excludes cascades")
  var light := DirectionalLight3D.new()
  var runtime := Runtime.new()
  runtime.configure(theme, {"values": {Fields.LEGACY_SHADOW_MODE: 0, "sun/shadow_opacity": 0.31}}, Environment.new(), light)
  device_unchanged("Legacy runtime", light)
  check(is_equal_approx(light.shadow_opacity, 0.31) and not runtime.lighting.has("directional_shadow_mode"), "Legacy keeps artistic intent, excludes quality from blending")
  light.free()
 for theme: String in Variants.THEMES: check(registry.revision(theme) == hashes[theme], "No source atmosphere rewrite: " + theme)
 registry.directory = "user://device-shadow-legacy"
 DirAccess.make_dir_recursive_absolute(registry.directory)
 var legacy := ConfigFile.new()
 legacy.set_value("format", "version", 1)
 var record := Variants.baseline()
 record.values = {Fields.LEGACY_SHADOW_MODE: 1, "sun/shadow_opacity": 0.42}
 for key: String in ["name", "enabled", "weight", "values"]: legacy.set_value("default", key, record[key])
 legacy.save(registry.path("green_hill"))
 var old_hash := registry.revision("green_hill")
 var records := registry.read("green_hill")
 check(registry.error.is_empty() and not records[0].values.has(Fields.LEGACY_SHADOW_MODE), "Legacy variant loads without cascade ownership")
 check(registry.revision("green_hill") == old_hash, "Loading legacy variant preserves exact bytes")
 check(registry.save("green_hill", [record], old_hash), "Explicit legacy save succeeds")
 legacy.load(registry.path("green_hill"))
 check(not legacy.get_value("default", "values").has(Fields.LEGACY_SHADOW_MODE), "Explicit save removes only retired field")
 check(record.values.has(Fields.LEGACY_SHADOW_MODE), "Save does not mutate caller data")
 panel._sync_device_shadow_controls()
 panel.tabs.current_tab = panel.tabs.get_tab_idx_from_control(panel.tabs.get_node("Shadows"))
 if DisplayServer.get_name() != "headless":
  for frame in 5: await process_frame
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute("res://test-results/shadow-device")
  root.get_texture().get_image().save_png("res://test-results/shadow-device/lab.png")
 shadowless.free()
 lab.queue_free()
 await process_frame
 finish()

func finish() -> void:
 print("DEVICE_SHADOWS | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
