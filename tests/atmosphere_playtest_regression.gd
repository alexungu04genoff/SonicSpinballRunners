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
 Options.set_smooth_shadows(true)
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
  check(Options.shadow_resolution() == 4096 and Options.shadow_cascades() == 2 and Options.smooth_shadows_enabled(), "Prototype retains device quality from the Lab")
  check(game.presentation._key_light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and game.view.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "Prototype foreground inherits device cascades and FXAA")
  for background: Dictionary in game.backgrounds.values():
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
