class_name CharacterSpecials
extends Node
## Owns ability state, never collisions or a second scoring system.
signal character_changed(id: String)
signal special_activated(id: String)
signal target_acquired(target: Node2D)
signal homing_started(target: Node2D, direction: Vector2)
signal homing_ended(reason: String)
signal special_hit(target: Node2D, multiplier: int)
signal flight_started
signal flight_ended(reason: String)
signal meter_changed(value: float)
signal meter_spent(amount: float)
signal meter_replenished(amount: float)
const CHARACTERS := {"sonic": preload("res://data/characters/sonic.tres"), "tails": preload("res://data/characters/tails.tres")}
const FLIGHT_KEY := "tail_flight"
var game: Node
var character_id := "sonic"
var definition: CharacterDefinition = CHARACTERS.sonic
var target: Node2D
var pending_target: Node2D
var homing_remaining := 0.0
## Target-facing unit vector in gameplay XY at activation, zero when inactive.
var homing_direction := Vector2.ZERO
var flight_remaining := 0.0
var feedback := "Collect rings and hit bumpers to charge"
var _scan_remaining := 0.0
var _flight_modifier := PhysicsModifier.new()
var _flight_weight := -1.0

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 _flight_modifier.display_name = "Tail Flight (temporary)"

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
 return not get_tree().paused and not game.generation_pending and not game.ball.serve_pending and not game.ball._teleport_pending and game.respawn_time < 0.0 and game.score_attack.state != ScoreAttack.State.COMPLETE and game.zone.state not in [ZoneRun.State.DRAFT, ZoneRun.State.COMPLETE]

func ready_to_use() -> bool:
 return game.special_meter >= definition.meter_cost and flight_remaining <= 0.0 and homing_remaining <= 0.0

func charge(base_amount: float) -> void:
 var before: float = game.special_meter
 game.special_meter = minf(definition.meter_capacity, before + base_amount * float(game.tuning.effective.special_meter_charge_multiplier))
 var gained: float = game.special_meter - before
 if gained > 0.0:
  meter_replenished.emit(gained)
  meter_changed.emit(game.special_meter)

func find_target() -> Node2D:
 var nearest: Node2D
 var best_distance := definition.target_range
 var query := PhysicsTestMotionParameters2D.new()
 query.from = game.ball.transform
 query.margin = 0.1
 var hit := PhysicsTestMotionResult2D.new()
 for chunk: TableChunk in game.chunks:
  for item: Dictionary in chunk.descriptors:
   if not item.has("body"):
    continue
   var candidate := item.body as Node2D
   if not is_instance_valid(candidate) or not candidate.has_meta("bumper"):
    continue
   if game.zone_enabled and not game.zone.acts[game.zone.active_act].bounds.has_point(candidate.global_position):
    continue
   var distance: float = game.ball.position.distance_to(candidate.global_position)
   if distance < 55.0 or distance > best_distance:
    continue
   # Sweep the full authoritative ball shape. Rails, paddles and closed gates
   # reject a target if they are the first obstruction, including narrow corners.
   query.motion = candidate.global_position - game.ball.position
   if PhysicsServer2D.body_test_motion(game.ball.get_rid(), query, hit) and hit.get_collider() == candidate:
    best_distance = distance
    nearest = candidate
 return nearest

func _set_target(value: Node2D) -> void:
 if target != value:
  target = value
  target_acquired.emit(target)

func activate() -> bool:
 if not can_use():
  feedback = "Launch and resume play before using Special"
  return false
 if not ready_to_use():
  feedback = "Special already active" if flight_remaining > 0.0 or homing_remaining > 0.0 else "Need %d meter (%d / %d)" % [definition.meter_cost, game.special_meter, definition.meter_capacity]
  return false
 if definition.ability == 0:
  _set_target(find_target())
  if not is_instance_valid(target):
   feedback = "No clear target in range — meter kept"
   return false
  var offset: Vector2 = target.global_position - game.ball.position
  var travel_time := clampf(offset.length() / definition.homing_speed, 0.08, 0.45)
  var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") * game.tuning.effective.gravity_scale
  var desired := (offset / travel_time - Vector2.DOWN * gravity * travel_time * 0.5).limit_length(definition.homing_speed * 1.15)
  var impulse: Vector2 = (desired - game.ball.linear_velocity).limit_length(definition.impulse_limit)
  game.ball.apply_central_impulse(impulse * game.ball.mass)
  pending_target = target
  homing_remaining = definition.hit_window
  homing_direction = offset.normalized()
  feedback = "HOMING ATTACK — hit the marked bumper!"
  homing_started.emit(pending_target, homing_direction)
 else:
  flight_remaining = definition.flight_duration
  _flight_weight = -1.0
  _update_flight()
  # One bounded impulse can rescue a fall. It does not continuously power ascent.
  if game.ball.linear_velocity.y > 0.0:
   var lift: float = minf(definition.flight_lift_limit, game.ball.linear_velocity.y + 160.0)
   game.ball.apply_central_impulse(Vector2.UP * lift * game.ball.mass)
  feedback = "TAIL FLIGHT — guide the shot"
  flight_started.emit()
 game.special_meter = maxf(0.0, game.special_meter - definition.meter_cost)
 meter_spent.emit(definition.meter_cost)
 meter_changed.emit(game.special_meter)
 special_activated.emit(character_id)
 return true

func hit_multiplier(body: Node2D) -> int:
 if homing_remaining > 0.0 and is_instance_valid(pending_target) and body == pending_target:
  clear_homing("Hit")
  feedback = "HOMING HIT!  ×%d target points" % definition.hit_multiplier
  special_hit.emit(body, definition.hit_multiplier)
  return definition.hit_multiplier
 return 1

func clear_homing(reason: String = "Cancelled") -> void:
 var was_homing := homing_direction != Vector2.ZERO
 pending_target = null
 homing_remaining = 0.0
 homing_direction = Vector2.ZERO
 _set_target(null)
 if was_homing:
  homing_ended.emit(reason)

func reset(clear_meter: bool = false, reason: String = "Reset") -> void:
 clear_homing(reason)
 var was_flying := flight_remaining > 0.0
 flight_remaining = 0.0
 game.tuning.clear_temporary(FLIGHT_KEY)
 if was_flying:
  flight_ended.emit(reason)
 if clear_meter:
  game.special_meter = 0.0
  meter_changed.emit(0.0)
 feedback = "Collect rings and hit bumpers to charge"

func _update_flight() -> void:
 var weight := smoothstep(0.0, definition.flight_fade, flight_remaining)
 if is_equal_approx(weight, _flight_weight):
  return
 _flight_weight = weight
 _flight_modifier.multipliers.clear()
 for key: String in definition.flight_multipliers:
  _flight_modifier.multipliers[key] = lerpf(1.0, definition.flight_multipliers[key], weight)
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
 if homing_remaining > 0.0:
  homing_remaining = maxf(0.0, homing_remaining - delta)
  if homing_remaining == 0.0:
   clear_homing("Expired")
   feedback = "Homing window ended — no bonus"
 _scan_remaining -= delta
 if _scan_remaining <= 0.0:
  _scan_remaining = 0.1
  if homing_remaining <= 0.0:
   _set_target(find_target() if definition.ability == 0 and ready_to_use() and can_use() else null)
