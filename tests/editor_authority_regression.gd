extends SceneTree
## Disk bake and real Prototype authority for disposable qualification Acts.
const Fixture = preload("res://tests/editor_qualification_fixture.gd")
const Act = Fixture.Act
const Objects = Fixture.Objects
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const Session = preload("res://scripts/prototype/session.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
const MechanicsVisual = preload("res://scripts/authored_act/mechanics_presentation.gd")
var checks := 0
var failures := 0
var failed: Array[String] = []

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  failed.append(message)
  push_error(message)

func collision_records(body: StaticBody2D) -> Array:
 var result := []
 for owner: int in body.get_shape_owners():
  for index in body.shape_owner_get_shape_count(owner):
   var shape: Shape2D = body.shape_owner_get_shape(owner, index)
   result.append({"class": shape.get_class(), "transform": body.shape_owner_get_transform(owner),
    "points": shape.points if shape is ConvexPolygonShape2D else (shape.segments if shape is ConcavePolygonShape2D else PackedVector2Array())})
 return result

func check_compiler(document: Resource, saved: Resource, pipeline: String) -> void:
 var tuning := PhysicsTuning.new()
 var controls := PlaygroundInput.new()
 var ball := PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 var source := Compiler.compile(document, tuning, controls, ball)
 var disk := Compiler.compile_baked(document, tuning, controls, ball, saved, pipeline)
 check(source.error.is_empty() and disk.error.is_empty(), "Both source and verified disk collision compilers accept the edited Act: " + source.error + disk.error)
 if source.error.is_empty() and disk.error.is_empty():
  check(disk.validation_reused and disk.terrain.size() == document.placements.size(), "Disk bake reuses verified collision data for every terrain piece")
  for index in source.terrain.size():
   check(collision_records(source.terrain[index].body) == collision_records(disk.terrain[index].body), "Disk collision polygons/segments equal source decomposition %d" % index)
  for index in source.objects.size():
   var original: Dictionary = source.objects[index]
   var compiled: Dictionary = disk.objects[index]
   check(original.object_id == compiled.object_id and original.position == compiled.position and original.rotation_degrees == compiled.rotation_degrees and Objects.properties(original) == Objects.properties(compiled), "Disk compiler retains identity and exact dimensions: " + original.type)
 if source.root != null: source.root.free()
 if disk.root != null: disk.root.free()
 ball.free()
 controls.free()
 tuning.free()

func check_presentation(game: Node, document: Resource) -> void:
 var runtime: Dictionary = game.active.runtime
 var offset: Vector2 = game.active.plan.offset
 check(runtime.terrain.size() == document.placements.size() and runtime.objects.size() == document.gameplay_objects.size(), "Prototype has all authoritative terrain and hardware")
 for index in runtime.terrain.size():
  check(not collision_records(runtime.terrain[index].body).is_empty(), "Live terrain has baked 2D collision %d" % index)
 for index in runtime.objects.size():
  var original: Dictionary = document.gameplay_objects[index]
  var live: Dictionary = runtime.objects[index]
  check(live.object_id == original.object_id and live.type == original.type and live.position.distance_to(original.position + offset) < 0.001 and Objects.properties(live) == Objects.properties(original), "Live identity, position and properties agree: " + original.type)
 check(runtime.mechanics.banks.size() == document.switch_banks.size(), "Prototype retains all Switch Banks")
 for index in document.switch_banks.size():
  var bank: Dictionary = runtime.mechanics.banks[index]
  var expected: Dictionary = document.switch_banks[index]
  check(bank.members == expected.members and bank.gates == expected.gates and bank.get("actions", []) == expected.get("actions", []), "Live bank membership and internal routing agree %d" % index)
 check(game.active.visual.find_children("*", "CollisionObject3D", true, false).is_empty(), "3D presentation has no collision authority")
 var decor_by_id := {}
 for visual: Node in game.active.visual.find_children("*", "Node3D", true, false):
  if visual.has_meta("decor_slot_id"): decor_by_id[visual.get_meta("decor_slot_id")] = visual
 check(decor_by_id.size() == document.decor_slots.size(), "Every authored Decor slot survives the disk visual recipe, including hidden authoring slots")
 for slot: Dictionary in document.decor_slots:
  if not decor_by_id.has(slot.slot_id): continue
  var visual: Node3D = decor_by_id[slot.slot_id]
  var mapped := TablePresentation.map_point(slot.position + offset)
  var scale: float = float(document.cell_size) * TablePresentation.SCALE * float(slot.get("scale", 1.0))
  var expected_basis := Basis(Vector3.UP, -deg_to_rad(float(slot.rotation_degrees)))
  expected_basis.x *= -scale if slot.get("mirror_x", false) else scale
  expected_basis.y *= scale
  expected_basis.z *= scale
  check(Vector2(visual.global_position.x, visual.global_position.z).distance_to(Vector2(mapped.x, mapped.z)) < 0.0001 and visual.global_basis.is_equal_approx(expected_basis), "Decor presentation preserves authored position, angle, scale and reflection: " + slot.slot_id)
 for index in runtime.flippers.size():
  var body: Node2D = runtime.flippers[index]
  var visual: Node3D = game.presentation.flipper_visuals[index]
  var mapped: Vector3 = TablePresentation.map_point(body.global_position)
  check(Vector2(visual.global_position.x, visual.global_position.z).distance_to(Vector2(mapped.x, mapped.z)) < 0.0001 and absf(wrapf(visual.rotation.y + body.rotation, -PI, PI)) < 0.0001, "Flipper presentation follows physical pivot and handed rotation %d" % index)
 for body_id: int in game.presentation.bumper_visuals:
  var body: Node2D = instance_from_id(body_id)
  var visual: Node3D = game.presentation.bumper_visuals[body_id]
  var mapped := TablePresentation.map_point(body.global_position)
  # Moving bumpers use a translated child under an authored-angle parent.
  # Compare world orientation, independently of how each model nests its nodes.
  var visual_axis := Vector2(visual.global_basis.x.x, visual.global_basis.x.z).normalized()
  check(Vector2(visual.global_position.x, visual.global_position.z).distance_to(Vector2(mapped.x, mapped.z)) < 0.0001 and visual_axis.distance_to(Vector2.from_angle(body.global_rotation)) < 0.0001, "Bumper presentation follows authoritative transformed collision")
 for node: Node in game.active.nodes:
  if node.get_script() != MechanicsVisual: continue
  for entry: Dictionary in node.gimmicks:
   if not entry.has("root"): continue
   var visual: Node3D = entry.root
   var mapped := TablePresentation.map_point(entry.item.position)
   check(Vector2(visual.global_position.x, visual.global_position.z).distance_to(Vector2(mapped.x, mapped.z)) < 0.0001 and absf(wrapf(visual.rotation.y + deg_to_rad(float(entry.item.rotation_degrees)), -PI, PI)) < 0.0001, "Mechanism presentation follows authored transform: " + entry.item.type)
  for entry: Dictionary in node.enemies:
   check(entry.item.object_id in runtime.mechanics.enemies.by_id and absf(wrapf(entry.pose.rotation.z + deg_to_rad(float(entry.item.rotation_degrees)), -PI, PI)) < 0.0001, "Buzz presentation and rotated sensor share runtime identity and angle")
 check(is_instance_valid(runtime.goal_ring) and runtime.goal_ring.is_visible_in_tree(), "Current Prototype Goal is visible")
 check(game.controls is PlaygroundInput and InputMap.has_action("left_flipper") and InputMap.has_action("right_flipper") and InputMap.has_action("steer_left") and InputMap.has_action("launch"), "Current Prototype controls are installed")

func run() -> void:
 var theme := "green_hill"
 var name := "dense"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--theme="): theme = argument.trim_prefix("--theme=")
  if argument.begins_with("--fixture="): name = argument.trim_prefix("--fixture=")
 if theme not in Registry.IDS or name not in ["dense", "linked", "linked_vertical", "smoothed"]:
  push_error("Choose a known theme and qualification fixture.")
  quit(1)
  return
 var path := Fixture.DIRECTORY.path_join(name + ".tres")
 var loaded := Act.load_document(path)
 check(loaded.document != null, "Saved fixture opens: " + loaded.error)
 if loaded.document == null:
  quit(1)
  return
 var document: Resource = loaded.document
 var source_hash := FileAccess.get_sha256(path)
 var pipeline := Bake.pipeline_hash(theme)
 var saved: Resource = ResourceLoader.load(Bake.path_for(path, theme), "", ResourceLoader.CACHE_MODE_IGNORE)
 check(saved is Bake and saved.matches(document, theme, pipeline) and saved.has_validated_collisions(document), "Normal-path disk bake is current and physics-validated")
 if not saved is Bake:
  quit(1)
  return
 check_compiler(document, saved, pipeline)
 var metadata: Resource = document.copy_document()
 metadata.editor_groups = []
 metadata.editor_locks = {}
 metadata.editor_hidden = {}
 check(saved.matches_geometry(metadata, theme, pipeline), "Editor groups, locks and hiding do not stale collision/gameplay bake")
 metadata.spawn_position += Vector2(0.125, 0)
 check(not saved.matches_geometry(metadata, theme, pipeline), "A genuine geometry edit stales the same bake")
 var session := Session.new()
 session.settings_path = "user://qualification-prototype.cfg"
 session.archive_directory = "user://qualification-telemetry"
 session.configure_act_test(path)
 session.run_configuration.selected_theme_ids = [theme]
 session.run_configuration.single_act_use_bakes = true
 session.sound_enabled = false
 root.add_child(session)
 await session.start_run()
 var deadline := Time.get_ticks_msec() + 180000
 while is_instance_valid(session.game) and not session.game.started and session.game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline:
  await process_frame
 var game: Node = session.game
 check(is_instance_valid(game) and game.started, "Actual Prototype starts the edited fixture")
 var receipt := {"fixture": name, "theme": theme, "source_sha256": source_hash, "pipeline": pipeline}
 if is_instance_valid(game) and game.started:
  game.auto_launch_time = -1.0
  game.ball.freeze = true
  game.set_physics_process(false)
  game.ring_field.set_physics_process(false)
  check(game.library.fallback_builds == 0 and game.library.visual_bake_hits == 1 and game.library.theme_bake_hits == 1, "Exactly one Act/theme disk load and zero fallback rebuilds")
  check(game.active.document.editing_fingerprint() == document.editing_fingerprint(), "Prototype loads the saved edited document exactly")
  check_presentation(game, document)
  game.controls.virtual_enabled = true
  game.controls.virtual_left = true
  game.controls.virtual_right = true
  game.controls.virtual_steering = 0.5
  for frame in 4: await physics_frame
  check(game.controls.left_held and game.controls.right_held and game.controls.steering == 0.5, "Live input adapter accepts flippers and steering")
  game.controls.virtual_left = false
  game.controls.virtual_right = false
  game.controls.virtual_steering = 0
  game.ball.serve_pending = false
  game.active.runtime.mechanics.scoring_active = true
  var old_score: int = game.score
  game.active.runtime.mechanics.mechanic_score.emit(&"switch", "qualification_scoring", 100)
  check(game.score > old_score, "Current Prototype scoring receives the mechanic event")
  receipt.merge({"fallback_builds": game.library.fallback_builds, "disk_acts": game.library.visual_bake_hits, "disk_themes": game.library.theme_bake_hits,
   "terrain": game.active.runtime.terrain.size(), "objects": game.active.runtime.objects.size(), "visual_nodes": game.active.nodes.size()})
 var owner: WeakRef = weakref(session)
 await session._close_run("qualification_finished")
 session.free()
 paused = false
 for frame in 3: await process_frame
 check(owner.get_ref() == null, "Prototype session closes cleanly")
 check(FileAccess.get_sha256(path) == source_hash, "Bake/Prototype checks never rewrite the fixture")
 receipt.merge({"checks": checks, "failures": failures, "failed": failed})
 var output := FileAccess.open("user://qualification-authority-%s-%s.json" % [name, theme], FileAccess.WRITE)
 output.store_string(JSON.stringify(receipt, "  "))
 output.close()
 print("EDITOR AUTHORITY | %s | %s | %d checks | %d failures" % [name, theme, checks, failures])
 quit(failures)
