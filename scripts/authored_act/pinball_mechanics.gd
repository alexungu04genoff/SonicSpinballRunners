extends Node
## Authored mechanics run only through the authoritative ball's 120 Hz integration.
signal mechanic_score(kind: StringName, object_id: String, points: int)
signal mechanic_rings(kind: StringName, object_id: String, amount: int)
signal feature_completed(kind: StringName, object_id: String, bonus: int)
## Movement events describe actual launches and rail ownership, independently of rewards.
signal traversal_event(kind: StringName, object_id: String, phase: StringName)
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const RailPath = preload("res://scripts/authored_act/rail_path.gd")
const Contact = preload("res://scripts/authored_act/gimmick_geometry.gd")
const Lanes = preload("res://scripts/authored_act/passing_lanes.gd")
const Banks = preload("res://scripts/act_editor/switch_banks.gd")
const MAX_FIELD_ACCELERATION := 600.0
const MAX_TICKS_PER_STEP := 2
var ball: PlaygroundBall
## Streaming coordinates several independent Act runtimes through one ball adapter.
var bind_ball_on_ready := true
## Loaded neighbors retain physical routes, but only the active Act owns objectives.
var scoring_active := true
var items: Array[Dictionary] = []
var banks: Array = []
var by_id: Dictionary = {}
var ramp: Dictionary = {}
var progress := 0.0
var speed := 0.0
var age := 0.0
var reentry_time := 0.0
var _saved_layer := 2
var _saved_mask := 1
var _travel_origin: Variant = null

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 if bind_ball_on_ready: ball.mechanics = self

func _exit_tree() -> void:
 reset()
 if is_instance_valid(ball) and ball.mechanics == self: ball.mechanics = null

func add_object(placement: Dictionary, descriptor: Dictionary) -> void:
 var item := placement.duplicate(true)
 item.properties = Objects.properties(placement)
 item["spin"] = 0.0
 item["angle"] = 0.0
 item["tick_rotation"] = 0.0
 item["cooldown"] = 0.0
 item["active"] = false
 item["open"] = item.properties.get("initial_state", "closed") == "open"
 item["latched"] = false
 item["passing"] = false
 item["pulse"] = 0.0
 item["launch_count"] = 0
 if item.type == "spinner":
  item["goal_ticks"] = 0
  item["completions"] = 0
 if item.type == "lane_barrier":
  item["posts"] = Objects.world_posts(item)
  item["lanes"] = []
  for i in item.posts.size() - 1: item.lanes.append(Lanes.make_lane())
  item["complete"] = false
  item["completions"] = 0
 if item.type == "diverter":
  item["state"] = item.properties.initial_state
  item["pending_state"] = ""
 if item.type == "elevated_rail":
  var control: PackedVector2Array = item.properties.points.duplicate()
  for i in control.size(): control[i] = item.position + control[i].rotated(deg_to_rad(float(item.rotation_degrees)))
  item["path"] = RailPath.build(control)
 items.append(item)
 by_id[item.object_id] = item
 descriptor["mechanic"] = item

func reset() -> void:
 leave_ramp()
 reset_motion()
 reentry_time = 0.0
 for item: Dictionary in items:
  item.spin = 0.0
  item.angle = 0.0
  item.tick_rotation = 0.0
  item.cooldown = 0.0
  item.active = false
  item.open = item.properties.get("initial_state", "closed") == "open"
  item.latched = false
  item.passing = false
  item.pulse = 0.0
  item.launch_count = 0
  if item.type == "spinner":
   item.goal_ticks = 0
   item.completions = 0
  if item.type == "lane_barrier":
   for i in item.lanes.size(): item.lanes[i] = Lanes.make_lane()
   item.complete = false
   item.completions = 0
  elif item.type == "diverter":
   item.state = item.properties.initial_state
   item.pending_state = ""
 for bank: Dictionary in banks:
  bank["complete"] = false
  bank["reset_remaining"] = 0.0

func reset_motion() -> void:
 _travel_origin = null
 for item: Dictionary in items:
  if item.type == "lane_barrier":
   for lane: Dictionary in item.lanes:
    lane.side = 0
    lane.latched = false

func leave_ramp() -> void:
 var leaving_id: String = ramp.get("object_id", "")
 if is_instance_valid(ball) and not ramp.is_empty():
  ball.collision_layer = _saved_layer
  ball.collision_mask = _saved_mask
  ball.gravity_scale = float(ball.tuning.effective.gravity_scale)
  ball.on_ramp = false
  ball.ramp_height = 0.0
 ramp = {}
 progress = 0.0
 speed = 0.0
 age = 0.0
 reset_motion()
 if not leaving_id.is_empty(): traversal_event.emit(&"elevated_rail", leaving_id, &"exited")

func tick(dt: float) -> void:
 reentry_time = maxf(0.0, reentry_time - dt)
 var budget := MAX_TICKS_PER_STEP
 for bank: Dictionary in banks:
  if not bank.get("complete", false) or float(bank.get("reset_delay", 0.0)) <= 0.0: continue
  bank.reset_remaining = maxf(0.0, float(bank.get("reset_remaining", 0.0)) - dt)
  if bank.reset_remaining <= 0.0:
   bank.complete = false
   for id: String in bank.members:
    if by_id.has(id): by_id[id].active = false
 for item: Dictionary in items:
  item.cooldown = maxf(0.0, item.cooldown - dt)
  item.pulse = maxf(0.0, item.pulse - dt)
  if item.type == "lane_barrier":
   for lane: Dictionary in item.lanes: lane.pulse = maxf(0.0, lane.pulse - dt)
   if item.complete and item.cooldown <= 0.0:
    item.complete = false
    for lane: Dictionary in item.lanes: lane.lit = false
  if item.type != "spinner": continue
  var rotation_step: float = item.spin * dt
  item.angle = fposmod(item.angle + rotation_step, TAU)
  item.tick_rotation += absf(rotation_step)
  item.spin *= exp(-float(item.properties.decay) * dt)
  if absf(item.spin) < 0.02: item.spin = 0.0
  var ticks := mini(budget, floori(item.tick_rotation / PI))
  # Discard excess complete rotations instead of building an event backlog.
  item.tick_rotation = fmod(item.tick_rotation, PI)
  if not scoring_active: continue
  for i in ticks:
   mechanic_score.emit(&"spinner_tick", item.object_id, int(item.properties.tick_score))
   if not bool(item.properties.completion_enabled): continue
   item.goal_ticks += 1
   if item.goal_ticks >= int(item.properties.target_ticks):
    # Consume the threshold before dispatch, so callbacks cannot award it twice.
    item.goal_ticks = 0
    item.completions += 1
    item.pulse = 0.6
    complete_feature(&"spinner_goal", item.object_id, int(item.properties.completion_bonus))
  budget -= ticks

static func magnetic_acceleration(item: Dictionary, at: Vector2) -> Vector2:
 var offset: Vector2 = item.position - at
 var distance := offset.length()
 var radius := float(item.properties.radius)
 if distance >= radius or distance < 0.001: return Vector2.ZERO
 # Smooth center clamp and outer falloff: no inverse-distance singularity or trap.
 var weight := minf(1.0, distance / maxf(8.0, radius * 0.2)) * (1.0 - distance / radius)
 return offset / distance * float(item.properties.strength) * weight * (-1.0 if item.properties.mode == "repel" else 1.0)

func apply_fields(state: PhysicsDirectBodyState2D) -> void:
 var acceleration := Vector2.ZERO
 for item: Dictionary in items:
  if item.type == "magnetic_field": acceleration += magnetic_acceleration(item, state.transform.origin)
 state.apply_central_impulse(acceleration.limit_length(MAX_FIELD_ACCELERATION) * ball.mass * state.step)

static func crossing_fraction(start: Vector2, end: Vector2, center: Vector2, forward: Vector2, half_width: float, one_way: bool) -> float:
 var a := (start - center).dot(forward)
 var b := (end - center).dot(forward)
 if one_way and not (a <= 0.0 and b > 0.0): return -1.0
 if not one_way and not ((a <= 0.0 and b > 0.0) or (a >= 0.0 and b < 0.0)): return -1.0
 var fraction := -a / (b - a)
 var sideways := Vector2(-forward.y, forward.x)
 if absf((start.lerp(end, fraction) - center).dot(sideways)) > half_width: return -1.0
 return fraction

func observe_actual_motion(state: PhysicsDirectBodyState2D) -> void:
 # Reward only actual travel since the last integration, never a speculative shot
 # that the ball's conservative terrain sweep might rebound before completing.
 if _travel_origin != null: _observe_travel(state, _travel_origin, state.transform.origin)
 _travel_origin = state.transform.origin

func observe_motion(state: PhysicsDirectBodyState2D, sample_travel := true) -> bool:
 if items.is_empty(): return false
 if sample_travel: observe_actual_motion(state)
 var start := state.transform.origin
 var motion := state.linear_velocity * state.step
 _advance_diverters(start, motion)
 var query := PhysicsTestMotionParameters2D.new()
 query.from = state.transform
 query.motion = motion
 var hit := PhysicsTestMotionResult2D.new()
 if PhysicsServer2D.body_test_motion(ball.get_rid(), query, hit): motion = hit.get_travel()
 var end := start + motion
 if _observe_gimmicks(state, start, motion):
  # Launches and one-way responses remain ordinary free flight on the same ball.
  # The native-body sweep still protects the new direction against nearby terrain.
  ball.flipper_launch_pending = false
  ball._guard_fast_motion(state)
  ball._previous_step_velocity = state.linear_velocity
  return true
 for item: Dictionary in items:
  if item.type == "spinner" and item.cooldown <= 0.0:
   var forward := Vector2.UP.rotated(deg_to_rad(float(item.rotation_degrees)))
   if crossing_fraction(start, end, item.position, forward, float(item.properties.width) * 0.5, false) >= 0.0:
    item.spin = clampf(float(item.spin) + state.linear_velocity.dot(forward) * 0.08, -float(item.properties.max_spin), float(item.properties.max_spin))
    item.cooldown = 0.08
  elif item.type == "elevated_rail" and reentry_time <= 0.0:
   var forward := RailPath.tangent(item.path, 0.0)
   var incoming := state.linear_velocity.dot(forward)
   if incoming < float(item.properties.entry_speed): continue
   if incoming / maxf(1.0, state.linear_velocity.length()) < 0.35: continue
   var fraction := crossing_fraction(start, end, item.path.points[0], forward, maxf(1.0, float(item.properties.width) * 0.5 - ball.radius), true)
   if fraction < 0.0: continue
   ramp = item
   speed = minf(incoming, 2400.0)
   progress = 0.0
   age = 0.0
   _saved_layer = ball.collision_layer
   _saved_mask = ball.collision_mask
   ball.collision_layer = 0
   ball.collision_mask = 0
   ball.gravity_scale = 0.0
   ball.on_ramp = true
   ball._reset_steering("Elevated rail")
   ball.flipper_launch_pending = false
   traversal_event.emit(&"elevated_rail", item.object_id, &"entered")
   advance_ramp(state, state.step * (1.0 - fraction))
   return true
 return false

func _activate_switch(item: Dictionary) -> void:
 if not scoring_active or item.active: return
 item.active = true
 item.latched = true
 item.pulse = 0.25
 if int(item.properties.score_reward) > 0:
  mechanic_score.emit(&"switch", item.object_id, int(item.properties.score_reward))
 for bank: Dictionary in banks:
  if bank.get("complete", false): continue
  var complete: bool = not bank.members.is_empty()
  for id: String in bank.members:
   if not by_id.has(id) or not by_id[id].active: complete = false
  if not complete: continue
  bank["complete"] = true
  bank["reset_remaining"] = float(bank.get("reset_delay", 0.0))
  complete_feature(&"switch_bank", bank.bank_id, int(bank.get("completion_bonus", 0)))
  for action: Dictionary in Banks.actions(bank):
   if not by_id.has(action.object_id): continue
   var target: Dictionary = by_id[action.object_id]
   if action.action == "open": target.open = true
   else: request_diverter(target, action.action)

func complete_feature(kind: StringName, object_id: String, bonus: int) -> void:
 if not scoring_active: return
 if bonus > 0: mechanic_score.emit(kind, object_id, bonus)
 feature_completed.emit(kind, object_id, bonus)

func request_diverter(item: Dictionary, action: String) -> void:
 var requested: String = item.pending_state if not str(item.pending_state).is_empty() else item.state
 match action:
  "set_a": requested = "a"
  "set_b": requested = "b"
  "toggle": requested = "b" if requested == "a" else "a"
  _: return
 item.pending_state = "" if requested == item.state else requested

func _advance_diverters(at: Vector2, motion: Vector2) -> void:
 for item: Dictionary in items:
  if item.type != "diverter" or item.pending_state == "": continue
  # The full circumscribed sweep must be empty, including this tick's travel.
  # A delayed instantaneous switch cannot intersect, carry or launch the ball.
  var nearest := Geometry2D.get_closest_point_to_segment(item.position, at, at + motion)
  if nearest.distance_to(item.position) <= float(item.properties.length) * 0.5 + ball.radius + 5.0: continue
  item.state = item.pending_state
  item.pending_state = ""
  item.pulse = 0.25

func _observe_travel(state: PhysicsDirectBodyState2D, start: Vector2, end: Vector2) -> void:
 for item: Dictionary in items:
  if item.type == "lane_barrier":
   if not scoring_active: continue
   for i in item.lanes.size():
    if not Lanes.observe(item.lanes[i], start, end, item.posts[i], item.posts[i + 1], item.properties.post_radius, ball.radius): continue
    if item.complete: continue
    var reward := int(item.properties.lane_reward)
    if reward > 0:
     if item.properties.reward_type == "rings": mechanic_rings.emit(&"lane", item.object_id, reward)
     else: mechanic_score.emit(&"lane", item.object_id, reward)
    if item.properties.completion_mode == "light_all" and item.lanes.all(func(lane): return lane.lit):
     item.complete = true
     item.completions += 1
     item.cooldown = float(item.properties.reset_delay)
     item.pulse = item.cooldown
     complete_feature(&"lane_set", item.object_id, int(item.properties.completion_bonus))
  elif item.type == "dash_panel":
   var forward := Objects.forward(item)
   var half_segment := maxf(0.0, float(item.properties.width) * 0.5 - 18.0)
   var radius := 18.0 + ball.radius
   var inside := not Contact.capsule_hit(start, Vector2.ZERO, item.position, forward, half_segment, radius + 0.5).is_empty()
   if not inside: item.latched = false
   if item.latched or item.cooldown > 0.0: continue
   if inside:
    item.latched = true # Placement inside the pad is not an entry crossing.
    continue
   if (end - start).length_squared() < 0.0001: continue
   if Contact.capsule_hit(start, end - start, item.position, forward, half_segment, radius).is_empty(): continue
   item.latched = true
   item.cooldown = 0.18
   item.pulse = 0.3
   item.launch_count += 1
   state.linear_velocity = Objects.dash_velocity(state.linear_velocity, item)
   ball._reset_steering("Dash Panel")
   traversal_event.emit(&"dash_panel", item.object_id, &"used")

func _observe_gimmicks(state: PhysicsDirectBodyState2D, start: Vector2, motion: Vector2) -> bool:
 var events: Array[Dictionary] = []
 for item: Dictionary in items:
  var contact := {}
  if item.type in ["switch_target", "wall_switch"]:
   var outside := Contact.circle_hit(start, Vector2.ZERO, item.position, Objects.switch_radius(item) + ball.radius + 0.5).is_empty()
   if outside: item.latched = false
   elif item.active: item.latched = true
   if item.latched and not item.active: continue
  if item.type == "switch_target":
   if item.active: continue
   contact = Contact.circle_hit(start, motion, item.position, Objects.switch_radius(item) + ball.radius)
  elif item.type == "wall_switch":
   if item.active: continue
   var forward := Objects.forward(item)
   var distance := (start - Vector2(item.position)).dot(forward)
   if distance < ball.radius - 0.5 or motion.dot(forward) >= -0.001: continue
   contact = Contact.capsule_hit(start, motion, item.position, forward, maxf(0.0, Objects.switch_radius(item) - 2.0), ball.radius + 2.0)
   if not contact.is_empty() and Vector2(contact.normal).dot(forward) < 0.5: continue
  elif item.type == "diverter":
   contact = Contact.capsule_hit(start, motion, item.position, Objects.diverter_forward(item, item.state), float(item.properties.length) * 0.5 - 4.0, ball.radius + 4.0)
   if not contact.is_empty() and motion.dot(contact.normal) >= -0.001: continue
  elif item.type in ["one_way_gate", "spring"]:
   var forward := Objects.forward(item)
   var depth := 4.0 if item.type == "one_way_gate" else float(item.properties.width) * 0.5
   var half_segment := float(item.properties.width) * 0.5 - depth
   var radius := ball.radius + depth
   var overlap := Contact.capsule_hit(start, Vector2.ZERO, item.position, forward, half_segment, radius + 0.5)
   if item.type == "spring":
    if overlap.is_empty(): item.latched = false
    if item.latched or item.cooldown > 0.0: continue
   else:
    if item.open: continue
    if overlap.is_empty(): item.passing = false
    var distance: float = (start - Vector2(item.position)).dot(forward)
    # A ball entering from the allowed side stays unblocked until fully clear,
    # even if gravity reverses it while it straddles the flap.
    if not overlap.is_empty() and distance < 0.0: item.passing = true
    if item.passing or distance < 0.0 or motion.dot(forward) >= 0.0: continue
   contact = Contact.capsule_hit(start, motion, item.position, forward, half_segment, radius)
   if item.type == "one_way_gate" and not contact.is_empty() and motion.dot(contact.normal) >= 0.0: continue
  else: continue
  if not contact.is_empty():
   contact["item"] = item
   events.append(contact)
 events.sort_custom(func(a: Dictionary, b: Dictionary):
  if is_equal_approx(a.fraction, b.fraction): return str(a.item.object_id) < str(b.item.object_id)
  return a.fraction < b.fraction)
 for event: Dictionary in events:
  var item: Dictionary = event.item
  if item.type in ["switch_target", "wall_switch"]:
   _activate_switch(item)
  elif item.type in ["one_way_gate", "diverter"]:
   if item.open: continue # An earlier switch contact may complete its bank this step.
   var incoming := state.linear_velocity.dot(event.normal)
   if incoming >= 0.0: continue
   state.transform = Transform2D(0.0, start + motion * float(event.fraction) + Vector2(event.normal) * 0.05)
   state.linear_velocity -= Vector2(event.normal) * incoming * (1.0 + float(ball.tuning.effective.wall_restitution))
   ball._reset_steering("Diverter" if item.type == "diverter" else "One-way gate")
   item.pulse = 0.15
   return true
  elif item.type == "spring":
   item.latched = true
   item.cooldown = 0.12
   item.pulse = 0.2
   item.launch_count += 1
   state.transform = Transform2D(0.0, start + motion * float(event.fraction))
   state.linear_velocity = Objects.forward(item) * float(item.properties.launch_strength)
   state.angular_velocity = 0.0
   ball._reset_steering("Spring launch")
   traversal_event.emit(&"spring", item.object_id, &"used")
   return true
 return false

func advance_ramp(state: PhysicsDirectBodyState2D, dt: float) -> void:
 if ramp.is_empty(): return
 age += dt
 if age > 30.0:
  # Last-resort lifecycle reset for an externally obstructed mouth, never a rail exit.
  ball.teleport_to(ball.serve_position, Vector2.ZERO, true)
  return
 var path: Dictionary = ramp.path
 var tangent := RailPath.tangent(path, progress)
 var rise := (RailPath.height(path, progress + 0.5, ramp.properties.height) - RailPath.height(path, progress - 0.5, ramp.properties.height))
 var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 700.0)) * float(ball.tuning.effective.gravity_scale)
 var metric := sqrt(1.0 + rise * rise)
 var acceleration := gravity * (tangent.y - rise) / metric
 # A weak shot can roll back. A stalled/very long ride eventually rolls to entry.
 if age > 12.0: acceleration = -180.0
 speed = (speed + acceleration * dt) * exp(-float(ramp.properties.drag) * dt)
 speed = clampf(speed, -2400.0, 2400.0)
 progress += speed * dt / metric
 var at_end: bool = progress >= path.length
 var at_start := progress <= 0.0 and speed < 0.0
 progress = clampf(progress, 0.0, path.length)
 var point := RailPath.sample(path, progress)
 state.transform = Transform2D(0.0, point)
 state.linear_velocity = Vector2.ZERO
 state.angular_velocity = 0.0
 ball.ramp_height = RailPath.height(path, progress, ramp.properties.height)
 if at_end or at_start:
  var outgoing := RailPath.tangent(path, progress) * speed
  if not _exit_clear(point):
   # A moving flipper may temporarily cover the mouth; reverse along the rail.
   speed = -maxf(80.0, absf(speed)) if at_end else maxf(80.0, absf(speed))
   return
  leave_ramp()
  reentry_time = 0.3
  state.linear_velocity = outgoing
  ball._previous_step_velocity = outgoing

func _exit_clear(point: Vector2) -> bool:
 var shape := CircleShape2D.new()
 shape.radius = ball.radius + 0.1
 var query := PhysicsShapeQueryParameters2D.new()
 query.shape = shape
 query.transform = Transform2D(0.0, point)
 query.collision_mask = _saved_mask
 query.exclude = [ball.get_rid()]
 return ball.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
