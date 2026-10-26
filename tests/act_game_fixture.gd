extends SceneTree
## Small shared helpers for authored gameplay regression fixtures.
var checks := 0
var failures := 0
var game: Node

func create_game() -> Node:
 # Keep controlled character/score fixtures at a 14 px ball radius, with real
 # authored rings. The default player Act is intentionally not a test fixture.
 var source = preload("res://scripts/act_editor/act_geometry.gd").load_document("res://data/acts/scale_comparison.tres")
 var document: Resource = source.document.copy_document()
 document.cell_size = 100.0
 var path := "res://test-results/session-physics-act.tres"
 check(document.save_document(path) == OK, "Save authored session fixture")
 var player: Node = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 player.authored_act_path = path
 return player

func _initialize() -> void:
 call_deferred("run")

func frames(count: int = 4) -> void:
 for i in count:
  await physics_frame
  await process_frame

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless":
  return
 await create_timer(0.25).timeout
 await RenderingServer.frame_post_draw
 var directory := "res://test-results"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 var prefix := "authored-game-"
 var result := root.get_texture().get_image().save_png(directory.path_join(prefix + label + ".png"))
 if result != OK:
  failures += 1
  push_error("Capture failed: " + error_string(result))
