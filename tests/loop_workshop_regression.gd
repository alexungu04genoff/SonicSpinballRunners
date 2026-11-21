extends SceneTree
## Exercise production disk recipes, the real 120 Hz body and the cross-Zone owner.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Path = Objects.LoopPath
const WORKSHOP := "res://data/acts/Experiments/Loop Workshop.tres"
const OUTPUT := "res://test-results/loop-dev"
const COMPARISON := OUTPUT + "/comparison.tres"
var checks := 0
var failures := 0

class Stream extends "res://scripts/endless/endless_game.gd":
 func _source_paths() -> Array:
  return [WORKSHOP, COMPARISON, WORKSHOP]
 func _next_planned_zone(documents: Array) -> Array[Dictionary]:
  planner.themes = ["green_hill"]
  var entries: Array[Dictionary] = planner.next_zone(documents)
  for i in entries.size(): entries[i].id = i
  return entries

func _initialize() -> void:
 run.call_deferred()

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func wait_for(condition: Callable, ticks := 500) -> bool:
 for i in ticks:
  await frames(1)
  if condition.call(): return true
 return false

func shoot(game: Node, item: Dictionary, speed := 550.0) -> void:
 var direction := Objects.forward(item)
 game.ball.teleport_to(Vector2(item.position) - direction * 14.0, direction * speed)

func ride(game: Node, item: Dictionary) -> PackedVector3Array:
 var trace := PackedVector3Array()
 if not await wait_for(func(): return game.ball.in_loop, 30): return trace
 var manager: Node = game.active.runtime.mechanics
 check(manager.ramp.object_id == item.object_id and game.hub.rail_owner == manager, "Active Act owns the accepted shot")
 check(game.ball.on_ramp and game.ball.collision_mask == 0 and game.ball.collision_layer == 0 and game.ball.gravity_scale == 0, "Lower table contacts and gravity suspended")
 var deviation := 0.0
 var inverted := false
 var rendered_inverted := false
 for i in 500:
  if not game.ball.in_loop: break
  var point := Vector3(game.ball.position.x, game.ball.ramp_height, game.ball.position.y)
  trace.append(point)
  if game.ball.has_track_frame and game.ball.track_frame.y.y < -0.97:
   inverted = true
   rendered_inverted = rendered_inverted or game.character.spin_root.basis.y.normalized().y < -0.93
  # The body can have a genuine lateral offset on the entry lead.
  if manager.progress > Path.LEAD * item.properties.scale:
   deviation = maxf(deviation, point.distance_to(Path.sample(item, manager.progress)))
  await frames(1)
 check(not game.ball.in_loop and not game.ball.on_ramp and game.hub.rail_owner == null, "Completed traversal releases its real body")
 check(game.ball.collision_mask != 0 and game.ball.collision_layer != 0 and game.ball.gravity_scale > 0, "Ordinary physics restored")
 check(inverted and rendered_inverted, "Rendered character turns upside down at the crest")
 check(deviation < 0.15, "Real body follows the authored centerline and height after entry (%.3f px)" % deviation)
 check(game.ball.linear_velocity.normalized().dot(Objects.forward(item)) > 0.999, "Exit velocity follows the authored tangent")
 return trace

func flipper_shot(game: Node, left: bool) -> void:
 var paddle: PlaygroundFlipper
 for other: PlaygroundFlipper in game.flippers:
  if (other.side > 0.0) == left: paddle = other
 var target: Dictionary = game.active.runtime.mechanics.by_id["flipper_climb" if left else "flipper_return"]
 var start_strikes := paddle.strikes
 var normal := paddle.strike_direction(0.85)
 var contact := paddle.global_position.lerp(paddle.tip(), 0.85)
 game.controls.virtual_right = false
 game.ball.teleport_to(contact + normal * (game.ball.radius + paddle.radius + 15.0), Vector2.DOWN * 65)
 for i in 100:
  await frames(1)
  var near := Geometry2D.get_closest_point_to_segment(game.ball.position, paddle.global_position, paddle.tip())
  if game.ball.position.distance_to(near) < game.ball.radius + paddle.radius + 3.0:
   game.controls.virtual_left = left
   game.controls.virtual_right = not left
   break
 var entered := false
 var nearest := INF
 var near_velocity := Vector2.ZERO
 var near_point := Vector2.ZERO
 for i in 180:
  await frames(1)
  if game.ball.position.distance_to(target.position) < nearest:
   nearest = game.ball.position.distance_to(target.position)
   near_point = game.ball.position
   near_velocity = game.ball.linear_velocity
  if game.ball.on_ramp:
   entered = game.active.runtime.mechanics.ramp.object_id == target.object_id
   break
 game.controls.virtual_right = false
 game.controls.virtual_left = false
 print("FLIPPER | strikes=%d | target=%s | nearest=%.2f at %s velocity=%s" % [paddle.strikes - start_strikes, entered, nearest, near_point, near_velocity])
 check(paddle.strikes > start_strikes and entered, "Actual flipper can make " + str(target.object_id))

func rejection_pads(game: Node) -> void:
 var items: Dictionary = game.active.runtime.mechanics.by_id
 var mouth: Vector2 = items.small_side.position
 for id: String in ["weak_straight", "oblique_fast"]:
  var pad: Dictionary = items[id]
  var forward := Objects.forward(pad)
  var strikes := int(pad.launch_count)
  game.ball.teleport_to(Vector2(pad.position) + forward * 30.0, -forward * 220.0)
  check(await wait_for(func(): return pad.launch_count > strikes, 40), "Workshop spring fires: " + id)
  var previous: Vector2 = game.ball.position
  var crossed := false
  for i in 120:
   await frames(1)
   var position: Vector2 = game.ball.position
   if previous.x <= mouth.x and position.x > mouth.x:
    var y := lerpf(previous.y, position.y, (mouth.x - previous.x) / (position.x - previous.x))
    var velocity: Vector2 = game.ball.linear_velocity
    var angle := absf(rad_to_deg(velocity.angle()))
    print("REJECTION | %s | offset=%.2f forward=%.2f angle=%.2f" % [id, y - mouth.y, velocity.x, angle])
    var margin := Path.HALF_WIDTH * float(items.small_side.properties.scale) - float(game.ball.radius)
    crossed = absf(y - mouth.y) <= margin and not game.ball.in_loop
    crossed = crossed and (velocity.x < 240 and angle <= 30 if id == "weak_straight" else velocity.x >= 240 and angle > 30)
    break
   previous = position
  check(crossed, "Spring crosses within the mouth, rejected for its intended reason: " + id)

func blocker(game: Node, where: Vector2) -> StaticBody2D:
 var body := StaticBody2D.new()
 var shape := CollisionShape2D.new()
 var circle := CircleShape2D.new()
 circle.radius = 8
 shape.shape = circle
 body.add_child(shape)
 game.ball.get_parent().add_child(body)
 body.global_position = where
 return body

func blocked_release(game: Node, item: Dictionary) -> void:
 var forward := Objects.forward(item)
 var end := Path.sample(item, Path.LENGTH * float(item.properties.scale))
 var before: int = game.score
 var rings: int = game.rings_collected
 var obstacle := blocker(game, Vector2(end.x, end.z) + forward * 9)
 for stop_return: bool in [false, true]:
  shoot(game, item)
  check(await wait_for(func(): return game.ball.in_loop, 30), "Enter before live obstruction")
  var entrance: StaticBody2D
  if stop_return: entrance = blocker(game, Vector2(item.position) - forward * 9)
  check(await wait_for(func(): return not game.ball.in_loop, 400), "Obstructed Loop releases ownership")
  await frames(2)
  if stop_return:
   check(game.ball.serve_pending and game.ball.position.distance_to(game.ball.serve_position) < 0.1, "Both ends blocked returns the Ball to serve")
   entrance.free()
  else:
   check(game.ball.linear_velocity.dot(forward) < -350 and game.ball.collision_mask != 0, "Blocked exit returns through the mouth under ordinary physics")
  check(game.score == before and game.rings_collected == rings, "Rollback cannot pay completion")
 obstacle.free()
 await frames(2)

func prototype(game: Node) -> void:
 var ball: PlaygroundBall = game.ball
 var manager: Node = game.active.runtime.mechanics
 var straight: Dictionary = manager.by_id.straight_drop
 var initial_mask := ball.collision_mask
 var identity := ball.get_instance_id()
 check(game.ring_field.rings.is_empty(), "Decorative inlays create zero world Ring records")
 game.launch_ball()
 check(await wait_for(func(): return manager.ramp.get("object_id") == "opening_hill", 400), "Natural serve enters the terrain ramp")
 check(await wait_for(func(): return ball.has_track_frame and ball.track_speed > 0 and (-ball.track_frame.z).y > 0.25, 90), "Rising ramp tangent reaches the real character frame")
 check(await wait_for(func(): return ball.in_loop, 450), "Unsteered natural serve reaches the straight Loop")
 check(await wait_for(func(): return not ball.in_loop, 360), "Natural serve exits the Loop")
 check(game.score == 1000 and game.rings_collected == 3, "First completion pays 1,000 Scorecraft points and three Rings")
 var last_trace := PackedVector3Array()
 var lengths := {}
 for id: String in ["straight_drop", "straight_drop", "small_side", "tall_right", "flipper_return"]:
  var item: Dictionary = manager.by_id[id]
  var points_before: int = game.score
  var rings_before: int = game.rings_collected
  var award := 0 if item.rings_paid else int(item.properties.ring_reward)
  game.active.visual.visible = not (id == "straight_drop" and not last_trace.is_empty())
  shoot(game, item)
  var trace := await ride(game, item)
  check(not trace.is_empty() and game.score == points_before + int(item.properties.completion_score) and game.rings_collected == rings_before + award, "Successful traversal pays score and bounded Rings for " + id)
  if id == "straight_drop" and not last_trace.is_empty(): check(trace == last_trace, "Identical 120 Hz positions with the entire Act visual hidden")
  last_trace = trace
  lengths[id] = trace.size()
 print("RIDE | 550 px/s | ticks ", lengths)
 check(lengths.small_side < lengths.straight_drop and lengths.straight_drop < lengths.tall_right, "Larger track takes longer at the same speed")
 var score_before: int = game.score
 var rings_before: int = game.rings_collected
 var practice_loop: Dictionary = manager.by_id.small_side
 practice_loop.properties.completion_score = 0
 shoot(game, practice_loop)
 var practice_trace := await ride(game, practice_loop)
 check(not practice_trace.is_empty() and game.score == score_before, "A zero-point Loop remains traversable")
 var forward := Objects.forward(straight)
 for velocity: Vector2 in [forward * 150.0, -forward * 500.0, forward.rotated(0.65) * 650.0]:
  ball.teleport_to(Vector2(straight.position) - velocity * 0.025, velocity)
  check(not await wait_for(func(): return ball.in_loop, 18), "Rejected shot stays in ordinary physics")
 check(game.score == score_before and game.rings_collected == rings_before, "Misses never pay")
 var climb: Dictionary = manager.by_id.flipper_climb
 var tangent := Objects.RailPath.tangent(climb.path, 0.0)
 ball.teleport_to(Vector2(climb.position) - tangent * 8.0, tangent * 135.0)
 check(await wait_for(func(): return ball.on_ramp and manager.ramp.get("object_id") == "flipper_climb", 50), "Weak uphill shot enters the ordinary ramp")
 check(await wait_for(func(): return ball.has_track_frame and ball.track_speed < -10 and game.character.riding_track, 160), "Character follows signed travel when the ramp rolls back")
 check(await wait_for(func(): return not ball.on_ramp and not ball.has_track_frame, 240), "Rollback releases the real Ball at the ramp entrance")
 await rejection_pads(game)
 await blocked_release(game, straight)
 shoot(game, straight)
 check(await wait_for(func(): return ball.in_loop, 30), "Reset fixture enters")
 game.reset_ball(false)
 check(not ball.in_loop and manager.ramp.is_empty() and ball.collision_mask == initial_mask, "Reset cancels without phantom payout")
 await frames(3)
 shoot(game, straight)
 check(await wait_for(func(): return ball.in_loop, 30), "Drain fixture enters")
 game._on_ball_drained()
 check(not ball.in_loop and manager.ramp.is_empty(), "Actual drain cancels the Loop")
 check(await wait_for(func(): return not is_instance_valid(game.transfer), 500), "Prototype checkpoint transfer completes")
 check(ball.get_instance_id() == identity and ball.collision_mask == initial_mask and straight.rings_paid and game.score == score_before and game.rings_collected == rings_before, "Drain preserves earned reward ledger and restores the same real Ball")
 game.controls.input_blocked = false
 await flipper_shot(game, true)
 await wait_for(func(): return not ball.on_ramp, 450)
 await flipper_shot(game, false)

func streaming() -> void:
 var game := Stream.new()
 root.add_child(game)
 check(await wait_for(func(): return game.started or not game.last_source_error.is_empty(), 12000) and game.started, "Endless stream opens Green Hill disk Act")
 if game.started:
  game.controls.virtual_enabled = true
  for seq in [1, 2, 3]:
   check(await wait_for(func(): return game.resident.any(func(act): return act.plan.sequence == seq), 12000), "Stream attaches neighbor %d" % seq)
   var found: Array = game.resident.filter(func(act): return act.plan.sequence == seq)
   if found.is_empty(): break
   var previous: RefCounted = game.active
   if seq != 2:
    shoot(game, previous.runtime.mechanics.by_id.straight_drop)
    check(await wait_for(func(): return game.ball.in_loop, 60), "Loop active before boundary")
   game._activate(found.front())
   if seq != 2:
    check(game.hub.rail_owner == null and previous.runtime.mechanics.ramp.is_empty() and not game.ball.in_loop and game.ball.collision_mask != 0, "Act or Zone transition restores ownership")
   await frames(2)
   game.presentation.camera_focus = game.active.spawn()
   game._retire_behind()
  check(game.active.plan.zone == 1 and game.resident.all(func(act): return act.plan.sequence >= 2), "Former Act retired across a real Zone boundary")
  shoot(game, game.active.runtime.mechanics.by_id.straight_drop)
  check(await wait_for(func(): return game.ball.in_loop, 50), "Teardown starts with live Loop ownership")
  var watched: WeakRef = weakref(game.hub.rail_owner)
  await game.prepare_to_close()
  check(game.hub.rail_owner == null and not game.ball.in_loop, "Closing cancels before the world is freed")
  game.free()
  await frames(2)
  check(watched.get_ref() == null, "Scene teardown releases the active owner")
 else:
  await game.prepare_to_close()
  game.free()

func run() -> void:
 Review.position_review_window(root)
 var fixture := Fixture.new()
 var opened := await fixture.open(self, WORKSHOP, "green_hill", OUTPUT, "default", "production")
 check(opened, "Disk-only Prototype loads: " + fixture.error)
 if opened:
  paused = false
  fixture.game.ball.freeze = false
  fixture.game.set_physics_process(true)
  fixture.game.controls.input_blocked = false
  fixture.game.controls.virtual_enabled = true
  await frames(2)
  await prototype(fixture.game)
 await fixture.close()
 paused = false
 await streaming()
 print("RESULT | Loop Workshop | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
