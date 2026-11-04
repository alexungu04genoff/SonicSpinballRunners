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
 act.gameplay_objects = [sling]
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
 runtime.root.free()
 ball.free()
 controls.free()
 tuning.free()
 quit(1 if failures else 0)
