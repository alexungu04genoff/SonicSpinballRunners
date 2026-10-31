extends SceneTree
## Rendered smoke for live controls, reversible presets and the existing camera adapter.
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(condition: bool, description: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error(description)

func run() -> void:
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(game)
 paused = true
 for frame in 12: await process_frame
 var panel = game.lighting_controls
 panel.settings_path = "user://lighting_lab_smoke.cfg"
 panel.saved = ConfigFile.new()
 panel.drafts.clear()
 panel.reset_values()
 var initial_ball: Vector2 = game.ball.position
 var initial_score: int = game.score
 var world_id: int = game.world.get_instance_id()
 var original_exposure: float = panel.originals["env/tonemap_exposure"]
 panel.widgets["env/tonemap_exposure"].value = 0.72
 check(is_equal_approx(game.presentation._world_environment.environment.tonemap_exposure, 0.72), "Exposure control updates the live environment")
 panel.widgets["sun/light_energy"].value = 0.65
 panel.widgets["sun/shadow_bias"].value = 0.22
 panel.widgets["env/fog_enabled"].button_pressed = true
 panel.widgets["env/fog_density"].value = 0.0015
 check(is_equal_approx(game.presentation._key_light.light_energy, 0.65), "Directional energy is live")
 check(is_equal_approx(game.presentation._key_light.shadow_bias, 0.22), "Shadow bias is live")
 check(game.presentation._world_environment.environment.fog_enabled, "Fog toggle is live")
 panel.compare.button_pressed = true
 check(is_equal_approx(game.presentation._world_environment.environment.tonemap_exposure, original_exposure), "Original comparison restores baseline")
 panel.compare.button_pressed = false
 check(is_equal_approx(game.presentation._world_environment.environment.tonemap_exposure, 0.72), "Tuned comparison restores draft")
 var other_window := ConfigFile.new()
 other_window.set_value("other_renderer/green_hill", "values", {"env/tonemap_exposure": 1.27})
 other_window.save(panel.settings_path)
 panel.save_preset()
 var merged := ConfigFile.new()
 merged.load(panel.settings_path)
 check(merged.get_value("other_renderer/green_hill", "values", {}).get("env/tonemap_exposure") == 1.27, "Saving preserves another renderer window's preset")
 panel.set_value("env/tonemap_exposure", 1.31)
 panel.reload_preset()
 check(is_equal_approx(game.presentation._world_environment.environment.tonemap_exposure, 0.72), "Saved preset reloads")
 check(panel.preset_key.begins_with(RenderingServer.get_current_rendering_method() + "/"), "Preset is scoped to actual renderer")
 panel.reset_values()
 check(is_equal_approx(game.presentation._world_environment.environment.tonemap_exposure, original_exposure), "Reset restores baseline without saving")
 panel.set_value("env/tonemap_exposure", 0.83)
 check(game.set_theme("aquarium_park"), "Switch to Aquarium")
 check(not is_equal_approx(game.presentation._world_environment.environment.tonemap_exposure, 0.83), "Unsaved exposure does not leak across themes")
 check(game.set_theme("green_hill"), "Switch back to Green Hill")
 check(is_equal_approx(game.presentation._world_environment.environment.tonemap_exposure, 0.83), "Unsaved theme draft survives switch")
 panel.reset_values()
 game.presentation.set_camera_follow(true)
 var wheel := InputEventMouseButton.new()
 wheel.button_index = MOUSE_BUTTON_WHEEL_UP
 wheel.pressed = true
 wheel.position = game.view_container.get_global_rect().get_center()
 game._unhandled_input(wheel)
 check(not game.presentation.camera_follow_enabled and game.presentation.overview_zoom > 1.0, "Wheel enters overview and zooms")
 var focus: Vector2 = game.presentation.camera_focus
 var drag := InputEventMouseMotion.new()
 drag.position = wheel.position + Vector2(50, 25)
 drag.relative = Vector2(50, 25)
 drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
 game._unhandled_input(drag)
 check(game.presentation.camera_focus.distance_to(focus) > 0.1, "Middle drag pans the camera")
 panel.toggle_panel()
 check(not panel.panel.visible and panel.reopen.visible, "Panel hides with a reopen button")
 panel.toggle_panel()
 check(panel.panel.visible, "Panel reopens")
 var directory := "res://test-results/lighting-lab/" + RenderingServer.get_current_rendering_method()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 for theme: String in game.ThemeRegistry.IDS:
  check(game.set_theme(theme), "Theme loads: " + theme)
  check(game.world.get_instance_id() == world_id and game.ball.position == initial_ball and game.score == initial_score, "Lighting changes preserve physics and score: " + theme)
  panel.set_value("emission", 0.4)
  var emission_matches := true
  for entry: Dictionary in panel.emission.parameters:
   var actual = entry.material.get_shader_parameter(entry.property) if entry.shader else entry.material.get(entry.property)
   emission_matches = emission_matches and is_equal_approx(float(actual), float(entry.base) * 0.4)
  check(emission_matches and not panel.emission.parameters.is_empty(), "Emission controls reach live materials: " + theme)
  if theme == "aquarium_park":
   check(is_equal_approx(game.presentation._world_environment.environment.tonemap_exposure, 1.0), "Chemical exposure does not leak into Aquarium's original")
   check(not game.presentation._world_environment.environment.fog_enabled, "Prior theme fog does not leak into Aquarium")
  panel.reset_values()
  game.presentation.set_camera_follow(true)
  game.presentation.set_camera_follow(false)
  for frame in 12: await process_frame
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(directory.path_join(theme + ".png"))
 check(Engine.physics_ticks_per_second == 120, "Authoritative physics remains 120 Hz")
 panel.restore_original()
 game.free()
 paused = false
 print("LIGHTING_LAB_SMOKE | ", checks - failures, "/", checks, " checks passed")
 quit(0 if failures == 0 else 1)
