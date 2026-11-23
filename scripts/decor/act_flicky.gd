extends Node3D
## One collisionless visitor shared by the active Act's presentation.
const Assets = preload("res://experiments/visual_lab/runners_sonic_assets.gd")
const IslandFlicky = preload("res://scripts/decor/island_flicky.gd")
const Scatter = preload("res://scripts/act_editor/decor_scatter.gd")
const FLIGHT_SECONDS := 1.25
const VISIT_CHANCE := 0.75
const GOLD_CHANCE := 0.2
var visit: Dictionary
var ball: PlaygroundBall
var bird: Node3D
var blue_bird: IslandFlicky
var gold_bird: Node3D
var checked_gold := false
var player: AnimationPlayer
var flight_time := -1.0
var heading := Vector2.ZERO
var cell := 0.0

static func choose_perch(document: Resource, runtime: Dictionary, offset: Vector2, rng: RandomNumberGenerator) -> Dictionary:
 if rng.randf() >= VISIT_CHANCE: return {}
 var size := float(document.cell_size)
 var solids: Array = runtime.terrain.filter(func(t: Dictionary): return t.closed and t.points.size() >= 3)
 if solids.is_empty(): return {}
 var bounds: Rect2 = document.terrain_bounds().grow(-size * 0.25)
 var floor_outline: PackedVector2Array = runtime.get("floor_outline", PackedVector2Array())
 var hardware: Array[Rect2] = []
 for item: Dictionary in runtime.objects:
  var footprint := Rect2(item.position, Vector2.ZERO).grow(size * 0.55)
  var transform := Transform2D(deg_to_rad(item.rotation_degrees), item.position)
  for point in ActGameplayObjects.local_points(item, size): footprint = footprint.expand(transform * point)
  hardware.append(footprint.grow(size * 0.2))
 for attempt in 36:
  var points: PackedVector2Array = solids[rng.randi_range(0, solids.size() - 1)].points
  var i := rng.randi_range(0, points.size() - 1)
  var next := points[(i + 1) % points.size()]
  var normal := points[i].direction_to(next).orthogonal()
  if normal.is_zero_approx(): continue
  var edge := points[i].lerp(next, rng.randf_range(0.15, 0.85))
  if not Geometry2D.is_point_in_polygon(edge + normal * size * 0.16, points): normal = -normal
  var perch := edge + normal * size * 0.16
  if not bounds.has_point(perch - offset): continue
  # Leave enough solid ground for both feet and an exposed lane beside the bank.
  var supported := true
  for foot: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
   if not Geometry2D.is_point_in_polygon(perch + foot * size * 0.09, points):
    supported = false
    break
  if not supported: continue
  var lane := edge - normal * size * 0.32
  if not bounds.has_point(lane - offset): continue
  if not floor_outline.is_empty() and not Geometry2D.is_point_in_polygon(lane - offset, floor_outline): continue
  if solids.any(func(t: Dictionary): return Geometry2D.is_point_in_polygon(lane, t.points)): continue
  if perch.distance_to(Vector2(document.spawn_position) + offset) < size: continue
  if hardware.any(func(area: Rect2): return area.has_point(perch)): continue
  var crowded := false
  for slot: Dictionary in document.decor_slots:
   if (perch - offset).distance_to(slot.position) < Scatter.radius(slot, size) + size * 0.18:
    crowded = true
    break
  if not crowded:
   return {"perch": perch, "phase": rng.randf(), "yaw": rng.randf_range(-0.55, 0.55), "gold": rng.randf() < GOLD_CHANCE, "departed": false}
 return {}

func enter(table: TablePresentation, state: Dictionary, cell_size: float) -> void:
 visit = state
 ball = table.ball
 cell = cell_size * table.SCALE
 flight_time = -1.0
 visible = not visit.is_empty() and not visit.departed
 set_process(visible)
 if bird:
  bird.hide()
  bird.process_mode = Node.PROCESS_MODE_DISABLED
 if not visible: return
 if visit.gold and not checked_gold:
  checked_gold = true
  gold_bird = Assets.animated_scene("flicky")
  if gold_bird:
   player = gold_bird.find_child("AnimationPlayer", true, false)
   if player and player.has_animation("ani_cmn_idle_loop"):
    add_child(gold_bird)
   else:
    gold_bird.free()
    gold_bird = null
    player = null
 bird = gold_bird if visit.gold else null
 if not bird:
  if not blue_bird:
   blue_bird = IslandFlicky.new(table)
   add_child(blue_bird)
  bird = blue_bird
 bird.show()
 bird.process_mode = Node.PROCESS_MODE_INHERIT
 position = table.map_point(visit.perch, table.RAIL_HEIGHT + table.RAIL_CAP_HEIGHT)
 rotation = Vector3(0.0, visit.yaw, 0.0)
 scale = Vector3.ONE
 bird.scale = Vector3.ONE * cell * (0.62 if bird == gold_bird else 1.2)
 if bird == gold_bird:
  # The Runners pivot sits 0.155 source units above the feet at rest.
  bird.position.y = 0.155 * bird.scale.y
  player.get_animation("ani_cmn_idle_loop").loop_mode = Animation.LOOP_LINEAR
  player.speed_scale = 1.0
  player.play("ani_cmn_idle_loop")
  player.seek(player.current_animation_length * float(visit.phase), true)
 else:
  blue_bird.set_process(true)
  blue_bird.set_animation_time(float(visit.phase) * IslandFlicky.CYCLE)

func _process(delta: float) -> void:
 if flight_time < 0.0:
  if ball.freeze or ball.serve_pending or ball.linear_velocity.length_squared() < 1.0: return
  var away: Vector2 = visit.perch - ball.position
  if away.length() * TablePresentation.SCALE > cell * 1.10: return
  heading = away.normalized() if not away.is_zero_approx() else Vector2.RIGHT.rotated(float(visit.yaw))
  flight_time = 0.0
  visit.departed = true
  if bird == gold_bird: player.speed_scale = 2.1
  else: blue_bird.set_process(false)
 flight_time += delta
 var t := minf(flight_time / FLIGHT_SECONDS, 1.0)
 if bird == blue_bird: blue_bird.set_flight_time(flight_time)
 var distance := cell * (0.5 * t + 2.1 * t * t)
 var perch := TablePresentation.map_point(visit.perch, TablePresentation.RAIL_HEIGHT + TablePresentation.RAIL_CAP_HEIGHT)
 position = perch + Vector3(heading.x * distance, cell * (1.7 * t + 0.15 * sin(PI * t)), heading.y * distance)
 rotation.y = lerp_angle(float(visit.yaw), atan2(heading.x, heading.y), smoothstep(0.0, 0.32, t))
 rotation.z = 0.12 * sin(t * TAU) * heading.x
 scale = Vector3.ONE * maxf(0.01, 1.0 - smoothstep(0.72, 1.0, t))
 if t >= 1.0:
  hide()
  set_process(false)
  bird.process_mode = Node.PROCESS_MODE_DISABLED
