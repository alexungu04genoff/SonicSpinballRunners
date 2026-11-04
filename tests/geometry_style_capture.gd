extends "res://tests/authored_main_game_regression.gd"
## Repeatable review evidence: identical authored Act, camera and theme defaults.
const Themes = preload("res://scripts/themes/theme_registry.gd")
const OUTPUT := "res://test-results/geometry-style"

func run() -> void:
 root.size = Vector2i(1280, 900)
 root.content_scale_size = root.size
 var label := "after"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 game = ObservedGame.new()
 game.authored_act_path = "res://data/acts/Experiments/Lockbox.tres"
 root.add_child(game)
 await frames(6)
 paused = true
 var source: String = game.playfield.document.fingerprint()
 var counts := {}
 for theme: String in Themes.IDS:
  check(game.set_theme(theme), theme + " instantiates")
  var p: TablePresentation = game.presentation
  p.set_process(false)
  p.camera_follow_enabled = true
  p.reset_camera(Vector2(300, 400))
  for layer: Node in game.find_children("*", "CanvasLayer", true, false): layer.visible = false
  if "--baked" in OS.get_cmdline_user_args():
   await baked_view(p, theme)
  if DisplayServer.get_name() == "headless":
   var catalogue := Node3D.new()
   var seen := {}
   for size: String in ["small", "medium", "large", "landmark"]:
    for hint: String in ["surface", "edge", "either"]:
     for variant: String in p.decor_skin.variants_for({"slot_type": size, "placement_hint": hint}):
      if seen.has(variant): continue
      seen[variant] = true
      catalogue.add_child(p.decor_skin.factory.call(variant))
   counts[theme] = {"catalogue": mesh_counts(catalogue), "act": mesh_counts(p)}
   catalogue.free()
  check(game.playfield.document.fingerprint() == source, theme + " preserves authored data")
  if DisplayServer.get_name() != "headless":
   for frame in 12: await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUTPUT.path_join(label + "-" + theme + ".png"))
   p.camera_follow_enabled = false
   p.reset_camera(Vector2(300, 450))
   for frame in 6: await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUTPUT.path_join(label + "-" + theme + "-overview.png"))
  print("GEOMETRY_STYLE | ", theme, " | ", counts.get(theme, "captured"))
 if not counts.is_empty():
  var file := FileAccess.open(OUTPUT.path_join(label + "-counts.json"), FileAccess.WRITE)
  file.store_string(JSON.stringify(counts, "  "))
 game.free()
 paused = false
 print("GEOMETRY_STYLE | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func mesh_counts(node: Node) -> Dictionary:
 var result := {"vertices": 0, "triangles": 0, "meshes": 0}
 for child: Node in node.find_children("*", "MeshInstance3D", true, false):
  var mesh: Mesh = child.mesh
  if mesh == null or mesh is ImmediateMesh: continue
  result.meshes += 1
  for surface in mesh.get_surface_count():
   var arrays := mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
   result.vertices += vertices.size()
   if not mesh is ArrayMesh or mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
    result.triangles += (vertices.size() if indices.is_empty() else indices.size()) / 3
   var valid := true
   for vertex: Vector3 in vertices: valid = valid and vertex.is_finite()
   if arrays[Mesh.ARRAY_NORMAL] != null:
    for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: valid = valid and normal.is_finite()
   for index: int in indices: valid = valid and index >= 0 and index < vertices.size()
   check(valid and (child.get_active_material(surface) != null or child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY), "Finite mesh, valid indices and material: " + str(child.name))
 return result

func baked_view(p: TablePresentation, theme: String) -> void:
 var Bake = preload("res://scripts/endless/geometry_bake.gd")
 var saved: Resource = ResourceLoader.load(Bake.path_for(game.authored_act_path, theme), "", ResourceLoader.CACHE_MODE_IGNORE)
 check(saved != null and saved.matches(game.playfield.document, theme), theme + " disk bake matches source and pipeline")
 if saved == null: return
 check(saved.collisions.size() == game.authored_runtime.terrain.size(), theme + " preserves collision piece count")
 for i in saved.collisions.size():
  var original: StaticBody2D = game.authored_runtime.terrain[i].body
  var index := 0
  for owner: int in original.get_shape_owners():
   for part in original.shape_owner_get_shape_count(owner):
    var shape: Shape2D = original.shape_owner_get_shape(owner, part)
    var baked: Shape2D = saved.collisions[i][index].shape
    var equal: bool = shape.get_class() == baked.get_class() and original.shape_owner_get_transform(owner) == saved.collisions[i][index].transform
    if shape is ConvexPolygonShape2D: equal = equal and shape.points == baked.points
    elif shape is ConcavePolygonShape2D: equal = equal and shape.segments == baked.segments
    check(equal, theme + " baked collision matches authoritative source")
    index += 1
  check(index == saved.collisions[i].size(), theme + " preserves shape count")
 for child: Node in p.get_children():
  if child is Node3D and child not in [p.camera, p._key_light, p.ball_visual]: child.visible = false
 var stage := Node3D.new()
 stage.name = "ReloadedBake"
 p.add_child(stage)
 var background: Resource = ResourceLoader.load(Bake.theme_path(theme), "", ResourceLoader.CACHE_MODE_IGNORE)
 for recipe: Resource in [saved.visual_recipe, background.visual_recipe]:
  var nodes: Array[Node] = []
  for i in recipe.records.size(): recipe.instantiate_one(i, nodes, stage)
  recipe.bind_animations(nodes, p, game.ball.mechanics)
 check(stage.find_children("*", "CollisionObject3D", true, false).is_empty(), theme + " baked presentation has no 3D collision")
 if DisplayServer.get_name() == "headless":
  print("BAKED_GEOMETRY | ", theme, " | ", mesh_counts(stage))
 await process_frame
