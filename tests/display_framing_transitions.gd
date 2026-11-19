extends "res://tests/display_framing_matrix.gd"
## The actual two-Zone composition, at identical seam coordinates and display aspects.
func run() -> void:
 output = "res://test-results/display-framing/transitions"
 DirAccess.make_dir_recursive_absolute(output)
 root.size = Vector2i(960,540)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.gui_embed_subwindows = true
 preload("res://scripts/rendering_options.gd").settings_path = output.path_join("isolated-graphics.cfg")
 for mode: String in ["prototype","endless"]: await inspect_transition(mode)
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "))
 print("RESULT | Display framing Zone transitions | %d checks | %d failures" % [checks,failures])
 quit(1 if failures else 0)

func inspect_transition(mode: String) -> void:
 paused = false
 window = Window.new()
 window.size = Vector2i(1280,720)
 window.content_scale_size = Vector2i(1280,900)
 window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
 root.add_child(window)
 window.show()
 var session: Control
 var game: Node
 if mode == "prototype":
  session = Session.new()
  session.settings_path = output.path_join("isolated-session.cfg")
  session.archive_directory = output.path_join("isolated-telemetry")
  session.sound_enabled = false
  session.run_configuration = Session.Run.RunPlan.Configuration.new([ACT,"res://data/acts/Authored/RampMania.tres","res://data/acts/Authored/SpringUp.tres"])
  session.run_configuration.zone_count = 2
  session.run_configuration.selected_theme_ids = ["green_hill","casino_night"]
  session.run_configuration.atmosphere_overrides = {"green_hill":"default","casino_night":"default"}
  window.add_child(session)
  while session.setup_menu.checking: await process_frame
  await session.start_run()
  game = session.game
 else:
  game = Stream.new()
  window.add_child(game)
 var deadline := Time.get_ticks_msec()+180000
 while Time.get_ticks_msec()<deadline and (not game.started or not game._zone_ready(1) or game.resident.size()<6): await process_frame
 check(game.started and game._zone_ready(1) and game.resident.size()==6,"Six real disk-backed Acts and two Zone layers")
 if not game._zone_ready(1): return
 game._update_hud(0.0)
 paused = true
 if session != null:
  session.set_process(false)
  session.overlay_root.hide()
  game.fps_label.hide()
 game.set_process(false)
 game.set_physics_process(false)
 game.presentation.set_process(false)
 game.ball.freeze = true
 game.auto_launch_time = -1.0
 Report.disable_native_input(game)
 var state := [game.ball.position,game.ball.linear_velocity,game.score,game.active_sequence]
 var identities := [game.ball.get_instance_id(),game.presentation.camera.get_instance_id()]
 var references := {}
 for size: Vector2i in [Vector2i(1280,720),Vector2i(3440,1440),Vector2i(1600,1200)]:
  window.size = size
  await frames()
  for fraction: float in [0.0,0.25,0.5,0.75,1.0,0.5,0.0]:
   game._background_zone = 0
   game._last_atmosphere_blend = Vector3(-1,-1,-1)
   var focus := Vector2(game.resident[3].spawn().x,game.backgrounds[1].entrance_y+200.0-fraction*450.0)
   game.presentation.touring = true
   game.presentation.tour_focus = focus
   game.presentation._update_camera(0.0)
   game._update_backgrounds()
   await frames(4)
   check(is_equal_approx(game.background_blend,smoothstep(0.0,1.0,fraction)),"Distance-owned crossfade and reversal remain exact")
   check(game.view.size==game._composite_view.size,"Seam foreground/composite align")
   for background: Dictionary in game.backgrounds.values():
    check(background.layer.view.size==game.view.size,"Both Zone resolutions align")
    check(background.layer.camera.global_transform.is_equal_approx(game.presentation.camera.global_transform),"Both Zone cameras align")
    check(background.layer.camera.projection==game.presentation.camera.projection and background.layer.camera.keep_aspect==game.presentation.camera.keep_aspect,"Both Zone projections align")
   var environment: Environment = game.presentation._world_environment.environment
   var row := {"mode":mode,"size":size,"fraction":fraction,"blend":game.background_blend,"camera":str(game.presentation.camera.global_transform),"exposure":environment.tonemap_exposure,"ambient":environment.ambient_light_color,"world":game.view.size,"logical":window.get_visible_rect().size}
   if not references.has(fraction): references[fraction]=row
   var reference: Dictionary = references[fraction]
   check(row.camera==reference.camera and row.world==reference.world and row.logical==reference.logical,"Seam composition survives aspect changes")
   check(row.exposure==reference.exposure and row.ambient==reference.ambient,"Atmosphere blend independent of display")
   check(state==[game.ball.position,game.ball.linear_velocity,game.score,game.active_sequence],"Seam probe preserves gameplay state")
   check(identities==[game.ball.get_instance_id(),game.presentation.camera.get_instance_id()],"No ball/camera replacement")
   check(game.library.fallback_builds==0,"Seam uses existing disk recipes")
   if fraction==0.5 and size==Vector2i(3440,1440):
    row["image"] = mode+"-ultrawide-seam.jpg"
    await capture(row.image,size)
   records.append(row)
 if session!=null:
  session.archive_attempted = true
  await session._close_run("display_seam")
  session.free()
 else:
  await game.prepare_to_close()
  game.free()
 window.free()
 paused=false
 await frames(2)
