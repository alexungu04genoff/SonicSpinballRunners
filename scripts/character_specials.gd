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
signal glide_started(direction: Vector2, duration: float)
signal glide_impact(body: Node2D, position: Vector2, normal: Vector2)
signal glide_ended(reason: String)
signal area_started(source: String, origin: Vector2, size: Vector2)
signal area_target_activated(source: String, target: Node2D, multiplier: int)
signal area_completed(source: String, targets: int, rings: int)
signal effects_cleared(reason: String)
signal meter_changed(value: float)
signal meter_spent(amount: float)
signal meter_replenished(amount: float)
const CHARACTERS := {"sonic": preload("res://data/characters/sonic.tres"), "tails": preload("res://data/characters/tails.tres"), "knuckles": preload("res://data/characters/knuckles.tres"), "shadow": preload("res://data/characters/shadow.tres")}
const CHARACTER_IDS: Array[String] = ["sonic", "tails", "knuckles", "shadow"]
const FLIGHT_KEY := "tail_flight"
const GLIDE_KEY := "knuckles_glide"
var game: Node
var character_id := "sonic"
var definition: CharacterDefinition = CHARACTERS.sonic
var target: Node2D
var pending_target: Node2D
var homing_remaining := 0.0
## Target-facing unit vector in gameplay XY at activation, zero when inactive.
var homing_direction := Vector2.ZERO
var flight_remaining := 0.0
var glide_remaining := 0.0
var glide_direction := Vector2.ZERO
var impact_target: Node2D
var _effect_generation := 0
var _area_pending := false
var feedback := "Collect rings and hit bumpers to charge"
var _scan_remaining := 0.0
var _flight_modifier := PhysicsModifier.new()
var _flight_weight := -1.0

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 _flight_modifier.display_name = "Tail Flight (temporary)"
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
 return game.special_meter >= definition.meter_cost and flight_remaining <= 0.0 and homing_remaining <= 0.0 and glide_remaining <= 0.0 and not _area_pending

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
  if distance < 55.0 * game.ball.radius / PlaygroundBall.RADIUS or distance > definition.target_range or priority > best_priority or (priority == best_priority and distance > best_distance):
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
  if distance < game.ball.radius or distance > definition.target_range or priority > best_priority or (priority == best_priority and distance > best_distance): continue
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
  feedback = "Special already active" if flight_remaining > 0.0 or homing_remaining > 0.0 or glide_remaining > 0.0 or _area_pending else "Need %d meter (%d / %d)" % [definition.meter_cost, game.special_meter, definition.meter_capacity]
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
  feedback = "HOMING ATTACK — hit the marked target!"
  homing_started.emit(pending_target, homing_direction)
 elif definition.ability == 1:
  flight_remaining = definition.flight_duration
  _flight_weight = -1.0
  _update_flight()
  # One bounded impulse can rescue a fall. It does not continuously power ascent.
  if game.ball.linear_velocity.y > 0.0:
   var lift: float = minf(definition.flight_lift_limit, game.ball.linear_velocity.y + 160.0)
   game.ball.apply_central_impulse(Vector2.UP * lift * game.ball.mass)
  feedback = "TAIL FLIGHT — guide the shot"
  flight_started.emit()
 elif definition.ability == 2:
  var axis: float = game.controls.steering
  if absf(axis) < 0.2:
   axis = signf(game.ball.linear_velocity.x) if absf(game.ball.linear_velocity.x) > 60.0 else 0.0
  if is_zero_approx(axis):
   feedback = "Hold left or right to choose a glide — meter kept"
   return false
  glide_direction = Vector2(signf(axis), 0.0)
  glide_remaining = maxf(0.1, definition.glide_duration)
  var modifier := PhysicsModifier.new()
  modifier.display_name = "Knuckles Glide (temporary)"
  modifier.multipliers = definition.glide_multipliers.duplicate()
  game.tuning.set_temporary(GLIDE_KEY, modifier)
  var change: float = clampf(glide_direction.x * definition.glide_speed - game.ball.linear_velocity.x, -definition.glide_impulse_limit, definition.glide_impulse_limit)
  game.ball.apply_central_impulse(Vector2(change * game.ball.mass, 0.0))
  feedback = "GLIDE — strike a side wall or bumper"
  glide_started.emit(glide_direction, glide_remaining)
 elif definition.ability != 3:
  return false
 game.special_meter = maxf(0.0, game.special_meter - definition.meter_cost)
 meter_spent.emit(definition.meter_cost)
 meter_changed.emit(game.special_meter)
 special_activated.emit(character_id)
 if definition.ability == 3:
  # Spend before pickup callbacks. Remote awards cannot refill their own cost.
  _release_area("chaos_blast", game.ball.position)
 return true

func _on_impact(body: Node2D, normal: Vector2, speed: float) -> void:
 if glide_remaining <= 0.0 or not can_use() or speed < definition.glide_min_impact_speed:
  return
 var eligible: bool = game.scoring_target_eligible(body)
 if not eligible:
  # Only a real terrain side qualifies. Gates, paddles, housings and generic
  # collision bodies are never ability triggers; a floor is not a side impact.
  if absf(normal.x) < 0.55:
   return
  eligible = game.playfield.is_glide_surface(body)
 if not eligible:
  return
 var origin: Vector2 = game.ball.position
 impact_target = body if body.has_meta("bumper") else null
 _area_pending = true
 clear_glide("Impact")
 glide_impact.emit(body, origin, normal)
 # Score the impact contact normally first, then activate the remaining wave
 # targets outside the physics callback. Resets invalidate this deferred work.
 _finish_shockwave.call_deferred(origin, _effect_generation)

func clear_glide(reason: String) -> void:
 var was_gliding := glide_remaining > 0.0
 glide_remaining = 0.0
 glide_direction = Vector2.ZERO
 game.tuning.clear_temporary(GLIDE_KEY)
 if was_gliding:
  glide_ended.emit(reason)

func _finish_shockwave(origin: Vector2, generation: int) -> void:
 if generation != _effect_generation:
  return
 if can_use():
  _release_area("shockwave", origin)
 impact_target = null
 _area_pending = false

func _area_contains(source: String, origin: Vector2, point: Vector2) -> bool:
 var offset := point - origin
 if source == "chaos_blast":
  return offset.length_squared() <= pow(clampf(definition.blast_radius, 0.0, 600.0), 2)
 return absf(offset.x) <= clampf(definition.shockwave_width, 0.0, 400.0) * 0.5 and offset.y <= game.ball.radius and offset.y >= -clampf(definition.shockwave_range, 0.0, 800.0)

func _wave_visible(origin: Vector2, point: Vector2, target_body: Node2D = null) -> bool:
 var query := PhysicsRayQueryParameters2D.create(origin, point, 1, [game.ball.get_rid()])
 var hit: Dictionary = game.ball.get_world_2d().direct_space_state.intersect_ray(query)
 return hit.is_empty() or hit.collider == target_body

func _release_area(source: String, origin: Vector2) -> void:
 var multiplier := clampi(definition.shockwave_multiplier, 1, 2) if source == "shockwave" else 1
 var size := Vector2(clampf(definition.shockwave_width, 0, 400), clampf(definition.shockwave_range, 0, 800)) if source == "shockwave" else Vector2.ONE * clampf(definition.blast_radius, 0, 600)
 area_started.emit(source, origin, size)
 var seen: Dictionary = {}
 var count := 0
 var pickups := 0
 for body: Node2D in game.playfield.bumpers:
  if not game.scoring_target_eligible(body) or seen.has(body.get_instance_id()):
   continue
  seen[body.get_instance_id()] = true
  if not _area_contains(source, origin, body.global_position):
   continue
  if source == "shockwave":
   var exposed: Vector2 = body.global_position
   # Wall-mounted centers can lie behind their rail. Test the exposed inward
   # face, while still requiring a real unobstructed ray to that same body.
   exposed.x += signf(origin.x - exposed.x) * game.playfield.bumper_radius(body) * 0.85
   if not _wave_visible(origin, exposed, body):
    continue
  if game.activate_area_target(body, source, multiplier):
   count += 1
   area_target_activated.emit(source, body, multiplier)
 for body: Node2D in game.enemy_targets():
  if not _area_contains(source, origin, body.global_position): continue
  if source == "shockwave" and not _wave_visible(origin, body.global_position): continue
  if game.destroy_enemy_target(body, StringName(source)):
   count += 1
   area_target_activated.emit(source, body, 1)
 for index in game.ring_field.rings.size():
  var ring: Dictionary = game.ring_field.rings[index]
  if not ring.active or not game.ring_field.ring_eligible(ring) or not _area_contains(source, origin, ring.home):
   continue
  if source == "shockwave" and not _wave_visible(origin, ring.home):
   continue
  if game.ring_field.claim_ring(index, source, multiplier):
   pickups += 1
 feedback = "%s — %d targets, %d rings" % ["SHOCKWAVE" if source == "shockwave" else "CHAOS BLAST", count, pickups]
 area_completed.emit(source, count, pickups)

func hit_multiplier(body: Node2D) -> int:
 if homing_remaining > 0.0 and is_instance_valid(pending_target) and body == pending_target:
  clear_homing("Hit")
  feedback = "HOMING HIT! Combo cashed out"
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
 game._target_awards.clear()
 _effect_generation += 1
 _area_pending = false
 impact_target = null
 clear_glide(reason)
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
 effects_cleared.emit(reason)

func act_advanced() -> void:
 _effect_generation += 1
 _area_pending = false
 impact_target = null
 if glide_remaining > 0.0:
  feedback = "Glide ended at Act boundary"
 clear_glide("Act advanced")
 effects_cleared.emit("Act advanced")

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
 if glide_remaining > 0.0:
  if glide_remaining <= delta:
   clear_glide("Expired")
   feedback = "Glide ended — no impact, no shockwave"
  else:
   glide_remaining -= delta
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
