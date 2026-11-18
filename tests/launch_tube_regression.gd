extends SceneTree
## Deterministic authoring and real 120 Hz body checks; no desktop input automation.
const Act = preload("res://scripts/act_editor/act_geometry.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Tube = preload("res://scripts/authored_act/launch_tube.gd")
const Transform = preload("res://scripts/act_editor/selection_transform.gd")
const Clipboard = preload("res://scripts/act_editor/selection_clipboard.gd")
const Assemblies = preload("res://scripts/act_editor/assembly_library.gd")
const WORKSHOP := "res://data/acts/Experiments/Launch Tube Workshop.tres"
var checks := 0
var failures := 0
var releases: Array[Vector2] = []
var ball: PlaygroundBall
var tube: Node2D
var controls: PlaygroundInput
var world: Node2D

func _initialize() -> void:
 run.call_deferred()

func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)

func frames(count: int) -> void:
 for index in count:
  await physics_frame
  await process_frame

func until(condition: Callable, count := 900) -> bool:
 for index in count:
  await frames(1)
  if condition.call(): return true
 return false

func points(item: Dictionary) -> PackedVector2Array:
 var result: PackedVector2Array = Objects.properties(item).points.duplicate()
 for index in result.size(): result[index] = Vector2(item.position) + result[index].rotated(deg_to_rad(float(item.rotation_degrees)))
 return result

func authoring() -> void:
 var loaded := Act.load_document(WORKSHOP)
 check(loaded.document != null, "Experimental Act loads: " + loaded.error)
 if loaded.document == null: return
 var document: Resource = loaded.document
 check(document.validation_errors().is_empty(), "Workshop is a valid authored Act")
 check(WORKSHOP not in preload("res://scripts/prototype/run_plan.gd").source_paths() and WORKSHOP not in preload("res://scripts/endless/endless_plan.gd").PATHS, "Workshop remains outside both production pools")
 var item: Dictionary = document.gameplay_objects[0]
 check(Objects.property_errors(item).is_empty(), "Default tube properties validate")
 for field: String in ["charge_seconds", "min_speed", "max_speed", "resistance", "return_speed", "feedback_strength"]:
  var invalid := item.duplicate(true)
  invalid.properties[field] = NAN
  check(not Objects.property_errors(invalid).is_empty(), "Non-finite tube property rejected: " + field)
 var invalid := item.duplicate(true)
 invalid.properties.max_speed = 50.0
 check(not Objects.property_errors(invalid).is_empty(), "Full launch must be faster than minimum")
 invalid = item.duplicate(true)
 invalid.properties.presentation = "unknown"
 check(not Objects.property_errors(invalid).is_empty(), "Unknown presentation is rejected")
 var terrain: Array = document.placements.duplicate(true)
 var before := points(item)
 for horizontal: bool in [true, false]:
  var mirrored: Resource = document.copy_document()
  Transform.mirror(mirrored, {"gameplay": [0]}, Vector2(300, 300), horizontal)
  var after := points(mirrored.gameplay_objects[0])
  for index in before.size():
   check(after[index].is_equal_approx(Vector2(600 - before[index].x, before[index].y) if horizontal else Vector2(before[index].x, 600 - before[index].y)), "Mirrored path and exit agree with the whole-object transform")
  check(mirrored.placements == terrain, "Mirroring the tube does not modify terrain")
 var copied := Clipboard.capture(document, {"gameplay": [0]})
 var pasted: Resource = document.copy_document()
 var appended := Clipboard.append_to(pasted, copied, Vector2(25, 12))
 check(appended.error.is_empty(), "Tube copy/paste accepts a second authored route")
 var clone: Dictionary = pasted.gameplay_objects.back()
 check(clone.object_id != item.object_id and clone.position == item.position + Vector2(25, 12), "Paste receives a fresh identity and exact offset")
 clone.properties.points[1] += Vector2(11, 7)
 check(points(item) == before, "Copied path edits do not alias the source")
 var assembly := Assemblies.save_selection(document, {"gameplay": [0]}, "Launch Tube regression")
 check(assembly.error.is_empty(), "Tube saves as a reusable assembly")
 if assembly.error.is_empty():
  var reopened := Assemblies.load_copy(assembly.path, document.cell_size)
  check(reopened.error.is_empty() and reopened.copied.gameplay[0].properties.points == item.properties.points, "Assembly reload retains exact route points")
 var saved := "res://test-results/launch-tube/roundtrip.tres"
 check(document.save_document(saved) == OK, "Tube Act saves")
 var reopened := Act.load_document(saved)
 check(reopened.document != null and reopened.document.fingerprint() == document.fingerprint(), "Save/reopen preserves all tube data and fingerprint")
 var editor := preload("res://scenes/act_geometry_editor.tscn").instantiate()
 root.add_child(editor)
 await process_frame
 editor.new_document()
 editor.document = document.copy_document()
 editor.canvas.set_document(editor.document)
 editor.canvas.snap_mode = 0
 editor.canvas.fit_view()
 editor._refresh()
 editor.workspace_tools.autosave_enabled.button_pressed = false
 editor.undo_stack.clear()
 editor.redo_stack.clear()
 editor.canvas.select_gameplay(0)
 editor.canvas.rail_edit = true
 var start: Vector2 = before[1]
 var finish := start + Vector2(15.25, -14.75)
 var down := InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT
 down.pressed = true
 down.alt_pressed = true
 down.position = editor.canvas.local_pixels_to_screen(start)
 editor.canvas._rail_input(down)
 var motion := InputEventMouseMotion.new()
 motion.position = editor.canvas.local_pixels_to_screen(finish)
 motion.alt_pressed = true
 motion.button_mask = MOUSE_BUTTON_MASK_LEFT
 editor.canvas._rail_input(motion)
 down.pressed = false
 down.position = motion.position
 editor.canvas._rail_input(down)
 check(points(editor.document.gameplay_objects[0])[1].is_equal_approx(finish), "Editor path handle moves to the exact free coordinate")
 check(editor.undo_stack.size() == 1, "One point drag creates one undo step")
 editor.undo()
 check(points(editor.document.gameplay_objects[0]) == before, "Undo restores the entire path")
 editor.redo()
 check(points(editor.document.gameplay_objects[0])[1].is_equal_approx(finish), "Redo restores the path edit")
 check(editor.document.placements == terrain, "Path gestures never cut or modify terrain")
 editor.free()

func obstacle(at: Vector2, size: Vector2) -> StaticBody2D:
 var body := StaticBody2D.new()
 body.position = at
 body.collision_layer = 1
 body.collision_mask = 2
 var collider := CollisionShape2D.new()
 var shape := RectangleShape2D.new()
 shape.size = size
 collider.shape = shape
 body.add_child(collider)
 world.add_child(body)
 return body

func fire(fraction: float) -> void:
 controls.virtual_launch = false
 tube.dock(ball)
 tube.advance(0.0, false)
 tube.advance(float(tube.properties.charge_seconds) * fraction, true)
 tube.advance(0.0, false)

func physics_checks() -> void:
 world = Node2D.new()
 root.add_child(world)
 var tuning := PhysicsTuning.new()
 root.add_child(tuning)
 controls = PlaygroundInput.new()
 controls.virtual_enabled = true
 controls.virtual_steering = 1.0
 root.add_child(controls)
 ball = PlaygroundBall.new()
 ball.radius = 7.0
 ball.tuning = tuning
 ball.controls = controls
 world.add_child(ball)
 tube = Tube.new()
 tube.position = Vector2(100, 500)
 var properties := Objects.defaults("launch_tube")
 properties.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -300)])
 tube.configure(properties)
 world.add_child(tube)
 tube.exited.connect(func(_point: Vector2, velocity: Vector2): releases.append(velocity))
 var terrain := obstacle(Vector2(100, 350), Vector2(100, 50))
 var terrain_transform := terrain.transform
 var neighbor := Tube.new()
 neighbor.configure(properties)
 neighbor.position = Vector2(100, 350)
 world.add_child(neighbor)
 tube.dock(ball)
 await frames(3)
 check(ball.serve_pending and ball.collision_layer == 0 and ball.collision_mask == 0, "Containment disables gameplay collision and serving/scoring gates")
 check(ball.steering_contribution == 0.0 and ball.steering_impulse_applied == 0.0, "Held steering cannot affect a contained ball")
 check(ball.position.is_equal_approx(tube.dock_position()), "The real body stays at the dock")
 fire(0.15)
 check(await until(func(): return tube.phase == Tube.Phase.RETURNING), "Weak shot reverses on the authored route")
 check(tube.distance > 20.0 and ball.launch_tube == tube and not neighbor.contained, "Weak shot travels meaningfully without neighboring capture")
 check(await until(func(): return tube.phase == Tube.Phase.DOCKED), "Weak shot safely re-docks")
 check(releases.is_empty() and ball.position.distance_to(tube.dock_position()) < 0.1, "Rollback emits no successful exit and returns the same real ball")
 fire(0.5)
 check(await until(func(): return not tube.contained), "Medium charge exits through solid terrain without changing it")
 check(releases.size() == 1, "Medium charge emits exactly one release")
 var medium: float = releases.back().length() if not releases.is_empty() else 0.0
 check(ball.collision_layer == 2 and ball.collision_mask == 1 and not ball.serve_pending, "Exit restores ordinary body collision and free flight")
 await frames(8)
 check(ball.steering_contribution > 0.0, "Ordinary steering works after exit")
 fire(1.0)
 check(await until(func(): return not tube.contained), "Full charge exits")
 check(releases.size() == 2 and releases.back().length() > medium * 1.5, "Charge materially changes measured exit velocity")
 check(terrain.transform == terrain_transform and terrain.get_child_count() == 1, "Traversal preserves terrain transform and collision shape")
 check(not neighbor.contained and ball.launch_tube == null, "A streamed neighboring tube cannot capture ordinary flight")
 var blocker := obstacle(Vector2(100, 200), Vector2(30, 30))
 await frames(2)
 fire(1.0)
 check(await until(func(): return tube.phase == Tube.Phase.RETURNING), "A blocked exit reverses instead of restoring collision inside terrain")
 check(await until(func(): return tube.phase == Tube.Phase.DOCKED), "Blocked exit returns safely to dock")
 check(releases.size() == 2, "Blocked exit never reports a successful launch")
 blocker.free()
 controls.virtual_launch = true
 tube.dock(ball)
 var identity := ball.get_instance_id()
 await frames(30)
 check(tube.phase == Tube.Phase.DOCKED and tube.charge == 0.0 and tube.require_release, "Launch held through re-docking never begins a charge")
 controls.virtual_launch = false
 await frames(3)
 check(tube.phase == Tube.Phase.DOCKED and not tube.require_release, "Releasing the stale hold only arms a fresh press")
 controls.virtual_launch = true
 await frames(12)
 check(tube.phase == Tube.Phase.CHARGING and tube.charge > 0.0 and ball.get_instance_id() == identity, "Fresh player hold charges the same real ball")
 var adapter := preload("res://scripts/game.gd").new()
 adapter.authored_document = Act.new()
 adapter.authored_document.spawn_position = Vector2(100, 500)
 adapter.authored_runtime = {"root": world, "launch_tubes": [tube]}
 check(adapter._active_launch_tube() == tube, "Active runtime alone owns the dock despite resident neighbors")
 adapter.authored_runtime = {"root": world, "launch_tubes": []}
 check(adapter._active_launch_tube() == null, "Ordinary active Act does not borrow a neighbor's tube")
 adapter.free()
 tube.detach()
 check(ball.collision_layer == 2 and ball.collision_mask == 1 and ball.launch_tube == null, "Source replacement/teardown restores body properties")
 world.free()
 controls.free()
 tuning.free()

func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://test-results/launch-tube")
 await authoring()
 await physics_checks()
 print("RESULT | Launch Tube | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
