extends SceneTree
## Content review. Run at --fixed-fps 120 after baking Starfall Alley for the chosen theme.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const Tube = preload("res://scripts/authored_act/launch_tube.gd")
const History = preload("res://scripts/act_editor/terrain_history.gd")
const Act := "res://data/acts/Candidates/Starfall Alley.tres"
const Output := "res://test-results/starfall-alley"
# Incoming pose on a resting paddle. All motion after that setup uses ordinary input.
const Setups := {
 "pocket": ["lower_right", 0.50],
 "buzz": ["lower_left", 0.62],
 "inlane": ["lower_left", 0.84],
 "crown": ["right_shoulder", 0.74],
}
var fixture: RefCounted
var game: Node
var pads := {}
var tube: Node2D
var events: Array = []
var strikes: Array = []
var tick := 0
var checks := 0
var failures := 0
var theme := "green_hill"
var film := false
var clip := ""
var frame_index := 0
var held_ticks := 0
var target_tick := -1

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func run() -> void:
 var scenarios: Array = ["run", "short_charge", "pocket", "buzz", "inlane", "crown", "retry"]
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--theme="): theme = argument.trim_prefix("--theme=")
  if argument.begins_with("--case="): scenarios = Array(argument.trim_prefix("--case=").split(","))
  if argument == "--film": film = true
 if Engine.physics_ticks_per_second != 120 or (film and DisplayServer.get_name() == "headless"):
  push_error("Use 120 Hz physics and a graphical renderer for film.")
  quit(1)
  return
 DirAccess.make_dir_recursive_absolute(Output)
 if DisplayServer.get_name() != "headless":
  root.size = Vector2i(1280, 900)
  Review.position_review_window(root)
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
  RenderingServer.frame_post_draw.connect(record_frame)
 var source: Resource = ActGeometry.load_document(Act).document
 check(source != null and source.difficulty_label() == "Easy", "Load an Easy Act")
 if source == null:
  quit(1)
  return
 var copy := Output.path_join("roundtrip-" + theme + ".tres")
 check(source.save_document(copy) == OK and ActGeometry.load_document(copy).document.editing_fingerprint() == source.editing_fingerprint(), "Editor round-trip preserves geometry, settings and editable sources")
 for piece: Dictionary in source.placements:
  var restored := History.restore(piece)
  check(piece.smoothing_strength > 0 and restored.error.is_empty() and restored.sources.all(func(p): return p.terrain_scale == 0.5), "Unsmooth restores the original half-scale stamps")
 for scenario: String in scenarios:
  await review(scenario)
 print("STARFALL REVIEW | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func review(scenario: String) -> void:
 fixture = Fixture.new()
 var directory := Output.path_join("physics" if DisplayServer.get_name() == "headless" else "video").path_join(theme + "-" + scenario)
 DirAccess.make_dir_recursive_absolute(directory)
 if not await fixture.open(self, Act, theme, directory, "default", "production"):
  check(false, fixture.error)
  await fixture.close()
  return
 game = fixture.game
 tube = game.ball.launch_tube
 check(tube != null and tube.contained and tube.dock_position() == game.active.spawn(), "Serve starts in the authored right-hand shooter")
 if tube == null:
  await fixture.close()
  return
 var old_tube: WeakRef = weakref(tube)
 var old_ball: WeakRef = weakref(game.ball)
 var old_world: WeakRef = weakref(game.active.runtime.root)
 var receipt := FileAccess.open(directory.path_join("authority.json"), FileAccess.WRITE)
 receipt.store_string(JSON.stringify(fixture.receipt, "  "))
 receipt.close()
 pads.clear()
 events.clear()
 strikes.clear()
 held_ticks = 0
 target_tick = -1
 tick = 0
 for object: Dictionary in game.active.runtime.objects:
  if object.body is PlaygroundFlipper:
   pads[object.object_id] = object.body
   object.body.shot_fired.connect(on_strike.bind(object.object_id))
 if scenario == "run": check_clearance()
 game.scorecraft.score_awarded.connect(on_score)
 if scenario == "overview":
  await overview(directory)
 else:
  game.controls.virtual_enabled = true
  game.controls.input_blocked = false
  game.set_physics_process(true)
  game.ball.freeze = false
  paused = false
  if scenario in ["run", "short_charge"]: start_clip(directory)
  if scenario == "retry":
   await retry()
  elif await launch({"run": 112, "short_charge": 62}.get(scenario, 72)):
   if scenario in Setups:
    var setup: Array = Setups[scenario]
    var pad: PlaygroundFlipper = pads[setup[0]]
    var axis := Vector2.from_angle(pad.rest_angle())
    var start: Vector2 = pad.global_position + axis * pad.length * float(setup[1]) + axis.rotated(-PI * 0.5 * pad.side) * (game.ball.radius + pad.radius + 18.0)
    game.ball.teleport_to(start, Vector2.DOWN * 65.0)
    game.presentation.reset_camera(start)
    start_clip(directory)
   await play(scenario)
 clip = ""
 check(fixture.still_current(), "Capture and collision source are current")
 await fixture.close()
 await process_frame
 check(old_ball.get_ref() == null and old_tube.get_ref() == null and old_world.get_ref() == null, "Teardown frees the Ball, shooter and Act root")

func check_clearance() -> void:
 var count := 0
 for trail: Dictionary in game.active.document.ring_trails:
  for pos: Vector2 in ActGeometry.RINGS.positions(trail):
   count += 1
   for terrain: Dictionary in game.active.runtime.terrain:
    check(not AuthoredActRuntimeCompiler._near_outline(pos, terrain.points, terrain.closed, game.ball.radius), "Ring clears terrain at %s" % pos)
 for pad: PlaygroundFlipper in pads.values():
  # Hinges sit in the banks. Sample the free blade at rest and through its swing.
  for i in 9:
   var axis := Vector2.from_angle(lerpf(pad.rest_angle(), pad.active_angle(), i / 8.0))
   for fraction: float in [0.38, 0.65, 1.0]:
    var pos := pad.global_position + axis * pad.length * fraction
    for terrain: Dictionary in game.active.runtime.terrain:
     check(not AuthoredActRuntimeCompiler._near_outline(pos, terrain.points, terrain.closed, pad.radius), "Flipper sweep clears terrain at %s" % pos)
 print("GEOMETRY | floor rings=%d | flippers=%d" % [count, pads.size()])

func on_score(details: Dictionary) -> void:
 if game.act_score >= game.act_score_target and target_tick < 0: target_tick = tick
 if details.kind != &"ring":
  events.append([tick, str(details.kind), str(details.object_id), details.total])

func on_strike(_at: Vector2, _impulse: Vector2, fraction: float, id: String) -> void:
 strikes.append([tick, id, snappedf(fraction, 0.01)])

func start_clip(directory: String) -> void:
 if not film: return
 clip = directory.path_join("frames")
 DirAccess.make_dir_recursive_absolute(clip)
 frame_index = 0

func record_frame() -> void:
 if clip.is_empty(): return
 if frame_index % 4 == 0:
  var path := clip.path_join("%05d.jpg" % (frame_index / 4))
  if root.get_texture().get_image().save_jpg(path, 0.90) != OK:
   check(false, "Write gameplay frame " + path)
 frame_index += 1

func overview(directory: String) -> void:
 if DisplayServer.get_name() == "headless":
  check(false, "Overview requires the graphical renderer")
  return
 var p: Node3D = game.presentation
 p.set_camera_follow(false)
 p.set_camera_preset(TablePresentation.CameraPreset.TOP_DOWN)
 p.overview_focus = Vector2(225, 371)
 p.reset_camera()
 game._update_backgrounds()
 for i in 10: await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_jpg(directory.path_join("table.jpg"), 0.96) == OK, "Save the full-table overview")

func launch(hold: int) -> bool:
 for i in 900:
  await physics_frame
  game.controls.virtual_launch = i >= 2 and i < hold + 2
  if not tube.contained:
   check(game.ball.launch_tube == null and not game.ball.on_ramp and game.hub.rail_owner == null and game.ball.collision_mask != 0 and game.ball.gravity_scale > 0, "Shooter releases into ordinary 2D physics")
   print("PLUNGE | held=%d ticks | exit=%s | velocity=%s" % [hold, game.ball.position, game.ball.linear_velocity])
   return true
 check(false, "Charged launch exits within its time budget")
 return false

func flip_on_approach(minimum_fraction: float) -> void:
 if held_ticks > 0:
  held_ticks -= 1
  return
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 if game.ball.linear_velocity.y < 0: return
 for pad: PlaygroundFlipper in pads.values():
  var near := Geometry2D.get_closest_point_to_segment(game.ball.position, pad.global_position, pad.tip())
  if near.distance_to(pad.global_position) <= pad.length * minimum_fraction: continue
  if game.ball.position.distance_to(near) >= game.ball.radius + pad.radius + 3.0: continue
  game.controls.virtual_left = pad.side > 0
  game.controls.virtual_right = pad.side < 0
  held_ticks = 5
  return

func play(scenario: String) -> void:
 var from_dock := scenario in ["run", "short_charge"]
 var in_right_lane := false
 var low_y := INF
 var first_pad := ""
 var initial_ball: int = game.ball_number
 for i in (12000 if from_dock else 1100):
  await physics_frame
  tick = i
  var pos: Vector2 = game.ball.position
  if not strikes.is_empty():
   if first_pad.is_empty(): first_pad = strikes[0][1]
   low_y = minf(low_y, pos.y)
   in_right_lane = in_right_lane or (pos.x > 320 and pos.y > 620 and pos.y < 675 and game.ball.linear_velocity.y > 0)
  if game.finished or game.transfer != null: break
  if not from_dock and strikes.size() >= 2:
   if i - int(strikes[1][0]) >= 36: break
   continue
  flip_on_approach(0.38 if from_dock else 0.10)
 var ids := events.map(func(e): return str(e[2]).get_slice(":", 2))
 var free: bool = not tube.contained and game.ball.launch_tube == null and not game.ball.on_ramp and game.hub.rail_owner == null
 check(free, scenario + " ends with no traversal owner")
 match scenario:
  "run", "short_charge":
   check(game.finished and game.results.size() == 1 and game.results[0].cleared and game.ball_number == initial_ball, "One continuous charge-to-Goal clear")
   check(target_tick > 0 and target_tick < tick and game.score >= game.active.document.score_target, "Earn the authored target before crossing the Goal")
  "pocket":
   check(first_pad == "lower_right" and "pocket" in ids and strikes.size() >= 2 and strikes[1][1] == "lower_left", "Right forehand hits the pocket and comes back to the left flipper")
  "buzz":
   check(first_pad == "lower_left" and "alley_buzz" in ids, "Left forehand destroys the patrolling Buzz")
  "inlane":
   check(first_pad == "lower_left" and "alley_buzz" not in ids and in_right_lane and strikes.size() >= 2 and strikes[1][1] == "lower_right" and game.ball_number == initial_ball, "Wide miss returns through the right inlane to a playable right-flipper strike")
  "crown":
   check(first_pad == "right_shoulder" and "crown_rack" in ids, "Upper forehand clears the crown ring rack")
  _: check(false, "Unknown scenario " + scenario)
 print("SHOT | %s | tick=%d target_tick=%d points=%d rings=%d min_y=%.1f right_inlane=%s strikes=%s features=%s" % [scenario, tick, target_tick, game.score, game.rings_collected, low_y, in_right_lane, strikes, events])

func retry() -> void:
 # A weak plunge must roll back under the tube's own resistance.
 var rolled_back := false
 for i in 900:
  await physics_frame
  game.controls.virtual_launch = i >= 2 and i < 12
  rolled_back = rolled_back or tube.phase == Tube.Phase.RETURNING
  if rolled_back and tube.phase == Tube.Phase.DOCKED: break
 check(rolled_back and tube.phase == Tube.Phase.DOCKED and tube.distance == 0 and game.score == 0, "Weak plunge redocks without scoring")
 if not await launch(72): return
 var number: int = game.ball_number
 game.controls.virtual_launch = true
 game.controls.reset_requested.emit()
 for i in 600:
  await physics_frame
  if game.transfer == null and tube.contained: break
 for i in 18: await physics_frame
 check(game.ball_number == number + 1 and tube.phase == Tube.Phase.DOCKED and tube.charge == 0.0 and tube.distance == 0.0 and game.hub.rail_owner == null, "Retry clears the previous traversal and waits for a fresh press")
 await launch(72)
