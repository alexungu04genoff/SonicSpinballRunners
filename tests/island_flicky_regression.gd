extends SceneTree
## Checks live pause/lifetime behavior and samples the full decorative animation.
## A graphical run also renders a repeatable 4.8-second preview at 20 fps.
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Presentation = preload("res://scripts/themes/themed_presentation.gd")
const Wildlife = preload("res://scripts/decor/island_flicky.gd")
const Bounds = preload("res://tests/landmark_theme_regression.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func run() -> void:
 var p := Presentation.new()
 # Match the game's always-processing UI ancestor, not the SceneTree default.
 p.process_mode = Node.PROCESS_MODE_ALWAYS
 p.set_theme_definition(Themes.create("green_hill"))
 root.add_child(p)
 var island: Node3D = p.decor_skin.factory.call("palm_island")
 p.add_child(island)
 var birds: Array[Node3D] = []
 for child: Node in island.get_children():
  if child.name.begins_with("Flicky"): birds.append(child)
 check(birds.size() == 3, "Palm island has three Flickies")
 if birds.size() != 3:
  quit(1)
  return
 if "flicky" in Wildlife.available_species():
  var bird := birds[0]
  check(birds.all(func(node): return node.rig and node.player.has_animation(Wildlife.CLIP)), "Palm Island loads three genuine Flicky rigs")
  var initial: float = bird.animation_time
  for i in 3: await process_frame
  check(bird.animation_time > initial, "Local idle advances")
  paused = true
  var held: float = bird.animation_time
  for i in 3: await process_frame
  check(bird.animation_time == held, "Scene pause freezes the original idle")
  paused = false
  for i in 3: await process_frame
  check(bird.animation_time > held, "Animation resumes after pause")
  var wing: Node3D = bird.rig.find_child("Wing", true, false)
  bird.set_animation_time(0.15)
  var pose_a := wing.transform
  bird.set_animation_time(0.75)
  check(not wing.transform.is_equal_approx(pose_a), "Source wing animates while perched")
  bird.set_animation_time(0.15 + bird.player.current_animation_length)
  check(wing.transform.is_equal_approx(pose_a), "The authored clip loops back to the same pose")
  var inspector := Bounds.new()
  for node in birds:
   var boxes: Array[AABB] = []
   check(inspector.collect_bounds(node, boxes) and not boxes.is_empty(), "Island wildlife is finite and collisionless")
  inspector.free()
 else:
  check(birds.all(func(node): return node.rig == null and not node.is_processing()), "Missing art leaves quiet empty perches")
 check_act_visit(p)
 if DisplayServer.get_name() != "headless" and birds[0].rig and failures == 0:
  await capture(p, birds)
 var weak: WeakRef = weakref(birds[0])
 island.queue_free()
 await process_frame
 await process_frame
 check(weak.get_ref() == null, "Removing the island also frees its animated birds")
 p.free()
 print("RESULT | Island Flickies | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func check_act_visit(p: TablePresentation) -> void:
 var visitor = preload("res://scripts/decor/act_flicky.gd").new()
 var document := ActGeometry.new()
 document.grid_size = Vector2i(10, 10)
 document.spawn_position = Vector2(10, 10)
 var cell := float(document.cell_size)
 var offset := Vector2(0, -12) * cell
 var polygon := PackedVector2Array()
 for corner in [Vector2(2, 2), Vector2(8, 2), Vector2(8, 8), Vector2(2, 8)]:
  polygon.append(corner * cell + offset)
 var runtime := {"terrain": [{"closed": true, "points": polygon}], "objects": []}
 var rng := RandomNumberGenerator.new()
 rng.seed = 18
 var perches := {}
 var variants := {}
 var empty := 0
 var chosen := {}
 var placement_state := rng.state
 for i in 32:
  var before := rng.state
  var state: Dictionary = visitor.choose_perch(document, runtime, offset, rng, Wildlife.SPECIES)
  if state.is_empty():
   empty += 1
   continue
  chosen = state
  placement_state = before
  variants[state.species] = true
  perches[state.perch] = true
  check(Geometry2D.is_point_in_polygon(state.perch, polygon), "Visit lands inside the offset Act's raised bank")
 check(perches.size() > 1 and empty > 0, "Fresh visits vary perch and can leave the Act empty")
 check(variants.size() > 1 and variants.keys().all(func(id): return id in Wildlife.SPECIES), "Random visits draw from the Runners roster")
 check(visitor.choose_perch(document, {"terrain": [], "objects": []}, offset, rng, Wildlife.SPECIES).is_empty(), "Empty terrain has no invented perch")
 check(visitor.choose_perch(document, runtime, offset, rng, []).is_empty(), "No installed Runners species leaves a fresh Act empty")
 if chosen.is_empty():
  visitor.free()
  return
 # Reuse a successful set of rolls to distinguish blocked sites from the no-visit roll.
 rng.state = placement_state
 var blocked := runtime.duplicate()
 blocked.floor_outline = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
 check(visitor.choose_perch(document, blocked, offset, rng, Wildlife.SPECIES).is_empty(), "Banks facing off the playable deck are skipped")
 document.decor_slots.assign([{"position": Vector2(5, 5) * cell, "slot_type": "landmark", "scale": 8.0}])
 rng.state = placement_state
 check(visitor.choose_perch(document, runtime, offset, rng, Wildlife.SPECIES).is_empty(), "A landmark occupying the whole bank leaves no perch")
 document.decor_slots.clear()
 var bumper := ActGameplayObjects.make_placement("round_bumper")
 bumper.position = Vector2(5, 5) * cell + offset
 bumper.properties.scale = 30.0
 blocked = runtime.duplicate()
 blocked.objects = [bumper]
 rng.state = placement_state
 check(visitor.choose_perch(document, blocked, offset, rng, Wildlife.SPECIES).is_empty(), "Large hardware excludes its full footprint")
 p.ball = PlaygroundBall.new()
 p.add_child(visitor)
 # Counts from the seven original rigid models after excluding their inverted shells.
 var body_triangles := {"flicky": 180, "picky": 198, "pecky": 132, "pocky": 172, "ricky": 184, "rocky": 116, "cookie": 182}
 for id: String in Wildlife.available_species():
  chosen.species = id
  visitor.enter(p, chosen, cell)
  check(visitor.visible and visitor.rig.name == id and visitor.player.has_animation(Wildlife.CLIP), "Original textured idle loaded for " + id)
  var parts: Array[Node] = visitor.rig.find_children("*", "MeshInstance3D", true, false)
  var triangles := 0
  for part: MeshInstance3D in parts: triangles += part.mesh.get_faces().size() / 3
  check(triangles == body_triangles[id], id + " has exactly its original body triangles after outline removal")
  var material: Material = parts[0].get_active_material(0)
  if id == "flicky":
   check(material is ShaderMaterial and material.get_shader_parameter("body_texture") is Texture2D and material.get_shader_parameter("gold_texture") is Texture2D, "Flicky uses the body atlas and the original masked gold reflection")
  else:
   check(material is BaseMaterial3D and material.albedo_texture != null and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, id + " uses the original unlit body texture")
  var anchor: Transform3D = visitor.transform
  var rig_id: int = visitor.rig.get_instance_id()
  p.ball.position = chosen.perch
  for incoming in [Vector2.RIGHT * 550.0, Vector2.LEFT * 550.0, Vector2.ZERO]:
   p.ball.linear_velocity = incoming
   visitor._process(0.16)
  check(visitor.visible and visitor.transform == anchor and visitor.rig.get_instance_id() == rig_id, "Ball proximity and reversals leave " + id + " perched")
  visitor.enter(p, chosen, cell)
  check(visitor.rig.get_instance_id() == rig_id, "Re-entry reuses the animal")
 chosen.species = "missing"
 visitor.enter(p, chosen, cell)
 check(not visitor.visible and visitor.rig == null, "Unavailable art leaves the visit empty")
 visitor.enter(p, {}, cell)
 check(not visitor.visible and not visitor.is_processing(), "Empty Act retires the last visitor")
 visitor.free()
 p.ball.free()
 p.ball = null

func capture(p: Node3D, birds: Array[Node3D]) -> void:
 root.size = Vector2i(800, 740)
 root.content_scale_size = root.size
 p._world_environment = WorldEnvironment.new()
 p._world_environment.environment = Environment.new()
 p.add_child(p._world_environment)
 p._key_light = DirectionalLight3D.new()
 p.add_child(p._key_light)
 p.theme_definition.configure_environment(p)
 p._world_environment.environment.background_mode = Environment.BG_COLOR
 p._world_environment.environment.background_color = Color("294451")
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 2.15
 camera.position = Vector3(1.0, 2.5, 4.8)
 p.add_child(camera)
 camera.look_at(Vector3(0, .65, 0))
 camera.current = true
 var canvas := CanvasLayer.new()
 root.add_child(canvas)
 var title := Label.new()
 title.text = "PALM ISLAND / THREE FLICKIES"
 title.position = Vector2(28, 20)
 title.add_theme_font_size_override("font_size", 28)
 canvas.add_child(title)
 var caption := Label.new()
 caption.text = "Sonic Runners / Original animal idle"
 caption.position = Vector2(28, 698)
 caption.add_theme_font_size_override("font_size", 19)
 canvas.add_child(caption)
 var folder := "res://test-results/flicky-frames"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 for frame in 8: await process_frame
 for frame in 96:
  for bird in birds: bird.set_animation_time(frame / 20.0)
  await process_frame
  await RenderingServer.frame_post_draw
  var image := root.get_texture().get_image()
  var result := image.save_png(folder + "/%03d.png" % frame)
  if frame == 5: image.save_png("res://test-results/palm-island-flickies.png")
  if result != OK:
   check(false, "Preview frame could not be written")
   break
 canvas.free()
