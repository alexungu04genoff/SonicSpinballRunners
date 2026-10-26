extends SceneTree
## Deterministic camera observations plus real window/HUD round trips.
var game: Node
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, label: String) -> void:
 checks += 1
 if ok:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func frames(count := 4) -> void:
 for _i in count:
  await process_frame

func key(code: Key) -> void:
 var event := InputEventKey.new()
 event.physical_keycode = code
 event.keycode = code
 event.pressed = true
 root.push_input(event, true)
 event = event.duplicate()
 event.pressed = false
 root.push_input(event, true)
 await frames()

func capture(name: String) -> void:
 if DisplayServer.get_name() == "headless":
  return
 game.presentation._process(0.0)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/player-view-" + name + ".png")

func camera_probe(speed: float, rate: int) -> bool:
 var p: TablePresentation = game.presentation
 var bounds := p.table_bounds
 var start := Vector2(bounds.get_center().x, bounds.end.y - bounds.size.y * 0.12)
 game.ball.position = start
 p.reset_camera(start)
 var distance := bounds.size.y * 0.78
 var steps := maxi(2, ceili(distance / absf(speed) * rate))
 for i in steps:
  game.ball.position = start + Vector2(0, -distance * float(i + 1) / steps)
  p._update_camera(1.0 / rate)
  var screen := p.camera.unproject_position(TablePresentation.map_point(game.ball.position, p.ball_height())) / Vector2(game.view.size)
  if p.camera.is_position_behind(TablePresentation.map_point(game.ball.position, p.ball_height())) or screen.y < 0.219 or screen.y > 0.781 or screen.x < 0.119 or screen.x > 0.881:
   print("CAMERA PROBE | ", speed, " px/s @ ", rate, " Hz | screen ", screen)
   return false
 # A 200 ms hitch must not let a shot escape the safe frame either.
 game.ball.position += Vector2(0, speed * 0.2)
 p._update_camera(0.2)
 var screen := p.camera.unproject_position(TablePresentation.map_point(game.ball.position, p.ball_height())) / Vector2(game.view.size)
 return screen.y >= 0.219 and screen.y <= 0.781

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 root.add_child(game)
 await frames(12)
 paused = true
 game.ball.freeze = true
 var p: TablePresentation = game.presentation
 p.set_process(false)
 var gameplay := [game.score, game.rings_collected, game.tuning.effective.duplicate(true), game.authored_document.fingerprint()]
 var modes := [false, true]
 for debug_mode in modes:
  if game.debug_open != debug_mode:
   game.toggle_debug()
  game.retro_controls.tuning_panel.show()
  p.physics_overlay.show()
  p.construction_grid_overlay.show()
  p.set_camera_follow(true)
  check(camera_probe(-8000.0, 60), "Fast upward launch stays visible in Development View " + str(debug_mode))
  p.set_camera_follow(false)
  var offsets := Vector4(game.view_container.offset_left, game.view_container.offset_top, game.view_container.offset_right, game.view_container.offset_bottom)
  var prior_mode := DisplayServer.window_get_mode()
  var prior_size := DisplayServer.window_get_size()
  var prior_position := DisplayServer.window_get_position()
  var prior_aspect := root.content_scale_aspect
  await key(KEY_F11)
  await frames(20)
  check(game.player_view and p.camera_follow_enabled, "F11 enables Player View and following from development mode " + str(debug_mode))
  check(DisplayServer.get_name() == "headless" or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Native fullscreen enabled")
  check(not game.development_footer.is_visible_in_tree() and not game.debug_panel.visible and not game.retro_controls.visible and not game.debug_panel.act_controls.get_child(0).is_visible_in_tree() and not game.debug_panel.act_controls.character_panel.combo_hud.toggle.is_visible_in_tree(), "All toolbars, source controls, tuning, retro and character development controls hidden")
  check(not p.physics_overlay.visible and not p.construction_grid_overlay.visible and game.score_label_lab.is_visible_in_tree() and game.debug_panel.act_controls.character_panel.is_visible_in_tree(), "Debug geometry hidden; score, specials and Scorecraft HUD retained")
  check(game.view_container.get_rect().size.is_equal_approx(root.get_visible_rect().size) and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Gameplay fills the available viewport with uniform root scaling")
  for shortcut in [KEY_F1, KEY_F4, KEY_O, KEY_C]:
   await key(shortcut)
  check(not game.debug_panel.visible and not game.retro_controls.visible and not game.close_view and p.camera_follow_enabled, "Development shortcuts cannot leak tools or overview into Player View")
  for preset in 3:
   p.set_camera_preset(preset)
   for zoom in [1.0, 2.0, 2.5]:
    p.set_camera_value("zoom", zoom)
    var visible := true
    for rate in [30, 60, 120]:
     visible = camera_probe(-8000.0, rate) and visible
    check(visible, "Fast upward launch and 200 ms hitch remain in safe frame: preset %d, zoom %.1f" % [preset, zoom])
  p.set_camera_preset(TablePresentation.CameraPreset.DRAMATIC_PINBALL)
  p.set_camera_value("zoom", 2.0)
  game.ball.position = p.table_bounds.get_center()
  p.reset_camera()
  var stationary := p.camera_focus
  for tick in 60:
   game.ball.position.x = p.table_bounds.get_center().x + (1.0 if tick % 2 else -1.0)
   p._update_camera(1.0 / 60.0)
  check(absf(p.camera_focus.x - stationary.x) < 0.01, "Tiny alternating lateral observations produce no camera jitter")
  var projected := p.camera.unproject_position(TablePresentation.map_point(game.ball.position, p.ball_height())) / Vector2(game.view.size)
  check(absf(projected.y - 0.38) < 0.025, "Settled ball sits in the upper-middle of the playable view")
  await capture("fullscreen")
  await key(KEY_F11)
  await frames(20)
  check(not game.player_view and game.debug_open == debug_mode and game.debug_panel.visible == debug_mode and game.lab_ui.visible != debug_mode and game.retro_controls.visible and game.retro_controls.tuning_panel.visible, "F11 restores development visibility including an open Retro panel")
  check(Vector4(game.view_container.offset_left, game.view_container.offset_top, game.view_container.offset_right, game.view_container.offset_bottom) == offsets and root.content_scale_aspect == prior_aspect and not p.camera_follow_enabled and p.physics_overlay.visible and p.construction_grid_overlay.visible, "Viewport, aspect mode, overview and overlay preferences restored")
  check(DisplayServer.get_name() == "headless" or (DisplayServer.window_get_mode() == prior_mode and DisplayServer.window_get_size() == prior_size and DisplayServer.window_get_position() == prior_position), "Exact native window mode, size and position restored")
 check(gameplay == [game.score, game.rings_collected, game.tuning.effective, game.authored_document.fingerprint()], "View switches and camera probes leave score, physics tuning and geometry unchanged")
 game.retro_controls.tuning_panel.hide()
 if game.debug_open:
  game.toggle_debug()
 game._set_close_view(true)
 await key(KEY_F11)
 check(game.player_view and not game.close_view and p.camera_follow_enabled, "Player View leaves character study for the gameplay camera")
 await key(KEY_F11)
 check(game.close_view and paused, "Development character study and pause state restore on exit")
 game._set_close_view(false)
 if DisplayServer.get_name() != "headless":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
  await frames(20)
  await key(KEY_F11)
  await key(KEY_F11)
  await frames(20)
  check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED, "F11 also restores a maximized development window")
 p.set_camera_follow(true)
 # Exercise the same camera at authored scale through the production loader.
 check(game.request_authored_act("res://data/acts/playtest_showcase.tres"), "Load authored fixture through the normal game")
 await frames(15)
 await key(KEY_F11)
 check(camera_probe(-8000.0, 60), "Authored-scale fast upward launch stays visible in Player View")
 await capture("authored")
 # Actual launch integration: leave the body live and observe each rendered frame.
 game.ball.freeze = false
 game.reset_ball(false)
 game.ball.teleport_to(p.table_bounds.get_center(), Vector2(0, -1800), false)
 p.reset_camera(p.table_bounds.get_center())
 paused = false
 p.set_process(true)
 var visible := true
 var rising := false
 var screen_range := Vector2(1, 0)
 for _i in 90:
  await physics_frame
  # Timers run after node processing, so sample the camera used for this frame.
  await create_timer(0.001).timeout
  rising = rising or game.ball.linear_velocity.y < -200.0
  var projected := p.camera.unproject_position(TablePresentation.map_point(game.ball.position, p.ball_height())) / Vector2(game.view.size)
  visible = visible and projected.y > 0.05 and projected.y < 0.95
  screen_range = Vector2(minf(screen_range.x, projected.y), maxf(screen_range.y, projected.y))
 print("LIVE LAUNCH | rising=", rising, " | normalized screen Y range=", screen_range)
 check(rising and visible, "Live physics upward launch stays visible across 90 rendered frames")
 await capture("live-launch")
 await key(KEY_F11)
 print("RESULT | Player View | %d checks | %d failures" % [checks, failures])
 paused = false
 game.queue_free()
 await frames()
 quit(0 if failures == 0 else 1)
