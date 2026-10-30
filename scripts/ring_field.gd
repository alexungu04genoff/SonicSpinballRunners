class_name RingField
extends Node
## Rings stay at their authored positions. Collection never applies force to the ball.
signal collected(position: Vector2)
signal scoring_pickup(position: Vector2, source: String, multiplier: int)
signal pickup_claimed(index: int)
signal rack_reset
signal feature_completed(kind: StringName, object_id: String, bonus: int)
signal rack_completed(position: Vector2, object_id: String)
const RingTrails = preload("res://scripts/act_editor/ring_trails.gd")
const CONTACT_RADIUS := PlaygroundBall.RADIUS + 12.0
const RESPAWN_SAFETY_DISTANCE := 128.0
const RESPAWN_FADE_SECONDS := 0.35
## Per-instance geometry; ordinary tables retain their original 12 px ring contact.
var ring_radius := 12.0
var rings: Array[Dictionary] = []
var ball: PlaygroundBall
var tuning: PhysicsTuning
var previous_ball_position: Vector2
## Empty bounds preserve sandbox behavior; Zone mode collects only the active Act.
var collection_bounds := Rect2()
## Ownership is authoritative when neighboring Acts are resident simultaneously.
var active_owner_id := ""
var scoring_enabled := true
var last_pickup_source_id := ""
var _collecting_rail_id := ""

static func pattern_records(trails: Array, owner_id: String, offset := Vector2.ZERO) -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for index in trails.size():
  var trail: Dictionary = trails[index]
  var points := RingTrails.positions(trail)
  var source_id := owner_id + ":" + RingTrails.pattern_id(trail, index)
  var rack := _new_rack(source_id, owner_id, points.size(), RingTrails.scoring_settings(trail))
  if not points.is_empty():
   var bounds := Rect2(points[0] + offset, Vector2.ZERO)
   for point: Vector2 in points: bounds = bounds.expand(point + offset)
   rack["bounds"] = bounds
  for point_index in points.size():
   var at: Vector2 = points[point_index] + offset
   result.append({"home": at, "position": at, "active": true, "rack": rack, "source_id": "%s:ring_%d" % [source_id, point_index]})
 return result

static func document_records(document: Resource, owner_id: String, offset := Vector2.ZERO) -> Array[Dictionary]:
 var result := pattern_records(document.ring_trails, owner_id, offset)
 var objects = preload("res://scripts/act_editor/gameplay_objects.gd")
 var rails = preload("res://scripts/authored_act/rail_rings.gd")
 for index in document.gameplay_objects.size():
  var item: Dictionary = document.gameplay_objects[index]
  if item.type != "elevated_rail": continue
  var samples: Array[Dictionary] = rails.samples(item, objects.properties(item))
  if samples.is_empty(): continue
  var rail_id: String = objects.identity(item, index)
  var id := owner_id + ":rail:" + rail_id
  var rack := _new_rack(id, owner_id, samples.size(), RingTrails.scoring_settings({}))
  var bounds := Rect2(samples[0].position + offset, Vector2.ZERO)
  for sample: Dictionary in samples: bounds = bounds.expand(sample.position + offset)
  rack["bounds"] = bounds
  for i in samples.size():
   var sample: Dictionary = samples[i]
   var at: Vector2 = sample.position + offset
   result.append({"home": at, "position": at, "height": sample.height, "rail_id": rail_id,
    "rail_distance": sample.distance, "active": true, "rack": rack, "source_id": "%s:ring_%d" % [id, i]})
 return result

func collect_rail_progress(rail_id: String, from: float, to: float, owner_id: String) -> void:
 if not scoring_enabled or not is_instance_valid(ball) or ball.serve_pending or ball._teleport_pending: return
 _collecting_rail_id = rail_id
 for index in rings.size():
  var ring: Dictionary = rings[index]
  if ring.get("rail_id", "") != rail_id or ring.rack.owner_id != owner_id: continue
  if float(ring.rail_distance) >= minf(from, to) and float(ring.rail_distance) <= maxf(from, to): claim_ring(index)
 _collecting_rail_id = ""

static func _new_rack(source_id: String, owner_id: String, total: int, settings: Dictionary) -> Dictionary:
 return {"id": source_id, "owner_id": owner_id, "total": total, "remaining": total, "timeout_remaining": -1.0, "respawn_remaining": -1.0, "ready": false, "fade": 0.0, "settings": settings}

func ring_eligible(ring: Dictionary) -> bool:
 if not scoring_enabled: return false
 if not active_owner_id.is_empty():
  return ring.has("rack") and ring.rack.owner_id == active_owner_id
 return not collection_bounds.has_area() or collection_bounds.has_point(ring.home)

func add_ring(at: Vector2) -> void:
 # Legacy callers create ordinary single-ring patterns, never implicit +500 racks.
 var source_id := "%s:ring_pattern_%d" % [active_owner_id, rings.size()]
 var rack := _new_rack(source_id, active_owner_id, 1, RingTrails.scoring_settings({}))
 rack["bounds"] = Rect2(at, Vector2.ZERO)
 rings.append({"home": at, "position": at, "active": true, "rack": rack, "source_id": source_id + ":ring_0"})

func add_pattern(trail: Dictionary, source_id: String, owner_id := "", offset := Vector2.ZERO) -> void:
 var pattern := trail.duplicate(true)
 pattern.pattern_id = source_id
 rings.append_array(pattern_records([pattern], owner_id, offset))

func reset_rings() -> void:
 for ring: Dictionary in rings:
  if not ring_eligible(ring):
   continue
  ring.position = ring.home
  ring.active = true
  if ring.has("rack"): _reset_rack_state(ring.rack)
 rack_reset.emit()

static func _reset_rack_state(rack: Dictionary) -> void:
 rack.remaining = rack.total
 rack.timeout_remaining = -1.0
 rack.respawn_remaining = -1.0
 rack.ready = false
 rack.fade = 0.0

func _safe_to_respawn(rack: Dictionary) -> bool:
 if not is_instance_valid(ball): return true
 var region: Rect2 = rack.bounds.grow(RESPAWN_SAFETY_DISTANCE + ball.radius + ring_radius)
 if region.has_point(ball.position) or region.has_point(previous_ball_position): return false
 var corners := [region.position, Vector2(region.end.x, region.position.y), region.end, Vector2(region.position.x, region.end.y)]
 for i in 4:
  if Geometry2D.segment_intersects_segment(previous_ball_position, ball.position, corners[i], corners[(i + 1) % 4]) != null: return false
 return true

static func visibility_alpha(ring: Dictionary) -> float:
 if ring.active: return 1.0
 return float(ring.rack.fade) / RESPAWN_FADE_SECONDS if ring.has("rack") and ring.rack.ready else 0.0

func advance_racks(delta: float) -> void:
 if not scoring_enabled or delta <= 0.0: return
 var visited: Dictionary = {}
 var changed := false
 for ring: Dictionary in rings:
  if not ring_eligible(ring) or not ring.has("rack"): continue
  var rack: Dictionary = ring.rack
  var id: String = rack.id
  if visited.has(id): continue
  visited[id] = true
  var expired := false
  if rack.ready:
   if not _safe_to_respawn(rack):
    rack.fade = 0.0
    continue
   rack.fade = minf(RESPAWN_FADE_SECONDS, rack.fade + delta)
   if rack.fade < RESPAWN_FADE_SECONDS: continue
   _reset_rack_state(rack)
   for member: Dictionary in rings:
    if member.has("rack") and member.rack.id == id:
     member.position = member.home
     member.active = true
   changed = true
   continue
  if rack.respawn_remaining >= 0.0:
   rack.respawn_remaining = maxf(0.0, rack.respawn_remaining - delta)
   expired = rack.respawn_remaining <= 0.0
  elif rack.timeout_remaining >= 0.0:
   rack.timeout_remaining = maxf(0.0, rack.timeout_remaining - delta)
   expired = rack.timeout_remaining <= 0.0
  if not expired: continue
  rack.ready = true
  rack.fade = 0.0
  # Hide the entire failed attempt, including its uncollected rings. Waiting and
  # fading are non-collectible states; safety is rechecked throughout the fade.
  for member: Dictionary in rings:
   if member.has("rack") and member.rack.id == id: member.active = false
  changed = true
 if changed: rack_reset.emit()

func claim_ring(index: int, source: String = "", multiplier: int = 1) -> bool:
 if index < 0 or index >= rings.size():
  return false
 var ring: Dictionary = rings[index]
 if ring.has("rail_id") and ring.rail_id != _collecting_rail_id: return false
 if not ring.active or not ring_eligible(ring):
  return false
 # One atomic claim is shared by contact, magnet and area abilities. Cosmetic
 # flight and legacy collection observers still receive exactly one event.
 ring.active = false
 last_pickup_source_id = str(ring.get("source_id", "ring_%d" % index))
 var completed := false
 if ring.has("rack"):
  var rack: Dictionary = ring.rack
  if rack.timeout_remaining < 0.0: rack.timeout_remaining = rack.settings.timeout
  rack.remaining = maxi(0, int(rack.remaining) - 1)
  if rack.remaining == 0:
   rack.timeout_remaining = -1.0
   rack.respawn_remaining = rack.settings.respawn_delay
   completed = bool(rack.settings.bonus_rack)
 pickup_claimed.emit(index)
 scoring_pickup.emit(ring.position, source, multiplier)
 collected.emit(ring.position)
 if completed:
  # Completion follows its last physical pickup, through the fixed-feature path.
  # Respawn is armed before callbacks, so observers cannot complete it twice.
  feature_completed.emit(&"ring_rack", ring.rack.id, int(ring.rack.settings.completion_bonus))
  rack_completed.emit(ring.position, ring.rack.id)
 return true

func _physics_process(delta: float) -> void:
 if not is_instance_valid(ball) or not scoring_enabled: return
 if ball.serve_pending or ball._teleport_pending:
  previous_ball_position = ball._teleport_position if ball._teleport_pending else ball.position
  return
 advance_racks(delta)
 if ball.on_ramp:
  previous_ball_position = ball.position
  return
 # Radius is measured from the swept ball center to the stationary ring center.
 # A disabled or small magnet must never shrink the existing direct-contact pickup.
 var radius := maxf(ball.radius + ring_radius, float(tuning.effective.ring_magnet_radius))
 for i in rings.size():
  var ring: Dictionary = rings[i]
  if not ring.active or not ring_eligible(ring):
   continue
  var closest: Vector2 = Geometry2D.get_closest_point_to_segment(ring.position, previous_ball_position, ball.position)
  if closest.distance_squared_to(ring.position) <= radius * radius:
   # Deactivate before notifying score/meter listeners, so overlapping pickup
   # methods and subsequent ticks cannot award this ring twice in one rack.
   claim_ring(i)
 previous_ball_position = ball.position
