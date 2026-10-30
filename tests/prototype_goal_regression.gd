extends SceneTree
const Editor = preload("res://scripts/act_editor/act_geometry_editor.gd")
const Goal = preload("res://scripts/prototype/goal_ring.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)
func run() -> void:
 var editor := Editor.new()
 root.add_child(editor)
 check(editor.load_from("res://data/acts/Authored/Second Simple.tres"), "Legacy authored Act loads in editor")
 check(editor.document.format_version == 16 and editor.document.goal_center() == editor.document.spawn_position and editor.document.goal_diameter_cells == 1.0, "Every legacy Act gets a cell-sized goal at its spawn")
 var at: Vector2 = editor.document.spawn_position + Vector2(20, -30)
 editor.set_lifecycle_marker("goal", at)
 editor.goal_size_field.value = 1.35
 check(editor.document.goal_center() == at and is_equal_approx(editor.document.goal_diameter_cells, 1.35), "Editor moves and resizes the mandatory goal")
 editor.undo()
 check(editor.document.goal_diameter_cells == 1.0, "Goal resize is undoable")
 editor.redo()
 var path := "user://goal-roundtrip.tres"
 check(editor.document.save_document(path) == OK, "Goal settings save successfully")
 var loaded := ActGeometry.load_document(path)
 check(loaded.document != null and loaded.document.fingerprint() == editor.document.fingerprint(), "Goal position and size round-trip exactly")
 editor.set_lifecycle_marker("goal", null)
 check(editor.document.goal_center() == editor.document.spawn_position, "Deleting the goal restores its default instead of removing it")
 var goal := Goal.new()
 root.add_child(goal)
 goal.configure(editor.document, Vector2(200, -600))
 var start: Vector2 = goal.center - Vector2(500, 0)
 var finish: Vector2 = goal.center + Vector2(500, 0)
 check(not goal.crossed(start, finish, 7.5), "Locked gray goal rejects fast crossings")
 var gray := goal.material.albedo_color
 goal.set_unlocked(true)
 check(goal.material.albedo_color != gray and goal.crossed(start, finish, 7.5), "Unlocked colored goal detects a swept crossing without tunneling")
 check(not goal.crossed(start + Vector2(0, 200), finish + Vector2(0, 200), 7.5), "Passing outside the goal does not advance")
 var score := Scorecraft.new()
 score.config = ScorecraftConfig.new()
 score.config.multiplier_cap = 4
 score.config.tiered_decay = true
 root.add_child(score)
 score.set_physics_process(false)
 var bodies: Array[Node] = []
 for i in 3:
  var body := Node.new()
  root.add_child(body)
  bodies.append(body)
 score.award_bumper(bodies[0])
 for i in 3: score.award_ring()
 score.award_bumper(bodies[1])
 score.award_bumper(bodies[2])
 check(score.multiplier == 4, "A ring link plus distinct hits earns x4")
 for tier in [3, 2, 1]:
  score._physics_process(score.config.combo_window)
  check(score.multiplier == tier, "Combo timer drains to x%d" % tier)
 check(score.remaining == 0.0 and score.chain == 0, "Expired combo returns to the permanent white base")
 for body in bodies: body.free()
 score.free()
 goal.free()
 editor.free()
 print("RESULT | Goal and meter | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
