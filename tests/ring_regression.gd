extends SceneTree
## Focused pickup checks use the real scoring listener, then a fast real-physics pass.
var game: Node
var field: RingField
var checks := 0
var failures := 0
var events: Array[Vector2] = []

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func prepare(points: PackedVector2Array, radius: float = 50.0, sentinel: bool = true) -> void:
 field.rings.clear()
 for point: Vector2 in points:
  field.add_ring(point)
 if sentinel:
  field.add_ring(Vector2(10000, 10000))
 events.clear()
 game.score = 0
 game.rings_collected = 0
 game.special_meter = 0
 game.tuning.set_value("ring_magnet_radius", radius)
 game.ball.position = Vector2(2000, 500)
 game.ball.serve_pending = false
 field.previous_ball_position = game.ball.position

func run() -> void:
 game = load("res://scenes/playground.tscn").instantiate()
 root.add_child(game)
 await frames(4)
 game.set_physics_process(false)
 game.presentation.set_process(false) # This fixture replaces the visual table's ring list.
 game.ball.freeze = true
 field = game.ring_field
 field.set_physics_process(false)
 # This scoring fixture replaces the ring list without rebuilding presentation.
 field.pickup_claimed.disconnect(game.presentation._on_ring_claimed)
 field.rack_reset.disconnect(game.presentation.clear_ring_pickups)
 field.collected.connect(func(where: Vector2): events.append(where))
 check(PhysicsTuning.BALANCED.ring_magnet_radius == 25.0 and PhysicsTuning.FLOATY.ring_magnet_radius == 25.0 and not PhysicsProfile.FIELDS.has("ring_magnet_strength"), "Both profiles use 25 px; obsolete attraction-speed control removed")

 prepare(PackedVector2Array([Vector2(2040, 500)]))
 field._physics_process(1.0 / 120.0)
 check(not field.rings[0].active and field.rings[0].position == Vector2(2040, 500) and events == [Vector2(2040, 500)] and game.score == 25 and game.special_meter == 5, "Nearby ring collects immediately at its authored position and awards once")
 for i in 120:
  field._physics_process(1.0 / 120.0)
 check(events.size() == 1 and game.rings_collected == 1 and game.score == 25 and game.special_meter == 5, "Repeated proximity does not duplicate score, meter or collection events")

 prepare(PackedVector2Array([Vector2(2051, 500), Vector2(2050, 500)]))
 for i in 120:
  field._physics_process(1.0 / 120.0)
 check(field.rings[0].active and field.rings[0].position == field.rings[0].home and not field.rings[1].active and events.size() == 1, "Outside rings remain fixed; exact radius boundary collects")

 var contact_radius: float = game.ball.radius + field.ring_radius
 prepare(PackedVector2Array([Vector2(2000 + contact_radius, 500), Vector2(2001 + contact_radius, 500)]), 0)
 field._physics_process(1.0 / 120.0)
 check(not field.rings[0].active and field.rings[1].active and game.score == 25, "Radius zero preserves the authored direct-contact pickup threshold")

 var swept_both_ways := true
 for direction: float in [-1.0, 1.0]:
  prepare(PackedVector2Array([Vector2(2100, 549), Vector2(2100, 551)]))
  field.previous_ball_position = Vector2(2100 - direction * 100, 500)
  game.ball.position = Vector2(2100 + direction * 100, 500)
  field._physics_process(1.0 / 120.0)
  swept_both_ways = swept_both_ways and not field.rings[0].active and field.rings[1].active and events.size() == 1
 check(swept_both_ways, "Swept magnet collects between distant endpoints in both directions without widening radius")

 prepare(PackedVector2Array([Vector2(2100, 500 + contact_radius), Vector2(2100, 501 + contact_radius)]), 0)
 game.ball.position = Vector2(2200, 500)
 field._physics_process(1.0 / 120.0)
 check(not field.rings[0].active and field.rings[1].active and events.size() == 1, "Swept direct contact stays reliable at high speed with magnetism disabled")

 prepare(PackedVector2Array([Vector2(2040, 500)]), 0)
 field._physics_process(1.0 / 120.0)
 var initially_active: bool = field.rings[0].active
 var magnet_chao := PhysicsModifier.new()
 magnet_chao.additions = {"ring_magnet_radius": 25.0}
 game.tuning.effective = PhysicsTuning.resolve(PhysicsTuning.BALANCED, {"ring_magnet_radius": 25.0}, [magnet_chao])
 field._physics_process(1.0 / 120.0)
 check(initially_active and not field.rings[0].active and PhysicsTuning.BALANCED.ring_magnet_radius == 25.0, "Live resolved radius and future Chao additions affect pickup without mutating the base")

 prepare(PackedVector2Array([Vector2(2100, 500)]))
 game.ball.serve_pending = true
 game.ball.position = Vector2(2200, 500)
 field._physics_process(1.0 / 120.0)
 game.ball.serve_pending = false
 field._physics_process(1.0 / 120.0)
 check(events.is_empty() and field.previous_ball_position == game.ball.position, "Waiting at serve suppresses pickups and discards the previous travel segment")

 prepare(PackedVector2Array([Vector2(2020, 500), Vector2(2040, 500)]), 50, false)
 field.rings.clear()
 field.add_pattern({"start": Vector2(2020, 500), "end": Vector2(2040, 500), "spacing": 20.0, "bonus_rack": true}, "bonus_test", field.active_owner_id)
 field._physics_process(1.0 / 120.0)
 field._physics_process(1.0 / 120.0)
 var first_rack: bool = events.size() == 2 and game.score == 550 and game.special_meter == 10 and field.rings[0].rack.respawn_remaining > 0.0
 field.advance_racks(1.1)
 field._physics_process(1.0 / 120.0)
 check(first_rack and events.size() == 4 and game.score == 1100 and game.rings_collected == 4 and game.special_meter == 20, "Explicit rack bonus occurs once per clear; timed reset rearms rings")

 prepare(PackedVector2Array([Vector2(2100, 545)]))
 game.controls.virtual_enabled = true
 game.controls.virtual_steering = 0
 game.tuning.effective.gravity_scale = 0
 var velocity := Vector2(24000, -300)
 game.ball.freeze = false
 game.ball.teleport_to(Vector2(2000, 500), velocity)
 field.set_physics_process(true)
 await frames(6)
 check(events.size() == 1 and game.ball.linear_velocity.distance_to(velocity) < 0.01 and field.rings[0].position == Vector2(2100, 545), "Real 24000 px/s pass collects a nearby ring while preserving both velocity components")

 print("RESULT | Rings | %d checks | %d failures" % [checks, failures])
 game.queue_free()
 await frames(2)
 quit(0 if failures == 0 else 1)
