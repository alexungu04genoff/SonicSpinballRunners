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
 check(Options.shadow_resolution() == 4096 and Options.shadow_cascades() == 2 and Options.ultra_filter_enabled() and Options.quality().fxaa, label + " preserves device preferences")
 check(light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, label + " preserves actual light mode")

func run() -> void:
 Options.settings_path = "user://device-shadow-regression.cfg"
 if "--shadow-review" in OS.get_cmdline_user_args():
  await review_controls()
  finish()
  return
 if "--reload-only" in OS.get_cmdline_user_args():
  var light := DirectionalLight3D.new()
  Options.register_light(light)
  device_unchanged("Fresh process", light)
  light.free()
  finish()
  return
 if FileAccess.file_exists(Options.settings_path): DirAccess.remove_absolute(Options.settings_path)
 check(Options.shadow_resolution() == int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size")) and Options.shadow_cascades() == 4 and not Options.ultra_filter_enabled(), "No preference preserves shipped defaults")
 var invalid := ConfigFile.new()
 invalid.set_value("rendering", "directional_shadow_resolution", "4096")
 invalid.set_value("rendering", "directional_shadow_cascades", 3)
 invalid.set_value("rendering", "smooth_shadows", "true")
 invalid.set_value("unrelated", "keep", 17)
 invalid.save(Options.settings_path)
 Options._loaded = false
 check(Options.shadow_resolution() == 8192 and Options.shadow_cascades() == 4 and not Options.ultra_filter_enabled(), "Invalid saved values fall back without coercion")
 check(Options.set_shadow_resolution(3000) == ERR_INVALID_PARAMETER and Options.set_shadow_cascades(3) == ERR_INVALID_PARAMETER, "Invalid setters reject unsupported choices")
 invalid.set_value("rendering", "smooth_shadows", true)
 invalid.save(Options.settings_path)
 Options._loaded = false
 check(Options.quality().fxaa and Options.ultra_filter_enabled(), "Legacy smooth enables both effects before any write")
 Options.update_quality({"fxaa": false})
 var migrated := ConfigFile.new()
 migrated.load(Options.settings_path)
 check(not migrated.has_section_key("rendering", "smooth_shadows") and migrated.get_value("rendering", "ultra_filter") and not migrated.get_value("rendering", "fxaa"), "First independent save migrates both keys")
 Options._loaded = false
 check(Options.ultra_filter_enabled() and not Options.quality().fxaa, "Migrated Ultra-only preference survives reload")
 Options.update_quality({"ultra_filter": false})
 root.size = Vector2i(1600, 1100)
 var lab = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 lab.authored_act_path = "res://data/acts/Experiments/Lockbox.tres"
 root.add_child(lab)
 for frame in 8: await process_frame
 var panel = lab.lighting_controls
 check(panel.authored_faces.button_pressed and not panel.clean_eight.button_pressed, "Approved terrain look defaults to authored faces and native shadows")
 panel.authored_faces.button_pressed = false
 panel.clean_eight.button_pressed = true
 if DisplayServer.get_name() != "headless":
  var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
  check(Options.clean_eight_enabled == forward and panel.clean_eight.disabled == (not forward),"Clean 8 availability follows the renderer")
 var terrain_settings := ConfigFile.new()
 check(terrain_settings.load(Options.settings_path) == OK and not terrain_settings.get_value("rendering","authored_faces",true) and terrain_settings.get_value("rendering","clean_eight_shadows",false), "Terrain appearance choices persist through the device controls")
 if Options.clean_eight_enabled and DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  var bands: RefCounted = lab.terrain_shadows.bands
  check(bands != null and bands.stats().receivers > 0, "Clean 8 reaches the source preview")
  var ground_synced := false
  var previous_brightness: float = panel.values["brightness/terrain_ground"]
  var previous_override: bool = panel.values["override/terrain_ground"]
  panel.set_value("override/terrain_ground",true)
  panel.set_value("brightness/terrain_ground",0.75)
  for owner: Dictionary in bands.owners.values():
   for source: ShaderMaterial in owner.materials:
    if source.get_meta("atmosphere_hue","") != "terrain_ground": continue
    var brightness: Variant = source.get_shader_parameter("atmosphere_brightness")
    ground_synced = is_equal_approx(float(brightness),0.75) and brightness == owner.materials[source].get_shader_parameter("atmosphere_brightness")
  check(ground_synced,"Live terrain palette reaches both native and Clean 8 materials")
  panel.set_value("brightness/terrain_ground",previous_brightness)
  panel.set_value("override/terrain_ground",previous_override)
 panel.authored_faces.button_pressed = true
 panel.clean_eight.button_pressed = false
 panel.settings_path = "user://device-shadow-lab-regression.cfg"
 DirAccess.make_dir_recursive_absolute("user://device-shadow-variants")
 for theme: String in Variants.THEMES:
  DirAccess.copy_absolute(Variants.new().path(theme), "user://device-shadow-variants/" + theme + ".cfg")
 panel.variants.registry.directory = "user://device-shadow-variants"
 var baseline: Dictionary = panel.values.duplicate(true)
 check(not baseline.has(Fields.LEGACY_SHADOW_MODE) and not panel.widgets.has(Fields.LEGACY_SHADOW_MODE), "New authoring excludes cascade mode")
 check(panel.review_rings == null and not lab.presentation.ring_visuals.is_empty(), "Ordinary Lab opens with live collectibles and no Ring override")
 var ring: MeshInstance3D = lab.presentation.ring_visuals[0]
 var cast := ring.cast_shadow
 check(cast != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Normal collectible retains its authored cast mode")
 var review := preload("res://scripts/diagnostics/shadow_review.gd")
 review.show_ring_shadows([ring], false)
 review.show_ring_shadows([ring], false)
 check(ring.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and ring.visible, "Review disables only Ring casting")
 review.show_ring_shadows([ring], true)
 check(ring.cast_shadow == cast and not ring.has_meta("review_cast_shadow"), "Ending comparison restores the original caster")
 for enabled: bool in [false, true]:
  for aa: bool in [false, true]:
   panel.ultra_filter.button_pressed = enabled
   panel.fxaa.button_pressed = aa
   check(Options.ultra_filter_enabled() == enabled and Options.quality().fxaa == aa, "Independent filter and FXAA state")
   check(lab.view.screen_space_aa == (Viewport.SCREEN_SPACE_AA_FXAA if aa and Options.smooth_filter_supported() else Viewport.SCREEN_SPACE_AA_DISABLED), "Actual viewport reflects only FXAA")
   check(Options.filter_quality() == (RenderingServer.SHADOW_QUALITY_SOFT_ULTRA if enabled else ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")), "Submitted filter reflects only Ultra")
 panel.msaa.item_selected.emit(panel.msaa.get_item_index(2))
 panel.native_scale.item_selected.emit(panel.native_scale.get_item_index(85))
 Options._loaded = false
 check(Options.quality().msaa == 2 and Options.quality().scale_percent == 85 and lab.view.msaa_3d == Viewport.MSAA_2X and is_equal_approx(lab.view.scaling_3d_scale, 0.85), "Lab saves MSAA and scale; both reach the 3D viewport")
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
 panel.ultra_filter.button_pressed = true
 panel.fxaa.button_pressed = true
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
  check(is_equal_approx(light.shadow_blur, 1.0) and is_zero_approx(light.light_angular_distance), "Legacy atmosphere defaults to normal radius and zero angular size")
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
 record.values["sun/shadow_blur"] = 1.5
 record.values["sun/light_angular_distance"] = 0.25
 check(registry.save("green_hill", [record], old_hash), "Explicit legacy save succeeds")
 var saved_record := registry.read("green_hill")[0]
 var saved_light := DirectionalLight3D.new()
 Runtime.new().configure("green_hill", saved_record, Environment.new(), saved_light)
 check(is_equal_approx(saved_light.shadow_blur, 1.5) and is_equal_approx(saved_light.light_angular_distance, 0.25), "Variant round-trips independent filter radius and physical sun size")
 saved_light.free()
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

func review_controls() -> void:
 Options.settings_path = "user://isolated-review-%d.cfg" % Time.get_ticks_usec()
 var lab = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(lab)
 while lab.loading_act: await process_frame
 for frame in 10: await process_frame
 var panel = lab.lighting_controls
 check(panel.review_rings != null and panel.tabs.get_current_tab_control().name == "Shadows", "Launcher opens the shadow review")
 check(panel.variants.context.selected == "default" and not paused, "Review starts live on the authored Default")
 for entry: Array in [["A · Production", "production"], ["C · 2048", "performance"], ["B · 4096", "quality"]]:
  for button: Button in panel.tabs.get_node("Shadows").find_children("*", "Button", true, false):
   if button.text == entry[0]: button.pressed.emit()
  check(Options.quality() == panel.Review.profile(entry[1]), "Live preset applies every device choice: " + entry[1])
 var phase: float = lab.presentation.ring_spin_phase
 panel.review_rings.button_pressed = false
 var ring: MeshInstance3D = lab.presentation.ring_visuals[0]
 check(ring.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Review control disables collectible casting")
 for frame in 10: await process_frame
 check(not is_equal_approx(phase, lab.presentation.ring_spin_phase), "Ring rotation advances with casting off")
 panel.review_rings.button_pressed = true
 check(ring.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not FileAccess.file_exists(Options.settings_path), "Live comparison restores Ring and leaves no device file")
 if DisplayServer.get_name() != "headless":
  var directory := "user://shadow-review-check"
  DirAccess.make_dir_recursive_absolute(directory)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(directory.path_join("appearance.png"))
  panel.tabs.get_node("Shadows").scroll_vertical = 10000
  for frame in 4: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(directory.path_join("device.png"))
 lab.free()
 await process_frame

func finish() -> void:
 print("DEVICE_SHADOWS | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
