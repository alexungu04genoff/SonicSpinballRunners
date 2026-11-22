extends "res://tests/act_game_fixture.gd"
## Exercise the shared Speed action with the actual Prototype presenter and body.
const Session = preload("res://scripts/prototype/session.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
var expected_boost_setting := 1.5

func run() -> void:
 Review.position_review_window(root)
 var directory := "res://test-results/target-boost/%d" % OS.get_process_id()
 DirAccess.make_dir_recursive_absolute(directory)
 var act := Document.new()
 act.title = "Target Boost Review"
 act.grid_size = Vector2i(20, 20)
 act.spawn_position = Vector2(500, 900)
 act.exit_start_x = 9
 act.exit_width = 2
 var bumper := Objects.make_placement("round_bumper")
 bumper.position = Vector2(500, 450)
 var panel := Objects.make_placement("dash_panel")
 panel.position = Vector2(220, 700)
 var loop := Objects.make_placement("sonic_loop")
 loop.position = Vector2(220, 580)
 loop.properties.direction = "clockwise"
 act.gameplay_objects = [bumper, panel, loop]
 var path := directory.path_join("target.tres")
 check(act.save_document(path) == OK, "Save test Act with one clear bumper")
 var session := Session.new()
 session.settings_path = directory.path_join("session.cfg")
 session.archive_directory = directory
 root.add_child(session)
 session.configure_act_test(path)
 await session._start_configured_run(session.run_configuration, "sonic", true, 18)
 game = session.game
 var deadline := Time.get_ticks_msec() + 90000
 while Time.get_ticks_msec() < deadline:
  if not is_instance_valid(game) or game.started or not game.last_source_error.is_empty(): break
  await process_frame
 check(is_instance_valid(game) and game.started, "Start actual Prototype")
 if is_instance_valid(game) and game.started:
  game.auto_launch_time = -1.0
  game.controls.virtual_enabled = true
  for id: String in CharacterSpecials.CHARACTER_IDS:
   await review_panel_and_loop(id, panel.position)
  for id: String in ["sonic", "shadow", "amy"]:
   await review_character(id, session)
 session.archive_attempted = true
 await session._close_run("review")
 session.free()
 print("RESULT | Target Boost | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func review_panel_and_loop(id: String, panel: Vector2) -> void:
 game.specials.select_character(id)
 var pose = game.combo_celebration.character_pose
 if not pose.motion_rig:
  check("--require-runners-set" not in OS.get_cmdline_user_args(), id + " has local Boost art")
  return
 game.ball.teleport_to(panel + Vector2.DOWN * 65.0, Vector2.UP * 820.0)
 for i in 40:
  await frames(1)
  if pose.motion == &"dash_panel": break
 var player: AnimationPlayer = pose.motion_player
 check(pose.motion == &"dash_panel" and player.current_animation == pose.Assets.BOOST[id] and is_equal_approx(player.current_animation_length / player.get_playing_speed(), 8.0 / 27.0), id + " hits a dash panel at Sonic's preview stride period")
 for i in 100:
  if game.ball.in_loop: break
  await frames(1)
 check(game.ball.in_loop and pose.motion == &"loop" and is_equal_approx(player.current_animation_length / player.get_playing_speed(), 8.0 / 27.0), id + " carries the same stride into the Loop")
 for i in 360:
  if not game.ball.in_loop: break
  await frames(1)
 check(not game.ball.in_loop and pose.motion == &"" and game.character.rolling_mesh.visible, id + " returns to the ball on release")

func review_character(id: String, session: Node) -> void:
 var specials: CharacterSpecials = game.specials
 var pose = game.combo_celebration.character_pose
 specials.select_character(id)
 var target: Node2D = game.playfield.bumpers.front()
 target.position = Vector2(500, 450)
 game.ball.teleport_to(target.position + Vector2(-145, 100))
 await frames(4)
 game.presentation.camera_settings.zoom = 2.0
 game.presentation.reset_camera(game.ball.position)
 game.special_meter = specials.definition.meter_capacity
 var before: int = game.score
 check(specials.activate() and specials.pending_target == target, id + " boosts toward the selected bumper")
 await frames(3)
 var rig: Node3D = pose.motion_rig
 if "--require-runners-set" in OS.get_cmdline_user_args(): check(rig != null, id + " has its original Runners rig")
 if rig:
  check(pose.motion == &"target_boost" and pose.motion_player.current_animation == pose.Assets.BOOST[id] and rig.is_visible_in_tree() and not game.character.rolling_mesh.visible, id + " uncurls into its own Boost clip")
  var cycles_per_second := 2.25 * expected_boost_setting
  check(is_equal_approx(pose.motion_player.get_playing_speed() / pose.motion_player.current_animation_length, cycles_per_second), id + " uses the shared Boost cadence for Target Boost")
  var original: Vector2 = specials.homing_direction
  target.position += Vector2(-55, 140)
  await frames(4)
  check(original.dot(specials.homing_direction) < 0.9, "Guidance updates the lock angle when the objective moves")
  var camera: Camera3D = game.presentation.camera
  var at := rig.global_position
  for preset: int in game.PLAY_CAMERAS:
   game.select_play_camera(preset)
   pose._process(0.0)
   var origin := camera.unproject_position(at)
   var projected := camera.unproject_position(at + TablePresentation.map_point(specials.homing_direction)) - origin
   var nose := camera.unproject_position(at + rig.global_basis.z.normalized()) - origin
   check(projected.normalized().dot(nose.normalized()) > 0.995 and rig.global_basis.y.normalized().is_equal_approx(Vector3.UP), id + " stays perpendicular to the table and faces the target in camera %d" % preset)
  var floor_y: float = game.character.spin_root.global_position.y - pose.radius
  check(is_equal_approx(rig.get_child(0).global_position.y, floor_y), id + "'s stride uses the table surface as its floor")
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png("res://test-results/target-boost/%s.png" % id) == OK, "Capture active " + id + " boost")
  session._open_spin_lab()
  var lab = session.spin_lab
  check(lab.active_clip == pose.Assets.BOOST[id] and lab.pivot.global_basis.orthonormalized().is_equal_approx(rig.global_basis.orthonormalized()) and is_equal_approx(lab.sliders.boost.value, expected_boost_setting) and is_equal_approx(lab.player.get_playing_speed() / lab.player.current_animation_length, cycles_per_second), "F8 opens at the same heading and shared stride rate as gameplay")
  var phase: float = lab.player.current_animation_position
  lab.sliders.boost.value = 2.0
  expected_boost_setting = 2.0
  lab._process(0.05)
  check(is_equal_approx(lab.player.current_animation_position, fposmod(phase + 0.05 * 4.5 * lab.player.current_animation_length, lab.player.current_animation_length)), "Boost speed changes the actual preview stride without restarting the clip")
  session._resume_spin_lab()
  check(is_equal_approx(pose.motion_player.get_playing_speed() / pose.motion_player.current_animation_length, 4.5), "Resume applies the selected stride rate")
 else:
  check(game.character.boost_wake.is_visible_in_tree(), id + " has a directional boost with painted assets")
 for i in 230:
  if specials.homing_remaining <= 0.0: break
  await frames(1)
 check(game.score == before + 500 and pose.motion == &"" and game.character.rolling_mesh.visible, id + " curls on physical contact and cashes out once")
 game.ball.teleport_to(target.position + Vector2(160, -80))
 await frames(4)
 game.special_meter = specials.definition.meter_capacity
 # Exercise the normal painted-ball path on machines with the optional art installed.
 pose.motion_rig = null
 check(specials.activate(), id + " starts a second boost")
 await frames(2)
 var wake: MeshInstance3D = game.character.boost_wake
 var aim := Vector3(specials.homing_direction.x, 0.0, specials.homing_direction.y)
 check(wake.is_visible_in_tree() and wake.global_basis.y.normalized().dot(aim) < -0.99, id + " leaves a painted boost streak directly behind the shot")
 specials.clear_homing("Blocked")
 pose.motion_rig = rig
 check(pose.motion == &"" and game.character.rolling_mesh.visible and not game.character.boost_wake.visible, id + " curls immediately on cancellation")
