class_name CharacterSpecials
extends Node
## Shared type actions. The ball owns integration/contact; Scorecraft owns awards.
## Legacy homing signal names remain the presentation/scoring adapter contract.
signal character_changed(id: String)
signal special_activated(id: String)
signal target_acquired(target: Node2D)
signal homing_started(target: Node2D, direction: Vector2)
signal homing_ended(reason: String)
signal special_hit(target: Node2D, multiplier: int)
signal flight_started
signal flight_lift_applied
signal flight_ended(reason: String)
signal area_started(source: String, origin: Vector2, size: Vector2)
signal area_target_activated(source: String, target: Node2D, multiplier: int)
signal area_completed(source: String, targets: int, rings: int)
signal effects_cleared(reason: String)
signal meter_changed(value: float)
signal meter_spent(amount: float)
signal meter_replenished(amount: float)
const CHARACTERS := {"sonic": preload("res://data/characters/sonic.tres"), "tails": preload("res://data/characters/tails.tres"), "knuckles": preload("res://data/characters/knuckles.tres"), "shadow": preload("res://data/characters/shadow.tres")}
const CHARACTER_IDS: Array[String] = ["sonic", "tails", "knuckles", "shadow"]
const FLIGHT_KEY := "type_flight"
var game: Node
var character_id := "sonic"
var definition: CharacterDefinition = CHARACTERS.sonic
var action: TypeAction:
 get: return definition.type_action
var target: Node2D
var pending_target: Node2D
var homing_remaining := 0.0
## Current target-facing unit vector in gameplay XY, zero when inactive.
var homing_direction := Vector2.ZERO
var flight_remaining := 0.0
var _dash_exit_pending := false
var _dash_exit_direction := Vector2.ZERO
var _area_pending := false
var feedback := "Collect rings and hit bumpers to charge"
var _scan_remaining := 0.0
var _flight_modifier := PhysicsModifier.new()
var _flight_weight := -1.0

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 _flight_modifier.display_name = "Fly · Flight (temporary)"
 game.ball.type_action_controller = self
 game.ball.physical_impact.connect(_on_impact)

func select_character(id: String) -> void:
 if not CHARACTERS.has(id):
  return
 reset(true, "Character changed")
 character_id = id
 game.character_id = id
 definition = CHARACTERS[id]
 game.tuning.use_profile(definition.profile)
 character_changed.emit(id)

func can_use() -> bool:
 return not get_tree().paused and not game.loading_act and not game.ball.on_ramp and not game.ball.serve_pending and not game.ball._teleport_pending and game.respawn_time < 0.0

func ready_to_use() -> bool:
 return game.special_meter >= definition.meter_cost and flight_remaining <= 0.0 and homing_remaining <= 0.0 and not _area_pending

func charge(base_amount: float) -> void:
 var before: float = game.special_meter
 game.special_meter = minf(definition.meter_capacity, before + base_amount * float(game.tuning.effective.special_meter_charge_multiplier))
 var gained: float = game.special_meter - before
 if gained > 0.0:
  meter_replenished.emit(gained)
  meter_changed.emit(game.special_meter)

func find_target() -> Node2D:
 var nearest: Node2D
 var best_distance := action.target_range
 var best_priority := 3
 var query := PhysicsTestMotionParameters2D.new()
 query.from = game.ball.transform
 query.margin = 0.1 * game.ball.radius / PlaygroundBall.RADIUS
 var hit := PhysicsTestMotionResult2D.new()
 for candidate: Node2D in game.playfield.bumpers:
  if not game.scoring_target_eligible(candidate):
   continue
  var distance: float = game.ball.position.distance_to(candidate.global_position)
  var priority := _homing_priority(candidate, &"bumper")
  if distance < 0.01 or distance > action.target_range or priority > best_priority or (priority == best_priority and distance > best_distance):
   continue
  # Sweep the full authoritative ball shape. Terrain, paddles and closed gates
  # reject a target if they are the first obstruction, including narrow corners.
  query.motion = candidate.global_position - game.ball.position
  if PhysicsServer2D.body_test_motion(game.ball.get_rid(), query, hit) and hit.get_collider() == candidate:
   best_distance = distance
   best_priority = priority
   nearest = candidate
 for candidate: Node2D in game.enemy_targets():
  var distance: float = game.ball.position.distance_to(candidate.global_position)
  var priority := _homing_priority(candidate, &"enemy")
  if distance < 0.01 or distance > action.target_range or priority > best_priority or (priority == best_priority and distance > best_distance): continue
  query.motion = candidate.global_position - game.ball.position
  # Enemies are sensors, so a clear full-ball sweep has no native collision.
  if not PhysicsServer2D.body_test_motion(game.ball.get_rid(), query, hit):
   best_distance = distance
   best_priority = priority
   nearest = candidate
 return nearest

func _homing_priority(candidate: Node2D, kind: StringName) -> int:
 var source := str(candidate.get_meta("scoring_source", candidate.get_instance_id()))
 if not game.scorecraft.enabled or game.scorecraft.builder_eligible(kind, source): return 0
 return 1 if kind == &"enemy" else 2

func _set_target(value: Node2D) -> void:
 if target != value:
  target = value
  target_acquired.emit(target)

func activate() -> bool:
 if not can_use():
  feedback = "Launch and resume play before using Special"
  return false
 if not ready_to_use():
  feedback = "Special already active" if flight_remaining > 0.0 or homing_remaining > 0.0 or _area_pending else "Need %d meter (%d / %d)" % [definition.meter_cost, game.special_meter, definition.meter_capacity]
  return false
 if action.kind == TypeAction.Kind.SPEED:
  _set_target(find_target())
  if not is_instance_valid(target):
   feedback = "No clear target in range — meter kept"
   return false
  var offset: Vector2 = target.global_position - game.ball.position
  pending_target = target
  homing_direction = offset.normalized()
  homing_remaining = action.dash_duration(offset.length(), -game.ball.linear_velocity.dot(homing_direction))
  _dash_exit_pending = false
  feedback = "TARGET DASH — physical contact cashes out the combo"
  homing_started.emit(pending_target, homing_direction)
 elif action.kind == TypeAction.Kind.FLY:
  flight_remaining = action.flight_duration
  _flight_weight = -1.0
  _update_flight()
  # One bounded impulse can rescue a fall. It does not continuously power ascent.
  if game.ball.linear_velocity.y > 0.0:
   var lift: float = minf(action.flight_lift_limit, game.ball.linear_velocity.y + 160.0)
   game.ball.apply_central_impulse(Vector2.UP * lift * game.ball.mass)
   if lift > 0.0: flight_lift_applied.emit()
  feedback = "FLIGHT — guide the shot"
  flight_started.emit()
 elif action.kind != TypeAction.Kind.POWER:
  return false
 # Prevent synchronous callback reentry while a radial use is being resolved.
 _area_pending = action.kind == TypeAction.Kind.POWER
 game.special_meter = maxf(0.0, game.special_meter - definition.meter_cost)
 meter_spent.emit(definition.meter_cost)
 meter_changed.emit(game.special_meter)
 special_activated.emit(character_id)
 if action.kind == TypeAction.Kind.POWER:
  # Spend before pickup callbacks. Remote awards cannot refill their own cost.
  _release_area("table_smash", game.ball.position)
  _area_pending = false
 return true

func _on_impact(body: Node2D, _normal: Vector2, _speed: float) -> void:
 if homing_remaining > 0.0 and body != pending_target:
  clear_homing("Collision")

func integrate_guidance(state: PhysicsDirectBodyState2D) -> void:
 if homing_remaining <= 0.0: return
 if not can_use() or not is_instance_valid(pending_target):
  clear_homing("Target lost")
  return
 var enemy := pending_target.has_meta("enemy_id")
 if (enemy and not game.enemy_targets().has(pending_target)) or (not enemy and not game.scoring_target_eligible(pending_target)):
  clear_homing("Target lost")
  return
 homing_remaining = maxf(0.0, homing_remaining - state.step)
 var offset: Vector2 = pending_target.global_position - state.transform.origin
 if homing_remaining == 0.0 or offset.length() > action.target_range * 1.5:
  clear_homing("Expired")
  feedback = "Target Dash ended — no bonus"
  return
 # Revalidate a moving/closing route using the full ball, never steer through walls.
 var query := PhysicsTestMotionParameters2D.new()
 query.from = state.transform
 query.motion = offset
 query.margin = 0.1 * game.ball.radius / PlaygroundBall.RADIUS
 var hit := PhysicsTestMotionResult2D.new()
 if PhysicsServer2D.body_test_motion(game.ball.get_rid(), query, hit) and hit.get_collider() != pending_target:
  clear_homing("Blocked")
  return
 homing_direction = offset.normalized()
 var contact_radius: float = game.ball.radius + (12.0 if enemy else game.playfield.bumper_radius(pending_target))
 state.linear_velocity = action.guided_velocity(state.linear_velocity, offset, contact_radius, state.step)
 game.ball._reset_steering("Target Dash")

func finish_guidance(state: PhysicsDirectBodyState2D) -> void:
 if not _dash_exit_pending: return
 _dash_exit_pending = false
 var velocity := state.linear_velocity
 if _dash_exit_direction != Vector2.ZERO:
  # Preserve tangent motion and an existing outward rebound, but replace inward
  # enemy pass-through with a small recoil. No scripted position changes.
  var outward := velocity.dot(_dash_exit_direction)
  velocity += _dash_exit_direction * maxf(0.0, action.dash_contact_speed - outward)
 state.linear_velocity = velocity.limit_length(action.dash_exit_speed)
 _dash_exit_direction = Vector2.ZERO
 game.ball._reset_steering("Target Dash exit")

func _area_contains(_source: String, origin: Vector2, point: Vector2) -> bool:
 return origin.distance_squared_to(point) <= pow(clampf(action.smash_radius, 0.0, 600.0), 2)

func _release_area(source: String, origin: Vector2) -> void:
 if source != "table_smash": return
 # Reuse the original radial target lists and atomic claim/cooldown callbacks.
 # Stateful switches, banks, rails, gates, slingshots and springs are not in them.
 area_started.emit(source, origin, Vector2.ONE * clampf(action.smash_radius, 0, 600))
 var seen: Dictionary = {}
 var count := 0
 var pickups := 0
 for body: Node2D in game.playfield.bumpers:
  if not game.scoring_target_eligible(body) or seen.has(body.get_instance_id()): continue
  seen[body.get_instance_id()] = true
  if _area_contains(source, origin, body.global_position) and game.activate_area_target(body, source, 1):
   count += 1
   area_target_activated.emit(source, body, 1)
 for body: Node2D in game.enemy_targets():
  if seen.has(body.get_instance_id()): continue
  seen[body.get_instance_id()] = true
  if _area_contains(source, origin, body.global_position) and game.destroy_enemy_target(body, StringName(source)):
   count += 1
   area_target_activated.emit(source, body, 1)
 for index in game.ring_field.rings.size():
  var ring: Dictionary = game.ring_field.rings[index]
  if not ring.active or not game.ring_field.ring_eligible(ring) or not _area_contains(source, origin, ring.home): continue
  if game.ring_field.claim_ring(index, source, 1): pickups += 1
 feedback = "TABLE SMASH — %d targets, %d rings" % [count, pickups]
 area_completed.emit(source, count, pickups)

func hit_multiplier(body: Node2D) -> int:
 if homing_remaining > 0.0 and is_instance_valid(pending_target) and body == pending_target:
  _dash_exit_direction = -homing_direction
  clear_homing("Hit")
  feedback = "TARGET DASH HIT! Combo cashed out"
  special_hit.emit(body, 5)
  return 5 # Existing Scorecraft cash-out marker, not a new 5x multiplier.
 return 1

func clear_homing(reason: String = "Cancelled") -> void:
 var was_homing := homing_direction != Vector2.ZERO
 pending_target = null
 homing_remaining = 0.0
 homing_direction = Vector2.ZERO
 _set_target(null)
 if was_homing:
  _dash_exit_pending = true
  if reason != "Hit": _dash_exit_direction = Vector2.ZERO
  homing_ended.emit(reason)

func reset(clear_meter: bool = false, reason: String = "Reset") -> void:
 game._target_awards.clear()
 _area_pending = false
 clear_homing(reason)
 _dash_exit_pending = false
 _dash_exit_direction = Vector2.ZERO
 var was_flying := flight_remaining > 0.0
 flight_remaining = 0.0
 game.tuning.clear_temporary(FLIGHT_KEY)
 if was_flying:
  flight_ended.emit(reason)
 if clear_meter:
  game.special_meter = 0.0
  meter_changed.emit(0.0)
 feedback = "Collect rings and hit bumpers to charge"
 effects_cleared.emit(reason)

func act_advanced() -> void:
 reset(false, "Act advanced")

func _update_flight() -> void:
 var weight := smoothstep(0.0, action.flight_fade, flight_remaining)
 if is_equal_approx(weight, _flight_weight):
  return
 _flight_weight = weight
 _flight_modifier.multipliers.clear()
 for key: String in action.flight_multipliers:
  _flight_modifier.multipliers[key] = lerpf(1.0, action.flight_multipliers[key], weight)
 game.tuning.set_temporary(FLIGHT_KEY, _flight_modifier)

func _physics_process(delta: float) -> void:
 if flight_remaining > 0.0:
  flight_remaining = maxf(0.0, flight_remaining - delta)
  if flight_remaining > 0.0:
   _update_flight()
  else:
   game.tuning.clear_temporary(FLIGHT_KEY)
   feedback = "Flight ended — ordinary physics restored"
   flight_ended.emit("Expired")
 _scan_remaining -= delta
 if _scan_remaining <= 0.0:
  _scan_remaining = 0.1
  if homing_remaining <= 0.0:
   _set_target(find_target() if action.kind == TypeAction.Kind.SPEED and ready_to_use() and can_use() else null)
