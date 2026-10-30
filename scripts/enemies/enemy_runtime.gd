extends RefCounted
## Destructible 2D sensors. Rendering and abilities use this same atomic lifecycle.
signal enemy_destroyed(enemy_type: StringName, object_id: String, base_points: int, source: StringName)
signal enemy_respawned(enemy_type: StringName, object_id: String)
const Contact = preload("res://scripts/authored_act/gimmick_geometry.gd")
const DEFINITIONS := {"buzz_bomber": {"base_score": 200, "half_segment": 6.0, "radius": 6.0}}
const ENEMY_TOP_BOUNCE_SPEED := 420.0
const ENEMY_TOP_SPEED_RETENTION := 0.85
const ENEMY_MAX_BOUNCE_SPEED := 850.0
const ENEMY_BOTTOM_SPEED_RETENTION := 0.80
const PATROL_PAUSE_SECONDS := 0.65
const RESPAWN_SAFETY_DISTANCE := 128.0
const RESPAWN_FADE_SECONDS := 0.35
var items: Array[Dictionary] = []
var by_id: Dictionary = {}
var owner_act := ""
var destruction_allowed: Callable
var ball: PlaygroundBall
var previous_ball_position := Vector2.INF

static func is_enemy(type: String) -> bool:
 return DEFINITIONS.has(type)

func add(item: Dictionary) -> void:
 var definition: Dictionary = DEFINITIONS[item.type]
 item.merge({"enemy_type": item.type, "alive": true, "base_score": definition.base_score, "anchor": item.position, "previous_position": item.position, "direction": -1.0 if item.properties.starting_direction == "left" else 1.0, "pause_remaining": PATROL_PAUSE_SECONDS, "death_remaining": 0.0, "respawn_remaining": -1.0, "respawn_ready": false, "respawn_fade": 0.0, "target": null})
 items.append(item)
 by_id[item.object_id] = item

func bind_body(id: String, body: Node2D) -> void:
 if not by_id.has(id): return
 by_id[id].target = body
 body.set_meta("enemy_id", id)

func targets() -> Array[Node2D]:
 var result: Array[Node2D] = []
 for item: Dictionary in items:
  if item.alive and is_instance_valid(item.target): result.append(item.target)
 return result

func tick(delta: float) -> void:
 # The owning mechanics supplies the same active-Act/serve/transfer gate used
 # for destruction. Retry never resets these Act-owned clocks.
 if destruction_allowed.is_valid() and not destruction_allowed.call():
  reset_motion()
  return
 for item: Dictionary in items:
  item.previous_position = item.position
  item.death_remaining = maxf(0.0, item.death_remaining - delta)
  if not item.alive:
   _advance_respawn(item, delta)
   continue
  var remaining := delta
  if item.pause_remaining > 0.0:
   var pause_step := minf(remaining, item.pause_remaining)
   item.pause_remaining -= pause_step
   remaining -= pause_step
  var left := float(item.anchor.x) + float(item.properties.patrol_left)
  var right := float(item.anchor.x) + float(item.properties.patrol_right)
  if remaining <= 0.0 or is_equal_approx(left, right) or item.properties.patrol_speed <= 0.0: continue
  var target := left if item.direction < 0.0 else right
  item.position.x = move_toward(item.position.x, target, item.properties.patrol_speed * remaining)
  if is_equal_approx(item.position.x, target):
   item.direction *= -1.0
   item.pause_remaining = PATROL_PAUSE_SECONDS
  if is_instance_valid(item.target): item.target.position = item.position
 if is_instance_valid(ball): previous_ball_position = ball.position

func _safe_to_respawn(item: Dictionary) -> bool:
 if not is_instance_valid(ball): return true
 var region := Rect2(item.anchor + Vector2(item.properties.patrol_left, 0), Vector2(item.properties.patrol_right - item.properties.patrol_left, 0))
 var definition: Dictionary = DEFINITIONS[item.enemy_type]
 region = region.grow(RESPAWN_SAFETY_DISTANCE + ball.radius + (definition.radius + definition.half_segment) * float(item.properties.scale))
 var start := previous_ball_position if previous_ball_position.is_finite() else ball.position
 if region.has_point(ball.position) or region.has_point(start): return false
 var corners := [region.position, Vector2(region.end.x, region.position.y), region.end, Vector2(region.position.x, region.end.y)]
 for i in 4:
  if Geometry2D.segment_intersects_segment(start, ball.position, corners[i], corners[(i + 1) % 4]) != null: return false
 return true

func _advance_respawn(item: Dictionary, delta: float) -> void:
 if item.respawn_remaining < 0.0: return
 if not item.respawn_ready:
  item.respawn_remaining = maxf(0.0, item.respawn_remaining - delta)
  if item.respawn_remaining > 0.0: return
  item.respawn_ready = true
  item.position = item.anchor
  item.previous_position = item.anchor
  item.direction = -1.0 if item.properties.starting_direction == "left" else 1.0
  item.pause_remaining = PATROL_PAUSE_SECONDS
  if is_instance_valid(item.target): item.target.position = item.position
  return # The fade starts on a later clear frame, never in the expiry step.
 if not _safe_to_respawn(item):
  item.respawn_fade = 0.0
  return
 item.respawn_fade = minf(RESPAWN_FADE_SECONDS, item.respawn_fade + delta)
 if item.respawn_fade < RESPAWN_FADE_SECONDS: return
 item.alive = true
 item.respawn_ready = false
 item.respawn_remaining = -1.0
 item.respawn_fade = 0.0
 enemy_respawned.emit(StringName(item.enemy_type), item.object_id)

func destroy(id: String, source: StringName = &"contact") -> bool:
 if not by_id.has(id) or (destruction_allowed.is_valid() and not destruction_allowed.call()): return false
 var item: Dictionary = by_id[id]
 if not item.alive: return false
 item.alive = false # Consume before signals; callbacks cannot farm or recurse.
 item.death_remaining = 0.28
 item.respawn_remaining = float(item.properties.get("respawn_delay", 15.0))
 item.respawn_ready = false
 item.respawn_fade = 0.0
 enemy_destroyed.emit(StringName(item.enemy_type), id, int(item.base_score), source)
 return true

static func swept_contact(item: Dictionary, start: Vector2, finish: Vector2, ball_radius: float) -> Dictionary:
 var definition: Dictionary = DEFINITIONS[item.enemy_type]
 var scale_value := float(item.properties.scale)
 # Relative motion catches both fast balls and a target moving across the ball.
 var motion: Vector2 = finish - start - (Vector2(item.position) - Vector2(item.previous_position))
 return Contact.capsule_hit(start, motion, item.previous_position, Vector2.UP, definition.half_segment * scale_value, definition.radius * scale_value + ball_radius)

static func contact_velocity(velocity: Vector2, start: Vector2, finish: Vector2, enemy_start: Vector2, hit: Dictionary) -> Vector2:
 var result := velocity
 if hit.is_empty(): return result
 var normal: Vector2 = hit.normal
 if normal.y < -0.55 and start.y < enemy_start.y and finish.y > start.y and velocity.y > 0.0:
  result.y = -clampf(velocity.y * ENEMY_TOP_SPEED_RETENTION, ENEMY_TOP_BOUNCE_SPEED, ENEMY_MAX_BOUNCE_SPEED)
 elif normal.y > 0.55 and start.y > enemy_start.y and finish.y < start.y and velocity.y < 0.0:
  result.y *= ENEMY_BOTTOM_SPEED_RETENTION
 return result

func observe(state: PhysicsDirectBodyState2D, start: Vector2, ball_radius: float) -> void:
 if destruction_allowed.is_valid() and not destruction_allowed.call(): return
 var finish := state.transform.origin
 var hits: Array[Dictionary] = []
 for item: Dictionary in items:
  if not item.alive: continue
  var hit := swept_contact(item, start, finish, ball_radius)
  if not hit.is_empty(): hits.append({"item": item, "hit": hit})
 hits.sort_custom(func(a, b): return a.hit.fraction < b.hit.fraction)
 for entry: Dictionary in hits:
  if not destroy(entry.item.object_id): continue
  var velocity := contact_velocity(state.linear_velocity, start, finish, entry.item.previous_position, entry.hit)
  if velocity != state.linear_velocity:
   state.linear_velocity = velocity
   # Stop at the actual first contact when it redirects motion. Do not destroy
   # later targets from the discarded portion of that high-speed sweep.
   state.transform.origin = start.lerp(finish, entry.hit.fraction) + Vector2(entry.hit.normal) * 0.25
   break

func reset_motion() -> void:
 for item: Dictionary in items: item.previous_position = item.position
 if is_instance_valid(ball): previous_ball_position = ball.position
 # A Ball retry never changes alive, patrol position or respawn progress.
