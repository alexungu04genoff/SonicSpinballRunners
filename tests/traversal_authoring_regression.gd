extends SceneTree
## Focused traversal contract and repeated real-ball trials; no alternate physics.
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const Clearance = preload("res://scripts/authored_act/terrain_clearance.gd")
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const ACT := "res://data/acts/Experiments/Traversal Diagnostic.tres"
var checks := 0
var failures := 0
var world: Node2D
var tuning: PhysicsTuning
var controls: PlaygroundInput
var ball: PlaygroundBall
var runtime: Dictionary
var events: Array = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

static func object(type: String, id: String, at: Vector2, props := {}) -> Dictionary:
 var item := Objects.make_placement(type)
 item.object_id = id
 item.position = at
 item.properties.merge(props, true)
 return item

static func fixture() -> Resource:
 var act := Document.new()
 act.title = "Traversal Diagnostic"
 act.design_thesis = "Compare 40 px full-height and 20 px carved horizontal crossings; 1x, 1.5x and 2x flippers; one paired Teleporter. Diagnostic, not a finished Act."
 act.spawn_position = Vector2(80, 440)
 act.goal_position = Vector2(500, 80)
 for y in [2, 5]:
  act.placements.append({"shape_id": "rectangle_1x3", "base_size": Vector2i(1, 3), "anchor": Vector2i(5, y), "quarter_turns": 0, "flip_h": false, "flip_v": false})
 act.gameplay_objects = [
  object("elevated_rail", "diagnostic_full_height", Vector2(80, 170), {"points": PackedVector2Array([Vector2.ZERO, Vector2(440, 0)]), "height": 40.0, "rings_enabled": false}),
  object("elevated_rail", "diagnostic_underpass", Vector2(80, 330), {"points": PackedVector2Array([Vector2.ZERO, Vector2(440, 0)]), "height": 20.0, "terrain_clearance": true, "rings_enabled": false}),
  object("left_flipper", "diagnostic_flipper_1", Vector2(100, 530)),
  object("left_flipper", "diagnostic_flipper_15", Vector2(230, 530), {"length_multiplier": 1.5}),
  object("right_flipper", "diagnostic_flipper_2", Vector2(450, 530), {"length_multiplier": 2.0}),
  object("teleporter", "diagnostic_teleporter", Vector2(80, 440), {"exit_x": 420.0, "exit_y": -340.0, "exit_angle": 90.0}),
 ]
 return act

func frames(count: int) -> void:
 for i in count: await physics_frame

func compile(act: Resource) -> Dictionary:
 return Compiler.compile(act, tuning, controls, ball)

func run() -> void:
 world = Node2D.new()
 root.add_child(world)
 tuning = PhysicsTuning.new()
 controls = PlaygroundInput.new()
 controls.virtual_enabled = true
 world.add_child(tuning)
 world.add_child(controls)
 ball = PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 var act := fixture()
 check(act.validation_errors().is_empty(), "Diagnostic data validates")
 if "--write-fixture" in OS.get_cmdline_user_args():
  check(act.save_document(ACT) == OK, "Diagnostic Act saved through normal persistence")
 var loaded := Document.load_document(ACT)
 check(loaded.document != null and loaded.document.fingerprint() == act.fingerprint(), "Diagnostic round trip is exact")
 runtime = compile(act)
 check(runtime.error.is_empty(), "Full-height and underpass routes compile: " + runtime.error)
 if not runtime.error.is_empty(): world.free(); ball.free(); quit(1); return
 var rejected: Resource = act.copy_document()
 rejected.gameplay_objects[1].properties.terrain_clearance = false
 var invalid := compile(rejected)
 check(not invalid.error.is_empty(), "Same 20 px crossing is rejected without explicit clearance")
 rejected = act.copy_document()
 rejected.gameplay_objects[1].properties.height = 10.0
 invalid = compile(rejected)
 check(not invalid.error.is_empty(), "Clearance keeps a solid terrain base and rejects too-low crossings")
 rejected = act.copy_document()
 rejected.gameplay_objects[1].position.x = 260.0
 invalid = compile(rejected)
 check(not invalid.error.is_empty(), "Terrain carve cannot hide an obstructed mouth")
 rejected = act.copy_document()
 rejected.gameplay_objects[-1].properties.exit_x = 190.0
 rejected.gameplay_objects[-1].properties.exit_y = -140.0
 invalid = compile(rejected)
 check(not invalid.error.is_empty(), "Teleporter rejects exit inside terrain")
 rejected.gameplay_objects[-1].properties.exit_x = 900.0
 invalid = compile(rejected)
 check(not invalid.error.is_empty(), "Teleporter rejects exit outside Act")
 rejected = act.copy_document()
 rejected.gameplay_objects[-1].properties.exit_x = 20.0
 rejected.gameplay_objects[-1].properties.exit_y = 90.0
 invalid = compile(rejected)
 check(not invalid.error.is_empty(), "Teleporter rejects flipper sweep exit")
 world.add_child(runtime.root)
 world.add_child(ball)
 await frames(2)
 for i in 3:
  var flipper: PlaygroundFlipper = runtime.flippers[i]
  var length: float = [32.5, 48.75, 65.0][i]
  var collision: CollisionShape2D = flipper.get_child(0)
  check(is_equal_approx(flipper.length, length) and is_equal_approx(collision.shape.height, length + 5.0) and is_equal_approx(collision.position.x, length * 0.5), "Flipper %d has exact authoritative length and fixed pivot" % i)
  var silhouette := Objects.local_points(act.gameplay_objects[i + 2], 50.0)
  var max_x := -INF
  for point: Vector2 in silhouette: max_x = maxf(max_x, point.x)
  check(is_equal_approx(max_x, length + 2.5), "Editor capsule matches flipper %d" % i)
 var legacy := {"type": "left_flipper", "position": Vector2.ZERO, "rotation_degrees": 0.0}
 check(Objects.flipper_length(legacy, 50.0) == 32.5 and Objects.flipper_length(legacy, 100.0) == 65.0, "Missing length property preserves exact old dimensions")
 var cuts := Clearance.crossings(runtime.mechanics.items, ball.radius)
 check(is_equal_approx(Clearance.top_at(Vector2(275, 330), cuts), 15.0), "20 px crossing lowers terrain to 15 px, leaving deck and gap")
 check(is_equal_approx(Clearance.top_at(Vector2(275, 250), cuts), 32.5), "Uncrossed terrain retains normal height")
 _mesh_check(cuts)
 _bake_check(act)
 runtime.mechanics.traversal_event.connect(func(kind, id, phase): events.append([kind, id, phase]))
 # Repeated offsets avoid selecting one lucky aligned shot as the ramp result.
 for rail_index in 2:
  for entry_speed in [100.0, 110.0, 120.0, 130.0, 140.0, 150.0, 180.0, 210.0, 240.0, 270.0, 300.0]:
   var completed := 0
   for offset in [-3.0, 0.0, 3.0]:
    var rail: Dictionary = runtime.mechanics.items[rail_index]
    ball.teleport_to(Vector2(rail.position) - Vector2(1, -offset), Vector2(entry_speed, 0))
    events.clear()
    await frames(2)
    for frame in 1100:
     await frames(1)
     if events.has([&"elevated_rail", rail.object_id, &"completed"]): completed += 1; break
     if events.has([&"elevated_rail", rail.object_id, &"exited"]): break
     if frame > 10 and not ball.on_ramp: break
    if entry_speed == 300.0: print("RAMP_DETAIL | ", rail.object_id, " ", events, " position=", ball.position, " speed=", ball.linear_velocity, " reentry=", runtime.mechanics.reentry_time)
   print("RAMP_TRIAL | peak=", act.gameplay_objects[rail_index].properties.height, " length=440 speed=", entry_speed, " completed=", completed, "/3")
   if entry_speed == 300.0: check(completed == 3, "Both crossings complete repeatedly at 300 px/s without Dash Panels")
 events.clear()
 var rings := RingField.new()
 rings.ball = ball
 rings.tuning = tuning
 world.add_child(rings)
 rings.previous_ball_position = Vector2(80, 440)
 rings.add_ring(Vector2(290, 270))
 ball.teleport_to(Vector2(80, 440), Vector2.ZERO)
 await frames(3)
 check(events.has([&"teleporter", "diagnostic_teleporter", &"used"]) and ball.position.x > 495.0, "Zero-speed ball transfers to paired exit")
 check(rings.rings[0].active, "Discrete transfer does not collect Rings between endpoints")
 check(ball.steering_last_reset == "Teleporter" and is_zero_approx(ball.steering_contribution), "Transfer resets steering")
 # Put a second entrance directly at arrival; even after cooldown it cannot bounce.
 var back := object("teleporter", "diagnostic_return", Vector2(500, 100), {"radius": 60.0, "exit_x": -420.0, "exit_y": 340.0})
 runtime.mechanics.add_object(back, {})
 tuning.effective.gravity_scale = 0.0
 ball.teleport_to(Vector2(80, 440), Vector2.ZERO)
 events.clear()
 await frames(120)
 check(events.size() == 1 and ball.position.distance_to(Vector2(500, 100)) < 2.0, "Overlapping arrival portal cannot ping-pong after cooldown")
 ball.teleport_to(Vector2(80, 440), Vector2(0, -220))
 await frames(3)
 check(ball.linear_velocity.x > 215.0 and absf(ball.linear_velocity.y) < 1.0, "Transfer preserves speed and rotates it along exit arrow")
 check(ball._contact_cooldowns.is_empty() and ball._flipper_strike.is_empty(), "Transfer clears old contact and flipper state")
 # Native obstacle added after compilation exercises dynamic safety at transfer time.
 var blocker := StaticBody2D.new()
 var shape := CollisionShape2D.new()
 shape.shape = CircleShape2D.new()
 shape.shape.radius = 12.0
 blocker.position = Vector2(500, 100)
 blocker.add_child(shape)
 world.add_child(blocker)
 await frames(2)
 events.clear()
 ball.teleport_to(Vector2(80, 440), Vector2.ZERO)
 await frames(5)
 check(events.is_empty() and ball.position.distance_to(Vector2(80, 440)) < 2.0, "Dynamic blocked exit leaves ball safely at entrance")
 ball.teleport_to(Vector2(220, 280), Vector2(220, 0))
 await frames(30)
 check(ball.position.x < 244.0, "Ground ball still collides with the original terrain under a carved route")
 world.free()
 await frames(2)
 print("RESULT | Traversal authoring | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func _mesh_check(cuts: Array[Dictionary]) -> void:
 var presenter := TablePresentation.new()
 var outline := PackedVector2Array([Vector2(250, 100), Vector2(300, 100), Vector2(300, 400), Vector2(250, 400)])
 var source := presenter._prism(outline, 0.325, null, null)
 var lowered := Clearance.lower_mesh(source, cuts, 0.01)
 var low := INF
 var high := -INF
 var finite := true
 for surface in lowered.get_surface_count():
  var arrays := lowered.surface_get_arrays(surface)
  for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
   if vertex.z > 3.2 and vertex.z < 3.4 and surface == 0: low = minf(low, vertex.y); high = maxf(high, vertex.y)
  for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: finite = finite and normal.is_finite() and normal.length() > 0.99
 check(is_equal_approx(low, 0.15) and is_equal_approx(high, 0.15), "Actual terrain cap mesh follows the shared clearance rule")
 check(finite, "Lowered top and side mesh normals remain finite and normalized")
 check(is_equal_approx(source.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0].y, 0.325), "Clearance never mutates the source mesh")
 presenter.free()

func _bake_check(act: Resource) -> void:
 var bake := Bake.new()
 bake.source_fingerprint = act.fingerprint()
 bake.theme_id = "green_hill"
 bake.physics_validated = true
 bake.pipeline_fingerprint = Bake.pipeline_hash("green_hill")
 for terrain: Dictionary in runtime.terrain:
  var records: Array = []
  for owner: int in terrain.body.get_shape_owners():
   for index in terrain.body.shape_owner_get_shape_count(owner): records.append({"shape": terrain.body.shape_owner_get_shape(owner, index), "transform": terrain.body.shape_owner_get_transform(owner)})
  bake.collisions.append(records)
 var baked := Compiler.compile_baked(act, tuning, controls, ball, bake, bake.pipeline_fingerprint)
 check(baked.error.is_empty() and baked.flippers[2].length == 65.0 and baked.mechanics.items[1].properties.terrain_clearance and baked.mechanics.by_id.has("diagnostic_teleporter"), "Validated production compiler preserves all traversal properties")
 for i in runtime.terrain.size(): check(runtime.terrain[i].points == baked.terrain[i].points, "Baked terrain keeps authoritative original outline")
 baked.root.free()
