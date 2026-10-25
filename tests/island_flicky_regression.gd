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
