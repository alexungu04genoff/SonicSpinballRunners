extends SceneTree
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
 print("PASS | " if ok else "FAIL | ", label)
 if not ok: failures += 1
func _initialize() -> void:
 run.call_deferred()
func frames(count: int) -> void:
 for i in count: await physics_frame
func run() -> void:
 var act := Document.new()
 act.spawn_position = Vector2(300, 500)
 var sling := Objects.make_placement("slingshot")
 sling.position = Vector2(300, 300)
 var bank := Objects.bank_from_span(Objects.make_placement("drop_target_bank"), Vector2(150, 150), Vector2(278, 150))
 bank.properties.reset_delay = 0.5
 act.gameplay_objects = [sling, bank]
 check(act.save_document("user://pinball-vocabulary-test.tres") == OK, "Slingshot placement saves")
 var loaded := Document.load_document("user://pinball-vocabulary-test.tres")
 check(loaded.document != null and loaded.document.fingerprint() == act.fingerprint(), "Slingshot reload is exact")
 var tuning := PhysicsTuning.new()
 var controls := PlaygroundInput.new()
 controls.virtual_enabled = true
 var ball := PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 root.add_child(tuning)
 root.add_child(controls)
 root.add_child(ball)
 var runtime := Compiler.compile(act, tuning, controls, ball)
 check(runtime.error.is_empty(), "Runtime compiles")
 root.add_child(runtime.root)
 var item: Dictionary = runtime.mechanics.items[0]
 ball.teleport_to(Vector2(300, 270), Vector2(0, 400))
 await frames(10)
 check(item.launch_count == 1 and ball.linear_velocity.y < -400, "Physical front contact launches once")
 ball.teleport_to(Vector2(300, 330), Vector2(0, -400))
 await frames(10)
 check(item.launch_count == 1 and ball.linear_velocity.y > 0, "Back rebounds without activation")
 item.rotation_degrees = 90.0
 ball.teleport_to(Vector2(330, 300), Vector2(-400, 0))
 await frames(10)
 check(item.launch_count == 2 and ball.linear_velocity.x > 600, "Rotation changes physical launch direction")
 ball.teleport_to(Vector2(300, 345), Vector2(0, -400))
 await frames(10)
 check(item.launch_count == 2, "End contact does not power launch")
 var bank_item: Dictionary = runtime.mechanics.items[1]
 ball.teleport_to(Vector2(150, 120), Vector2(0, 400))
 await frames(10)
 check(bank_item.targets[0].down and not bank_item.targets[1].down, "Physical contact drops only the struck target")
 var first_id: String = bank_item.targets[0].object_id
 ball.teleport_to(Vector2(150, 120), Vector2(0, 400))
 await frames(16)
 check(ball.position.y > 160, "Dropped target has no collision")
 ball.teleport_to(Vector2(500, 500))
 await frames(2)
 var completions: Array = []
 runtime.mechanics.feature_completed.connect(func(kind, id, bonus): completions.append([kind, id, bonus]))
 for target: Dictionary in bank_item.targets: runtime.mechanics.drop_target(bank_item, target)
 check(bank_item.complete and completions.size() == 1 and completions[0][2] == 500, "All targets complete bank exactly once")
 runtime.mechanics.reset_for_retry()
 check(bank_item.complete, "Retry preserves dropped targets and bank state")
 runtime.mechanics.tick(0.6)
 check(not bank_item.complete and not bank_item.targets[0].down and bank_item.targets[0].object_id == first_id, "Timed reset restores independent collision state and stable identity")
 bank_item.properties.reset_delay = 0.0
 for target: Dictionary in bank_item.targets: runtime.mechanics.drop_target(bank_item, target)
 runtime.mechanics.tick(10.0)
 check(bank_item.complete, "Zero reset delay keeps bank down")
 runtime.root.free()
 ball.free()
 controls.free()
 tuning.free()
 quit(1 if failures else 0)
