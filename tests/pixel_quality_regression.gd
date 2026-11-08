extends SceneTree
## Device-owned, unsaved pixel controls; layout, atmosphere and gameplay stay intact.
const Options = preload("res://scripts/rendering_options.gd")
const Session = preload("res://scripts/prototype/session.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value: failures += 1; push_error(label)

func run() -> void:
 Options.settings_path = "user://pixel-quality-regression.cfg"
 if FileAccess.file_exists(Options.settings_path): DirAccess.remove_absolute(Options.settings_path)
 var world := SubViewport.new()
 world.size = Vector2i(673, 473)
 root.add_child(world)
 Options.register_view(world)
 check(world.msaa_3d == Viewport.MSAA_4X and world.scaling_3d_scale == 1.0, "Absent overrides retain 4x/full-scale defaults")
 var original := Options.pixel_profile()
 check(Options.set_pixel_profile(8, 100) == ERR_INVALID_PARAMETER and Options.set_pixel_profile(2, 80) == ERR_INVALID_PARAMETER and Options.set_pixel_profile(2, 85, 2) == ERR_INVALID_PARAMETER and Options.pixel_profile() == original, "Invalid combinations are rejected atomically")
 var light := DirectionalLight3D.new()
 Options.register_light(light)
 var shadows := [Options.shadow_resolution(), Options.shadow_cascades(), Options.smooth_shadows_enabled(), light.directional_shadow_mode]
 for samples: int in Options.PROFILE_MSAA:
  for scale_percent: int in Options.PROFILE_SCALES:
   check(Options.set_pixel_profile(samples, scale_percent) == OK, "Supported live profile applies")
   var late := SubViewport.new()
   Options.register_view(late)
   check(world.msaa_3d == {0:0, 2:1, 4:2}[samples] and late.msaa_3d == world.msaa_3d and is_equal_approx(late.scaling_3d_scale, scale_percent / 100.0), "Existing and late viewports inherit the same pixel profile")
   check(world.size == Vector2i(673, 473) and shadows == [Options.shadow_resolution(), Options.shadow_cascades(), Options.smooth_shadows_enabled(), light.directional_shadow_mode], "Pixel switching leaves layout and all shadow choices intact")
   late.free()
 check(not FileAccess.file_exists(Options.settings_path), "Profile controls never write graphics preferences")
 Options.set_pixel_profile(2, 100, 1)
 check(not Options.smooth_shadows_enabled() and (world.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA if Options.smooth_filter_supported() else world.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED), "FXAA-only visual probe does not enable Ultra shadows")
 Options.set_pixel_profile(4, 100)
 var controls := preload("res://scripts/pixel_profile_controls.gd").new()
 root.add_child(controls)
 var key := InputEventKey.new()
 key.pressed = true
 key.keycode = KEY_F6
 controls._unhandled_key_input(key)
 check(Options.pixel_profile().msaa == 0 and world.msaa_3d == Viewport.MSAA_DISABLED, "F6 cycles live MSAA and updates registered views")
 key.keycode = KEY_F7
 controls._unhandled_key_input(key)
 check(Options.pixel_profile().scale_percent == 75 and world.scaling_3d_scale == 0.75, "F7 cycles native 3D scale")
 key.echo = true
 controls._unhandled_key_input(key)
 check(Options.pixel_profile().scale_percent == 75, "Held keys do not repeatedly switch profiles")
 controls.free()
 Options.set_pixel_profile(4, 100)
 world.free()
 light.free()
 if "--unit-only" not in OS.get_cmdline_user_args():
  for route in ["source", "disk", "endless"]: await route_check(route)
 Options.set_pixel_profile(4, 100)
 print("PIXEL_QUALITY | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func route_check(route: String) -> void:
 var session: Control
 var game: Node
 if route == "endless":
  game = preload("res://scripts/endless/endless_game.gd").new()
  root.add_child(game)
 else:
  session = Session.new()
  session.settings_path = "user://pixel-quality-session.cfg"
  session.archive_attempted = true
  session.configure_act_test("res://data/acts/Authored/First Try Smooth Decor.tres")
  session.run_configuration.single_act_use_bakes = route == "disk"
  session.sound_enabled = false
  root.add_child(session)
  await session.start_run()
  game = session.game
 var deadline := Time.get_ticks_msec() + 180000
 while not game.started and game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
 check(game.started, "Starts supported route: " + route)
 if game.started:
  for frame in 45: await process_frame
  paused = true
  game.set_process(false)
  game.presentation.set_process(false)
  var before := [game.view.size, game._composite_view.size, game.ball.get_instance_id(), game.ball.position, game.score, game.presentation.camera.global_transform, game.run_seed]
  for samples: int in Options.PROFILE_MSAA:
   Options.set_pixel_profile(samples, 85)
   for frame in 3: await process_frame
   var match_views: bool = game.view.msaa_3d == {0:0, 2:1, 4:2}[samples] and is_equal_approx(game.view.scaling_3d_scale, 0.85)
   for backdrop: Dictionary in game.backgrounds.values():
    match_views = match_views and backdrop.layer.view.msaa_3d == game.view.msaa_3d and is_equal_approx(backdrop.layer.view.scaling_3d_scale, 0.85)
   check(match_views and game.library._view.msaa_3d == game.view.msaa_3d, "World, scenery and warm-up share live ownership: " + route)
   check(before == [game.view.size, game._composite_view.size, game.ball.get_instance_id(), game.ball.position, game.score, game.presentation.camera.global_transform, game.run_seed], "Live switching preserves exact layout, camera and gameplay: " + route)
  check(root.scaling_3d_scale == 1.0 and game._composite_view.scaling_3d_scale == 1.0 and game._composite_view.disable_3d, "HUD/compositor are excluded: " + route)
  Options.set_pixel_profile(4, 100)
 paused = false
 if session != null:
  session.archive_attempted = true
  await session._close_run("pixel_test")
  session.free()
 else:
  await game.prepare_to_close()
  game.free()
