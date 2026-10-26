extends SceneTree
## Uses the production Green Hill application, not the standalone diagnostic loop.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const Act = preload("res://scripts/act_editor/act_geometry.gd")
const Slots = preload("res://scripts/act_editor/decor_slots.gd")
const DecorSkin = preload("res://scripts/decor/decor_skin.gd")
const GreenHill = preload("res://scripts/decor/green_hill_decor.gd")
const EXAMPLES := ["decor_terraces", "decor_garden_steps", "decor_loop_court"]
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 checks += 1
 if ok: print("PASS | ", message)
 else:
  failures += 1
  push_error("FAIL | " + message)

func frames(count := 4) -> void:
 for i in count:
  await process_frame
  await physics_frame

func rebuild(path: String) -> void:
 game.request_authored_act(path)
 await frames(8)

func variants() -> Array:
 var result: Array = []
 for prop: Node in game.presentation.decor_root.get_children():
  result.append([prop.get_meta("decor_slot_id"), prop.get_meta("decor_variant")])
 return result

func only_visual_nodes(node: Node) -> bool:
 if not node is Node3D or node is CollisionObject3D or node is CollisionShape3D: return false
 for child in node.get_children():
  if not only_visual_nodes(child): return false
 return true

func geometry_signature() -> Array:
 var result: Array = []
 for item: Dictionary in game.playfield.authored_runtime.terrain:
  result.append([item.points, item.closed])
 for item: Dictionary in game.playfield.authored_runtime.objects:
  result.append([item.type, item.position, item.rotation_degrees])
 return result

func test_industrial_prop(_variant: String) -> Node3D:
 var prop := MeshInstance3D.new()
 prop.mesh = CylinderMesh.new()
 return prop

func capture(name: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await frames(3)
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://test-results/%s.png" % name) == OK, "Rendered capture: " + name)

func run() -> void:
 root.size = Vector2i(1440, 1000)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 game = Game.new()
 game.authored_act_path = "res://data/acts/decor_terraces.tres"
 root.add_child(game)
 await frames(8)
 # Capture the unfiltered current Green Hill look without changing saved defaults.
 if game.get("retro_filter") != null: game.retro_filter.set_preset(0)
 for file: String in EXAMPLES:
  var path := "res://data/acts/%s.tres" % file
  var source := FileAccess.get_file_as_bytes(path)
  await rebuild(path)
  var act: Resource = game.authored_document
  check(game.playfield.source == "authored" and game.presentation.decor_root.get_child_count() == act.decor_slots.size(), "All manual slots spawn in main gameplay: " + file)
  check(game.presentation.skipped_decor_slots.is_empty() and only_visual_nodes(game.presentation.decor_root), "Decor is supported and entirely collisionless: " + file)
  var transforms_match := true
  for i in act.decor_slots.size():
   var slot: Dictionary = act.decor_slots[i]
   var prop: Node3D = game.presentation.decor_root.get_child(i)
   transforms_match = transforms_match and prop.position.is_equal_approx(TablePresentation.map_point(slot.position, TablePresentation.RAIL_HEIGHT + TablePresentation.RAIL_CAP_HEIGHT))
   transforms_match = transforms_match and is_equal_approx(prop.rotation.y, -deg_to_rad(slot.rotation_degrees))
   transforms_match = transforms_match and is_equal_approx(prop.scale.x, act.cell_size * TablePresentation.SCALE * slot.scale)
  check(transforms_match, "Props mount at exact positions, free angles and safe scales: " + file)
  var resolved := variants()
  var bodies: Array = geometry_signature()
  await rebuild(path)
  check(resolved == variants() and bodies == geometry_signature() and source == FileAccess.get_file_as_bytes(path), "Reload retains variants, collision data and source file: " + file)
  game.presentation.set_camera_follow(false)
  await capture(file)
 var path := "res://data/acts/decor_terraces.tres"
 await rebuild(path)
 var before: String = game.authored_document.fingerprint()
 var physics_before := geometry_signature()
 var all_pools: Dictionary = {}
 for type: String in Slots.TYPES:
  all_pools[type] = {"surface": ["test_pipe"], "edge": ["test_pipe"], "either": ["test_pipe"]}
 game.presentation.decor_skin = DecorSkin.new("industrial_test", all_pools, test_industrial_prop)
 await rebuild(path)
 var switched := true
 for prop: Node in game.presentation.decor_root.get_children():
  switched = switched and prop.get_meta("decor_variant") == "test_pipe" and prop.get_meta("decor_skin_id") == "industrial_test"
 check(switched and game.authored_document.fingerprint() == before and geometry_signature() == physics_before, "Actual runtime switches skin without changing Act or physics")
 game.presentation.decor_skin = GreenHill.new(game.presentation)
 var unsupported: Resource = game.authored_document.copy_document()
 var slot := Slots.make_slot("large")
 slot.position = Vector2(300, 500)
 unsupported.decor_slots.append(slot)
 var draft := "res://test-results/decor-unsupported.tres"
 check(unsupported.save_document(draft) == OK, "Off-terrain slot remains a saveable authoring draft")
 await rebuild(draft)
 check(game.presentation.skipped_decor_slots == PackedStringArray([slot.slot_id]) and game.presentation.decor_root.get_child_count() == unsupported.decor_slots.size() - 1, "Unsupported anchor skips only that visual without moving it")
 var bare: Resource = game.authored_document.copy_document()
 bare.decor_slots.clear()
 var bare_path := "res://test-results/decor-bare.tres"
 check(bare.save_document(bare_path) == OK, "Undecorated control Act saves")
 await rebuild(bare_path)
 check(game.presentation.decor_root.get_child_count() == 0 and geometry_signature() == physics_before, "Removing decor leaves all authored gameplay collision unchanged")
 await rebuild(path)
 game.presentation.set_camera_follow(false)
 await capture("decor_terraces_final")
 game.free()
 await frames(2)
 print("RESULT | Decor runtime | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
