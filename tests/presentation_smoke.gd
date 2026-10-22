extends SceneTree
## Run graphically to capture identical seed/ball state through all three cameras.
var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func capture(filename: String) -> void:
 if DisplayServer.get_name() == "headless":
  return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://test-results/" + filename + ".png") == OK, "Rendered " + filename)

func framing_valid(presentation: TablePresentation) -> bool:
 var camera := presentation.camera
 var rect := Rect2(Vector2(8, 8), Vector2(camera.get_viewport().size) - Vector2(16, 16))
 # Include the board slab and taller-than-rendered bumper envelope, not just centers.
 var bounds := presentation.table_bounds.grow_individual(7.5, 25.0, 7.5, 25.0)
 for x: float in [bounds.position.x, bounds.end.x]:
  for z: float in [bounds.position.y, bounds.end.y]:
   for y in [-0.32, 0.55]:
    var point := TablePresentation.map_point(Vector2(x, z), y)
    if camera.is_position_behind(point) or not rect.has_point(camera.unproject_position(point)):
     return false
 return true

func perspective_ratio(presentation: TablePresentation) -> float:
 var camera := presentation.camera
 var bounds := presentation.table_bounds
 var near_width := camera.unproject_position(TablePresentation.map_point(bounds.end)).distance_to(camera.unproject_position(TablePresentation.map_point(Vector2(bounds.position.x, bounds.end.y))))
 var far_width := camera.unproject_position(TablePresentation.map_point(Vector2(bounds.end.x, bounds.position.y))).distance_to(camera.unproject_position(TablePresentation.map_point(bounds.position)))
 return near_width / far_width

func flippers_aligned(game: Node) -> bool:
 for i in game.flippers.size():
  var visual: Node3D = game.presentation.flipper_visuals[i]
  var visual_tip: Vector3 = visual.to_global(Vector3(game.flippers[i].length * TablePresentation.SCALE, 0, 0))
  if TablePresentation.unmap_point(visual_tip).distance_to(game.flippers[i].tip()) > 0.01:
   return false
 return true

func prism_faces_outward(presentation: TablePresentation) -> bool:
 # Both windings occur when chunks are mirrored. Test actual generated face normals.
 var points := PackedVector2Array([Vector2(-40, 35), Vector2(0, -50), Vector2(40, 35)])
 for mirrored in [false, true]:
  if mirrored:
   points.reverse()
  var mesh := presentation._prism(points, 0.34, null, null)
  var top: Array = mesh.surface_get_arrays(0)
  for normal: Vector3 in top[Mesh.ARRAY_NORMAL]:
   if normal.y < 0.99:
    return false
  var sides: Array = mesh.surface_get_arrays(1)
  var center := Vector3(0, 0.17, (35.0 - 50.0 + 35.0) / 3.0 * TablePresentation.SCALE)
  for i in sides[Mesh.ARRAY_VERTEX].size():
   var normal: Vector3 = sides[Mesh.ARRAY_NORMAL][i]
   if normal.dot(sides[Mesh.ARRAY_VERTEX][i] - center) <= 0.0:
    return false
 return true

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var game: Node = load("res://scenes/playground.tscn").instantiate()
 game.legacy_pair_fixture = true # Retain the original stationary-view comparison fixture.
 root.add_child(game)
 await create_timer(0.25).timeout
 game.presentation.set_camera_follow(false)
 var ui: PlaygroundDebugPanel = game.debug_panel
 var original_signature: String = game.layout.signature
 var original_position: Vector2 = game.ball.position
 var original_values: Dictionary = game.tuning.effective.duplicate()
 check(game.presentation.camera_preset == TablePresentation.CameraPreset.REAL_PINBALL and ui.camera_presets.selected == 1, "Real Pinball is the default and UI agrees")
 check(game.presentation.find_children("*", "CollisionObject3D", true, false).is_empty(), "Raised presentation has no 3D collision objects")
 check(prism_faces_outward(game.presentation), "Triangle top and side faces point outward for normal and mirrored chunks")
 var light: DirectionalLight3D = game.presentation.get_node("TableKeyLight")
 check(light.shadow_enabled and game.presentation.ball_visual.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Directional shadows and ball shadow casting are enabled")
 var ratios: Array[float] = []
 var names := ["depth-top-down", "depth-real-pinball", "depth-dramatic-pinball"]
 for preset in 3:
  ui.camera_presets.select(preset)
  ui.camera_presets.item_selected.emit(preset)
  await create_timer(0.1).timeout
  check(framing_valid(game.presentation), "%s keeps the entire board and height envelope inside the viewport" % TablePresentation.CAMERA_NAMES[preset])
  ratios.append(perspective_ratio(game.presentation))
  await capture(names[preset])
 check(is_equal_approx(ratios[0], 1.0) and ratios[1] > 1.2 and ratios[2] > ratios[1] + 0.2, "Perspective naturally enlarges the near edge; Dramatic strengthens the effect")
 print("CAMERA_WIDTH_RATIOS | ", ratios)
 check(game.layout.signature == original_signature and game.ball.position.is_equal_approx(original_position) and game.ball.linear_velocity.is_zero_approx() and game.tuning.effective == original_values, "Camera changes preserve layout, serve position, velocity and effective physics")
 # Inspect the camera-far side of a raised bumper, where occlusion is most likely.
 game.toggle_pause()
 await process_frame
 var probe_position := original_position
 for item: Dictionary in game.chunks[0].descriptors:
  if item.kind == "circle":
   probe_position = item.position + Vector2.UP * (item.radius + PlaygroundBall.RADIUS + 2.0)
   break
 game.ball.position = probe_position
 for preset in [1, 2]:
  ui.camera_presets.select(preset)
  ui.camera_presets.item_selected.emit(preset)
  await create_timer(0.1).timeout
  await capture("depth-bumper-clearance-%d" % preset)
 check(game.ball.position.is_equal_approx(probe_position), "Paused occlusion probe holds the ball two pixels beyond bumper contact")
 game.ball.position = original_position
 game.toggle_pause()
 var table_rect: Rect2 = game.view.get_parent().get_global_rect()
 check(not table_rect.intersects(ui.generation_panel.get_global_rect()) and not table_rect.intersects(ui.panel.get_global_rect()) and ui.camera_presets.get_global_rect().end.y < ui.panel.get_global_rect().end.y, "Table and camera controls remain clear of both debug panels")
 check(flippers_aligned(game), "Resting flipper tips match their 2D endpoints")
 Input.action_press("left_flipper")
 Input.action_press("right_flipper")
 await create_timer(0.12).timeout
 check(game.flippers[0].held and game.flippers[1].held and flippers_aligned(game), "Both moving paddles stay aligned during simultaneous input")
 Input.action_release("left_flipper")
 Input.action_release("right_flipper")
 await create_timer(0.15).timeout
 check(flippers_aligned(game), "Released paddles return in sync")
 game.toggle_pause()
 ui.camera_presets.select(1)
 ui.camera_presets.item_selected.emit(1)
 game.presentation.physics_overlay.visible = true
 game.presentation.chunk_overlay.visible = true
 game.presentation.connector_overlay.visible = true
 await create_timer(0.1).timeout
 check(paused and game.presentation.camera_preset == 1 and game.presentation.dynamic_geometry.get_surface_count() == 1, "Camera and ground-plane collision overlays work while paused")
 await capture("depth-collision-overlay")
 game.presentation.physics_overlay.visible = false
 game.presentation.chunk_overlay.visible = false
 game.presentation.connector_overlay.visible = false
 game.toggle_pause()
 for sample in [{"seed": 10, "preference": TableGenerator.Difficulty.EASY}, {"seed": 6, "preference": TableGenerator.Difficulty.NORMAL}]:
  game.request_generation(sample.seed, sample.preference)
  await create_timer(0.2).timeout
  check(game.generation_seed == sample.seed and game.presentation.camera_preset == 1 and ui.camera_presets.selected == 1 and framing_valid(game.presentation), "Seed %d rebuild preserves camera and framing" % sample.seed)
  await capture("depth-seed-%d-real" % sample.seed)
 game.launch_ball()
 var aligned := true
 var stationary: Transform3D = game.presentation.camera.transform
 for frame in 120:
  # SceneTree timers run after Node._process; process_frame fires before visual sync.
  await create_timer(1.0 / 120.0).timeout
  aligned = aligned and game.presentation.ball_visual.position.distance_to(TablePresentation.map_point(game.ball.position, TablePresentation.BALL_HEIGHT)) < 0.001
 check(aligned and not game.ball.serve_pending and game.presentation.camera.transform == stationary, "Moving ball follows exact 2D mapping while camera stays stationary")
 print("RESULT | Presentation | %d checks | %d failures" % [checks, failures])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
