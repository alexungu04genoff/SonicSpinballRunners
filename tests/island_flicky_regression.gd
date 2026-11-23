extends SceneTree
## Checks live pause/lifetime behavior and samples the full decorative animation.
## A graphical run also renders a repeatable 4.8-second preview at 20 fps.
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Presentation = preload("res://scripts/themes/themed_presentation.gd")
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
 var initial_time: float = birds[0].animation_time
 for frame in 3: await process_frame
 check(birds[0].animation_time > initial_time, "Animation advances in the live scene tree")
 paused = true
 var paused_time: float = birds[0].animation_time
 for frame in 3: await process_frame
 check(birds[0].animation_time == paused_time, "Animation freezes during scene-tree pause")
 paused = false
 for frame in 3: await process_frame
 check(birds[0].animation_time > paused_time, "Animation resumes after pause")
 for bird in birds: bird.set_process(false)
 var bounds_check := Bounds.new()
 var bounded := true
 var collisionless := true
 var grounded := true
 var heights: Dictionary = {}
 var wing_angles: Dictionary = {}
 for frame in 96:
  for bird in birds:
   bird.set_animation_time(frame / 20.0)
   var boxes: Array[AABB] = []
   collisionless = bounds_check.collect_bounds(bird, boxes) and collisionless
   for box in boxes:
    grounded = grounded and box.position.y >= .335
    for corner in 8:
     var point := box.get_endpoint(corner)
     bounded = bounded and Vector2(point.x, point.z).length() < .80
   heights[snappedf(bird.pose.position.y, .001)] = true
   wing_angles[snappedf(bird.wings[0].rotation.z, .01)] = true
 check(collisionless, "Every animated descendant stays finite and collisionless")
 check(bounded, "All birds remain inside the island throughout the full cycle")
 check(grounded, "Feet never pass through the turf")
 check(heights.size() > 5 and wing_angles.size() > 5, "Hops and wing flutters have distinct animated poses")
 for bird in birds: bird.set_animation_time(.24)
 check(birds[0].pose.position.y > .10 and is_zero_approx(birds[1].pose.position.y), "Birds hop at staggered phases")
 var sample: Transform3D = birds[0].pose.transform
 birds[0].set_animation_time(.24 + birds[0].CYCLE * 100)
 check(birds[0].pose.transform.is_equal_approx(sample), "Animation loops without long-run drift")
 bounds_check.free()
 check_act_visit(p)
 if DisplayServer.get_name() != "headless" and failures == 0:
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
  var state: Dictionary = visitor.choose_perch(document, runtime, offset, rng)
  if state.is_empty():
   empty += 1
   continue
  chosen = state
  placement_state = before
  variants[state.gold] = true
  perches[state.perch] = true
  check(Geometry2D.is_point_in_polygon(state.perch, polygon), "Visit lands inside the offset Act's raised bank")
 check(perches.size() > 1 and empty > 0, "Fresh visits vary perch and can leave the Act empty")
 check(variants.size() == 2, "Both blue and gold visits can be drawn")
 check(visitor.choose_perch(document, {"terrain": [], "objects": []}, offset, rng).is_empty(), "Empty terrain has no invented perch")
 if chosen.is_empty():
  visitor.free()
  return
 # Reuse a successful set of rolls to distinguish blocked sites from the no-visit roll.
 rng.state = placement_state
 var blocked := runtime.duplicate()
 blocked.floor_outline = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
 check(visitor.choose_perch(document, blocked, offset, rng).is_empty(), "Banks facing off the playable deck are skipped")
 document.decor_slots.assign([{"position": Vector2(5, 5) * cell, "slot_type": "landmark", "scale": 8.0}])
 rng.state = placement_state
 check(visitor.choose_perch(document, runtime, offset, rng).is_empty(), "A landmark occupying the whole bank leaves no perch")
 document.decor_slots.clear()
 var bumper := ActGameplayObjects.make_placement("round_bumper")
 bumper.position = Vector2(5, 5) * cell + offset
 bumper.properties.scale = 30.0
 blocked = runtime.duplicate()
 blocked.objects = [bumper]
 rng.state = placement_state
 check(visitor.choose_perch(document, blocked, offset, rng).is_empty(), "Large hardware excludes its full footprint")
 p.ball = PlaygroundBall.new()
 p.add_child(visitor)
 chosen.gold = false
 visitor.enter(p, chosen, cell)
 check(visitor.visible and visitor.find_children("*", "CollisionObject3D", true, false).is_empty(), "Visitor is visible and collisionless")
 p.ball.position = chosen.perch + Vector2.RIGHT * cell * 0.8
 p.ball.linear_velocity = Vector2.LEFT * cell
 p.ball.serve_pending = true
 visitor._process(0.1)
 check(not chosen.departed, "Parked ball cannot startle a Flicky")
 p.ball.serve_pending = false
 p.ball.freeze = false
 visitor._process(0.15)
 check(chosen.departed and visitor.heading.x < 0 and visitor.position.y > p.RAIL_HEIGHT + p.RAIL_CAP_HEIGHT, "Approaching ball sends the Flicky up and away")
 var wing: float = visitor.blue_bird.wings[0].rotation.z
 visitor._process(0.07)
 check(not is_equal_approx(wing, visitor.blue_bird.wings[0].rotation.z), "Blue visitor flaps during takeoff")
 visitor._process(1.5)
 visitor.enter(p, chosen, cell)
 check(not visitor.visible and not visitor.is_processing(), "Completed visit stays empty on re-entry")
 var fresh := chosen.duplicate()
 fresh.departed = false
 fresh.gold = true
 visitor.checked_gold = true # Exercise a portable build without the optional local rig.
 visitor.enter(p, fresh, cell)
 check(visitor.visible and visitor.bird == visitor.blue_bird, "A gold roll uses the blue bird when local art is absent")
 visitor.checked_gold = false
 visitor.enter(p, fresh, cell)
 check(visitor.visible and visitor.bird.visible, "A new Act can host a gold visit or its portable blue alternative")
 visitor.enter(p, {}, cell)
 check(not visitor.visible and not visitor.is_processing(), "Switching to an empty Act clears the previous visitor")
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
 caption.text = "Procedural meshes / Hops, wing flutters and head turns"
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
