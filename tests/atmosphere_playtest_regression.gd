extends SceneTree
## Lab capture and actual Prototype application without publishing atmosphere data.
const Lab = preload("res://experiments/lighting_lab/lighting_lab.gd")
const Snapshot = preload("res://scripts/atmosphere/playtest_snapshot.gd")
const Options = preload("res://scripts/rendering_options.gd")
const ACT := "res://data/acts/Experiments/Lockbox.tres"
class PreviewSession:
 extends "res://scripts/prototype/session.gd"
 var preview_path := ""
 func _show_menu() -> void:
  configure_act_test("res://data/acts/Experiments/Lockbox.tres", preview_path)
  start_run.call_deferred()
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func run() -> void:
 Options.settings_path = "user://atmosphere-playtest-graphics.cfg"
 Options.set_shadow_resolution(4096)
 Options.set_shadow_cascades(2)
 Options.update_quality({"ultra_filter": true, "fxaa": true})
 root.size = Vector2i(1600, 1000)
 var production := "res://data/atmospheres/green_hill.cfg"
 var before := FileAccess.get_sha256(production)
 var lab := Lab.new()
 lab.authored_act_path = ACT
 root.add_child(lab)
 for frame in 6: await process_frame
 var controls: CanvasLayer = lab.lighting_controls
 check(lab.presentation._key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Lab inherits device cascades")
 controls.set_value("env/tonemap_exposure", 0.65)
 controls.set_value("sun_yaw", -25.0)
 check(not controls.widgets.has("sun/light_angular_distance") and controls.widgets.has("sun_pitch") and controls.widgets.has("sun_yaw"), "Shadows omits PCSS angle while Light retains both sun direction controls")
 check(controls.widgets["sun/shadow_blur"].max_value == 25.0 and controls.widgets["ssao/strength"].max_value == 100.0, "Editor offers the experimental radius and SSAO ranges")
 var gain_slider: HSlider = controls.widgets["ssao/strength"].get_meta("slider")
 gain_slider.ratio = 1.0
 gain_slider.ratio = 0.0
 check(is_zero_approx(controls.values["ssao/strength"]), "Dragging the SSAO slider fully left turns contact shading off")
 controls.widgets["sun/shadow_blur"].value = 25.0
 controls.widgets["ssao/strength"].value = 100.0
 controls.widgets["ssao/radius"].value = 0.84
 controls.widgets["ssao/contrast"].value = 4.0
 var tones: OptionButton = controls.widgets["shadow/levels"]
 tones.item_selected.emit(tones.get_item_index(3))
 var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
 var preview_env: Environment = lab.presentation._world_environment.environment
 check(is_equal_approx(lab.presentation._key_light.shadow_blur, 25.0) and preview_env.ssao_enabled == forward and (not forward or is_equal_approx(preview_env.ssao_intensity, 96.1)), "Editing the widgets changes the real light and contact strength")
 check(not forward or is_equal_approx(preview_env.ssao_radius, 0.84), "The radius control changes contact width independently of intensity")
 if forward and DisplayServer.get_name() != "headless":
  var contact_menu: OptionButton = controls.widgets["ssao/levels"]
  var pixel_profile := Options.pixel_profile()
  Options.set_pixel_profile(2)
  for count: int in [4, 5]:
   contact_menu.item_selected.emit(contact_menu.get_item_index(count))
   for frame in 5: await process_frame
   var effect = lab.terrain_shadows.contact
   check(not preview_env.ssao_enabled and effect and effect.levels == count and effect.depth.depth != null and effect.receivers.inventory().receivers > 0, "Contact menu applies %d clean tones using foreground depth" % count)
  var old_size: Vector2i = root.size
  root.size = old_size - Vector2i(100, 50)
  for frame in 8: await process_frame
  check(lab.terrain_shadows.contact.depth.depth.get_size() == Vector2(lab.view.size), "Banded contacts follow a resized playfield")
  root.size = old_size
  for frame in 5: await process_frame
  Options.set_pixel_profile(0)
  for frame in 4: await process_frame
  check(preview_env.ssao_enabled and not lab.terrain_shadows.contact, "Disabling MSAA restores native SSAO")
  Options.set_pixel_profile(2)
  for frame in 5: await process_frame
  check(not preview_env.ssao_enabled and lab.terrain_shadows.contact and lab.terrain_shadows.contact.levels == 5, "Restoring MSAA resumes the selected contact tones")
  contact_menu.item_selected.emit(contact_menu.get_item_index(0))
  Options.set_pixel_profile(pixel_profile.msaa, pixel_profile.scale_percent, pixel_profile.fxaa_override)
  check(preview_env.ssao_enabled and not lab.terrain_shadows.contact, "Selecting native SSAO releases the banded contact effect")
 controls.compare.button_pressed = true
 check(preview_env.ssao_enabled == forward and (not forward or is_equal_approx(preview_env.ssao_intensity, 7.688)) and is_equal_approx(lab.presentation._key_light.shadow_blur, 10.0), "Show Original restores the approved blur and contact shading")
 controls.compare.button_pressed = false
 var request := lab.prototype_playtest_request()
 check(request.error.is_empty(), "Unsaved Lab atmosphere creates a valid user-local playtest snapshot")
 if not request.error.is_empty():
  lab.free(); quit(1); return
 var loaded := Snapshot.read_preview(request.path)
 check(loaded.error.is_empty() and loaded.preview.values == controls.values, "Snapshot preserves every current lighting and palette value")
 var args: PackedStringArray = request.arguments
 check("res://scenes/prototype_run.tscn" in args and args[args.find("--act") + 1] == ProjectSettings.globalize_path(ACT) and "--theme=green_hill" in args and ("--atmosphere-preview=" + request.path) in args, "Play passes the current Act, theme and snapshot to Prototype")
 check(lab.play_buttons.get_child(0).text == "Play Prototype", "Main Lab Play button uses Prototype")
 if DisplayServer.get_name() != "headless":
  for frame in 6: await process_frame
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute("res://test-results")
  root.get_texture().get_image().save_png("res://test-results/atmosphere-prototype-button.png")
 controls.compare.set_pressed_no_signal(true)
 var original := lab.prototype_playtest_request()
 var comparison := Snapshot.read_preview(original.path)
 check(comparison.preview.values == controls.originals, "Show original atmosphere playtests the visible comparison")
 check(not Snapshot.validation_error({"theme": "green_hill", "values": {"unsupported": 1}}).is_empty(), "Unsupported snapshot fields are rejected")
 check(FileAccess.get_sha256(production) == before, "Capturing an unsaved appearance does not publish a production variant")
 lab.free()
 for frame in 3: await process_frame
 var session := PreviewSession.new()
 session.preview_path = request.path
 session.settings_path = "user://atmosphere-playtest-%d.cfg" % Time.get_ticks_usec()
 session.archive_directory = "user://atmosphere-playtest-validation"
 root.add_child(session)
 var deadline := Time.get_ticks_msec() + 120000
 while Time.get_ticks_msec() < deadline:
  if is_instance_valid(session.game) and (session.game.started or not session.game.last_source_error.is_empty()): break
  await process_frame
 var game: Node = session.game
 check(is_instance_valid(game) and game.started, "Prototype starts the single Act with the unsaved Lab atmosphere")
 if is_instance_valid(game) and game.started:
  check(is_equal_approx(game.presentation._key_light.shadow_blur, 25.0), "Prototype applies the full experimental shadow blur")
  var world_env: Environment = game.presentation._world_environment.environment
  check(world_env.ssao_enabled == forward and (not forward or is_equal_approx(world_env.ssao_intensity, 96.1)), "Prototype applies the Lab's 100× SSAO to the playfield")
  check(not forward or is_equal_approx(world_env.ssao_radius, 0.84), "Prototype carries the selected contact radius through the snapshot")
  check(game.terrain_shadows.cast_levels == 3 and (not forward or is_equal_approx(world_env.ssao_power, 4.0)), "Prototype restores three cast tones and the native contact curve")
  check(Options.shadow_resolution() == 4096 and Options.shadow_cascades() == 2 and Options.ultra_filter_enabled(), "Prototype retains device quality from the Lab")
  check(game.presentation._key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and game.view.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "Prototype foreground inherits device cascades and FXAA")
  for background: Dictionary in game.backgrounds.values():
   check(not background.layer.atmosphere.environment.ssao_enabled, "Foreground contact shading leaves the backdrop independent")
   check(background.layer.light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and not background.layer.light.shadow_enabled and background.layer.view.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "Streamed backdrop inherits policy and remains shadowless")
  for count: int in [1, 4, 2]:
   Options.set_shadow_cascades(count)
   game._last_atmosphere_blend = Vector3(-1, -1, -1)
   game._blend_lighting(0, 0, 0.0)
   check(game.presentation._key_light.directional_shadow_mode == Options.SHADOW_CASCADES.find(count), "Runtime atmosphere blend cannot restore old cascades")
  var atmosphere = game.backgrounds[0].layer.atmosphere
  check(game.active.plan.atmosphere.values == loaded.preview.values and game.active.plan.atmosphere.id == "lab_preview", "Run planning retains the exact preview instead of selecting a weighted variant")
  check(is_equal_approx(game.presentation._world_environment.environment.tonemap_exposure, 0.65) and is_equal_approx(atmosphere.environment.tonemap_exposure, 0.65), "Foreground and background both apply the Lab exposure")
  check(game.active.runtime.goal_ring.is_visible_in_tree() and game.act_score_target == 1000 and game.practice_mode, "Preview uses Prototype Goal, score target and Practice rules")
  if DisplayServer.get_name() != "headless":
   game.ball.freeze = true
   game.ball.position = game.active.runtime.goal_ring.center + Vector2(0, 60)
   game.presentation.reset_camera(game.ball.position)
   for frame in 35: await process_frame
   await RenderingServer.frame_post_draw
   DirAccess.make_dir_recursive_absolute("res://test-results")
   root.get_texture().get_image().save_png("res://test-results/atmosphere-prototype-playtest.png")
  check(game.effective_configuration().snapshot().atmosphere_preview == loaded.preview and not FileAccess.file_exists(session.settings_path), "Telemetry identifies the preview without changing normal preferences")
 await session._close_run("validation")
 session.free()
 paused = false
 check(FileAccess.get_sha256(production) == before, "Prototype leaves production atmosphere bytes unchanged")
 # These paths are the two snapshots created by this fixture.
 DirAccess.remove_absolute(request.path)
 DirAccess.remove_absolute(original.path)
 print("RESULT | Atmosphere Prototype playtest | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
