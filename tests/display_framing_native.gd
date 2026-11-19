extends "res://tests/display_framing_matrix.gd"
## Actual native-window F11 and engine-local pointer checks; no OS cursor control.
var pointer_presses := 0

func run() -> void:
 output = "res://test-results/display-framing/native"
 DirAccess.make_dir_recursive_absolute(output)
 window = root
 var secondary := 0
 for index in DisplayServer.get_screen_count():
  if index != DisplayServer.get_primary_screen():
   secondary = index
   break
 root.current_screen = secondary
 root.position = DisplayServer.screen_get_position(secondary)+Vector2i(20,30)
 root.size = Vector2i(1280,720)
 # Keep only this test's monitor-2 client rectangle unoccluded for readback.
 root.always_on_top = true
 root.grab_focus()
 preload("res://scripts/rendering_options.gd").settings_path = output.path_join("isolated-graphics.cfg")
 for mode: String in ["prototype","endless"]: await native_mode(mode,secondary)
 FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"screen":secondary},"  "))
 print("RESULT | Native display input/fullscreen | %d checks | %d failures" % [checks,failures])
 quit(1 if failures else 0)

func native_mode(mode: String, secondary: int) -> void:
 paused = false
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED # Editor-style caller.
 root.content_scale_size = Vector2i(1280,900)
 root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
 var session: Control
 var game: Node
 if mode == "prototype":
  session = Session.new()
  session.settings_path = output.path_join("isolated-session.cfg")
  session.archive_directory = output.path_join("isolated-telemetry")
  session.configure_act_test(ACT)
  session.run_configuration.single_act_use_bakes = true
  session.run_configuration.atmosphere_overrides = {"green_hill":"default"}
  session.sound_enabled = false
  root.add_child(session)
  await session._start_configured_run(session.run_configuration,session.selected_character,session.practice_mode,18)
  game = session.game
 else:
  game = Stream.new()
  root.add_child(game)
 check(await wait_started(game),mode+" starts")
 if not game.started: return
 game._update_hud(0.0)
 paused = true
 game.set_process(false)
 game.set_physics_process(false)
 game.presentation.set_process(false)
 game.ball.freeze = true
 game.auto_launch_time = -1.0
 if session != null:
  session.set_process(false)
  session.overlay_root.hide()
  game.fps_label.hide()
 Report.disable_native_input(game)
 var frozen := [game.ball.position,game.ball.linear_velocity,game.score,game.active_sequence]
 var target := Button.new()
 target.text = "Pointer diagnostic"
 target.position = Vector2(1100,100)
 target.size = Vector2(190,60)
 target.process_mode = Node.PROCESS_MODE_ALWAYS
 target.pressed.connect(func(): pointer_presses += 1)
 game.hud.add_child(target)
 var references := {}
 var cases := ["720p","900p","4x3","ultrawide","legacy-window","fullscreen","restored"]
 var sizes := [Vector2i(1280,720),Vector2i(1600,900),Vector2i(960,720),Vector2i(1440,600),Vector2i(1280,900)]
 for index in cases.size():
  if index < sizes.size(): root.size = sizes[index]
  else:
   var key := InputEventKey.new()
   key.keycode = KEY_F11
   key.pressed = true
   if session != null: session._unhandled_key_input(key)
   else: game._unhandled_key_input(key)
  await frames(12)
  check(root.current_screen == secondary,"Native window remains on monitor 2")
  check(root.get_visible_rect().size == Vector2(1600,900),"Native gameplay canvas remains fixed")
  check(root.mode == (Window.MODE_FULLSCREEN if index == 5 else Window.MODE_WINDOWED),"Actual fullscreen/windowed mode")
  for preset: int in game.PLAY_CAMERAS:
   game.presentation.set_camera_preset(preset)
   game._update_backgrounds()
   await frames(3)
   var row := measure(game,mode,root.size,preset,true)
   if not references.has(preset): references[preset] = row
   row["case"] = cases[index]
   row["max_landmark_delta"] = landmark_delta(references[preset].landmarks,row.landmarks)
   check(row.max_landmark_delta < 0.00001,"Native camera framing survives resize/F11")
   records.append(row)
  var before := pointer_presses
  var point: Vector2 = root.get_final_transform()*target.get_global_rect().get_center()
  click(point)
  await frames(2)
  check(pointer_presses == before+1,"Physical pointer maps to HUD through bars and scaling")
  var fitted := Rect2(root.get_final_transform()*Vector2.ZERO,root.get_final_transform().basis_xform(Vector2(1600,900)))
  if not fitted.has_point(Vector2(2,2)):
   click(Vector2(2,2))
   await frames(2)
   check(pointer_presses == before+1,"Black-bar pointer cannot activate HUD")
  if session != null:
   var projected: Vector2 = game.presentation.camera.unproject_position(TablePresentation.map_point(game.ball.position,game.presentation.ball_height()))/Vector2(game.view.size)*Vector2(1600,900)
   check(game.score_overlay.screen_point(game.ball.position,game.presentation.ball_height()).distance_to(projected)<0.01,"Score feedback aligns with world projection")
   check(Rect2(Vector2.ZERO,Vector2(1600,900)).encloses(game.player_hud.get_rect()),"HUD remains inside gameplay canvas")
  await overview_input(game)
  check(frozen == [game.ball.position,game.ball.linear_velocity,game.score,game.active_sequence],"Display/input checks never advance gameplay")
  target.hide()
  game.presentation.set_camera_preset(game.PLAY_CAMERAS[0])
  game._update_backgrounds()
  await frames(3)
  await RenderingServer.frame_post_draw
  # Window viewport readback excludes OS-composited bars. Capture only this
  # native client rectangle, which is wholly inside the secondary monitor.
  var monitor := Rect2i(DisplayServer.screen_get_position(secondary),DisplayServer.screen_get_size(secondary))
  var client := Rect2i(root.position,root.size)
  check(monitor.encloses(client),"Capture stays within monitor 2")
  var image := DisplayServer.screen_get_image_rect(client)
  check(image != null and image.get_size()==root.size,"Native client capture includes the full display fit")
  if image != null:
   if fitted.position.x > 2.0 or fitted.position.y > 2.0:
    var bar := Vector2i(int(fitted.position.x/2.0),root.size.y/2) if fitted.position.x>2.0 else Vector2i(root.size.x/2,int(fitted.position.y/2.0))
    var color := image.get_pixelv(bar)
    check(maxf(color.r,maxf(color.g,color.b))<0.02,"Native letterbox/pillarbox is black")
   image.save_jpg(output.path_join(mode+"-"+cases[index]+".jpg"),0.87)
  target.show()
 if session != null:
  session.archive_attempted = true
  await session._close_run("display_native")
  session.free()
 else:
  await game.prepare_to_close()
  game.free()
 await frames(2)
 check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED,"Leaving gameplay restores editor scaling")
 check(root.content_scale_size == Vector2i(1280,900),"Leaving gameplay restores caller reference")
 paused = false

func click(point: Vector2) -> void:
 for down: bool in [true,false]:
  var event := InputEventMouseButton.new()
  event.position = point
  event.global_position = point
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = down
  root.push_input(event,false)

func overview_input(game: Node) -> void:
 var p: Node = game.presentation
 p.set_camera_follow(false)
 var point := Vector2(800,450)
 var mapped := point*Vector2(game.view.size)/Vector2(1600,900)
 var anchored: Vector2 = p._overview_floor_point(mapped)
 game.controls.input_blocked = false
 var wheel := InputEventMouseButton.new()
 wheel.position = point
 wheel.button_index = MOUSE_BUTTON_WHEEL_UP
 wheel.pressed = true
 game._unhandled_input(wheel)
 check(is_equal_approx(p.overview_zoom,1.15),"Overview wheel reaches existing camera handler")
 check(p._overview_floor_point(mapped).distance_to(anchored)<0.01,"Overview zoom retains pointer floor anchor")
 wheel.position = Vector2(-20,-20)
 game._unhandled_input(wheel)
 check(is_equal_approx(p.overview_zoom,1.15),"Outside gameplay canvas cannot steer overview")
 var motion := InputEventMouseMotion.new()
 motion.position = point+Vector2(40,20)
 motion.relative = Vector2(40,20)
 motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
 var previous_floor: Vector2 = p._overview_floor_point(mapped)
 game._unhandled_input(motion)
 var dragged := motion.position*Vector2(game.view.size)/Vector2(1600,900)
 check(p._overview_floor_point(dragged).distance_to(previous_floor)<0.01,"Overview drag maps relative motion without scaling drift")
 game.controls.input_blocked = true
 p.set_camera_follow(true)
