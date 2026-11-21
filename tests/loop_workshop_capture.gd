extends SceneTree
## Matched disk-backed GPU sample and real-time-scale Prototype footage.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const Report = preload("res://tests/render_profile_support.gd")
const OUTPUT := "res://test-results/loop-dev"
const WORKSHOP := "res://data/acts/Experiments/Loop Workshop.tres"
const CONTROL := OUTPUT + "/comparison.tres"

func _initialize() -> void:
 run.call_deferred()

func capture(fixture: RefCounted, flipper: bool) -> bool:
 var game: Node = fixture.game
 var directory := OUTPUT.path_join("flipper-frames" if flipper else "frames")
 if fixture.receipt.theme != "green_hill": directory += "-" + str(fixture.receipt.theme)
 DirAccess.make_dir_recursive_absolute(directory)
 Engine.time_scale = 1.0
 paused = false
 game.controls.virtual_enabled = true
 game.controls.input_blocked = false
 game.set_physics_process(true)
 game.ball.freeze = false
 var paddle: PlaygroundFlipper
 if flipper:
  for other: PlaygroundFlipper in game.flippers:
   if other.side < 0: paddle = other
  var contact := paddle.global_position.lerp(paddle.tip(), 0.85)
  var setup: Vector2 = contact + paddle.strike_direction(0.85) * (game.ball.radius + paddle.radius + 15.0)
  game.ball.teleport_to(setup, Vector2.DOWN * 65.0)
  game.presentation.reset_camera(setup)
 else: game.launch_ball()
 var entered := false
 var crest_saved := false
 var ramp_saved := false
 var still_only := "--still" in OS.get_cmdline_user_args()
 var framed := true
 var index := 0
 var tail := 0
 # --fixed-fps 60. Read back alternate rendered frames for a 30 fps replay.
 for tick in 420:
  await process_frame
  await RenderingServer.frame_post_draw
  if flipper and not game.controls.virtual_right:
   var near := Geometry2D.get_closest_point_to_segment(game.ball.position, paddle.global_position, paddle.tip())
   if game.ball.position.distance_to(near) < game.ball.radius + paddle.radius + 3.0: game.controls.virtual_right = true
  if not ramp_saved and game.ball.on_ramp and not game.ball.in_loop and game.ball.ramp_height > 25.0:
   ramp_saved = root.get_texture().get_image().save_jpg(directory.path_join("ramp.jpg"), 0.95) == OK
  entered = entered or game.ball.in_loop
  if game.ball.in_loop:
   var camera: Camera3D = game.presentation.camera
   var center: Vector3 = game.presentation.ball_visual.global_position
   framed = framed and camera.is_position_in_frustum(center)
   var manager: Node = game.active.runtime.mechanics
   var path := preload("res://scripts/authored_act/loop_path.gd")
   var length := path.LENGTH * float(manager.ramp.properties.scale)
   if not crest_saved and manager.progress >= 0.48 * length:
    for d: float in path.distances():
     var p := path.sample(manager.ramp, d * float(manager.ramp.properties.scale))
     framed = framed and camera.is_position_in_frustum(p * TablePresentation.SCALE)
    crest_saved = root.get_texture().get_image().save_jpg(directory.path_join("crest.jpg"), 0.95) == OK
  if entered and not game.ball.in_loop: tail += 1
  if not still_only and tick % 2 == 0:
   var image := root.get_texture().get_image()
   if image.save_jpg(directory.path_join("%04d.jpg" % index), 0.95) != OK: return false
   index += 1
  if tail >= 36: break
 print("CAPTURE | frames=%d | score=%d | rings=%d | ball_framed=%s" % [index, game.score, game.rings_collected, framed])
 return (flipper or ramp_saved) and entered and framed and crest_saved and tail >= 36 and game.score == 1000 and game.rings_collected == 3

func sample(fixture: RefCounted, pass_index: int, overview: bool) -> void:
 var game: Node = fixture.game
 var viewport: SubViewport = game.view
 var rid := viewport.get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(rid, true)
 game.presentation.camera_follow_enabled = not overview
 var focus := Vector2(214, 224)
 game.presentation.reset_camera(focus)
 game._update_backgrounds()
 for i in 75: await process_frame
 var gpu := []
 var draws := []
 var primitives := []
 for i in 120:
  await process_frame
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
  draws.append(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
  primitives.append(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
 draws.sort()
 primitives.sort()
 print("PROFILE | act=%s overview=%s pass=%d gpu_ms=%s draws=%d primitives=%d" % [fixture.receipt.act, overview, pass_index, Report.timing(gpu), draws[60], primitives[60]])

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Loop capture needs a graphical renderer.")
  quit(1)
  return
 root.size = Vector2i(1280, 900)
 Review.position_review_window(root)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps = 0
 Engine.time_scale = 0.0
 Review.Options.settings_path = OUTPUT.path_join("graphics.cfg")
 Review.Options.update_quality(Review.Options.defaults(), false)
 var footage := "--capture" in OS.get_cmdline_user_args() or "--still" in OS.get_cmdline_user_args()
 var theme := "green_hill"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--theme="): theme = argument.trim_prefix("--theme=")
 var pass_index := 0
 for path: String in ([WORKSHOP] if footage else [CONTROL, WORKSHOP, WORKSHOP, CONTROL]):
  var fixture := Fixture.new()
  if not await fixture.open(self, path, theme, OUTPUT, "default", "production"):
   push_error(fixture.error)
   await fixture.close()
   quit(1)
   return
  var ok := true
  if footage: ok = await capture(fixture, "--flipper" in OS.get_cmdline_user_args())
  else:
   for overview: bool in [false, true]: await sample(fixture, pass_index, overview)
  await fixture.close()
  paused = false
  if not ok:
   quit(1)
   return
  pass_index += 1
 quit(0)
