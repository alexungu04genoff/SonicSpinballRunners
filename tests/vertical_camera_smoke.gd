extends SceneTree
## Controlled visual probes exercise camera behavior without changing gameplay physics.
## Run graphically for snapshots; headless still checks the camera and scene contract.
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String, detail: String = "") -> void:
 checks += 1
 if condition:
  print("PASS | ", label, " | ", detail)
 else:
  failures += 1
  push_error("FAIL | " + label + " | " + detail)

func capture(filename: String) -> void:
 if DisplayServer.get_name() == "headless":
  return
 game.debug_panel._process(0.10)
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://test-results/" + filename + ".png") == OK, "Rendered " + filename)

func visible_point(presentation: TablePresentation, point: Vector3, margin: float = 6.0) -> bool:
 var camera := presentation.camera
 var viewport := Rect2(Vector2.ONE * margin, Vector2(camera.get_viewport().size) - Vector2.ONE * margin * 2.0)
 return not camera.is_position_behind(point) and viewport.has_point(camera.unproject_position(point))

func overview_framed(presentation: TablePresentation) -> bool:
 var bounds := presentation.table_bounds.grow_individual(7.5, 25.0, 7.5, 25.0)
 for x: float in [bounds.position.x, bounds.end.x]:
  for y: float in [bounds.position.y, bounds.end.y]:
   for height: float in [-0.32, 0.60]:
    if not visible_point(presentation, TablePresentation.map_point(Vector2(x, y), height)):
     return false
 return true

func aligned() -> bool:
 var p: TablePresentation = game.presentation
 for i in game.flippers.size():
  var tip := p.flipper_visuals[i].to_global(Vector3(game.flippers[i].length * TablePresentation.SCALE, 0, 0))
  if TablePresentation.unmap_point(tip).distance_to(game.flippers[i].tip()) > 0.01:
   return false
 for i in p.ring_visuals.size():
  if not p.ring_pickups.has(i) and game.ring_field.rings[i].active:
   if p.ring_visuals[i].position.distance_to(TablePresentation.map_point(game.ring_field.rings[i].position, TablePresentation.RING_HEIGHT)) > 0.001:
    return false
 return p.ball_visual.position.distance_to(TablePresentation.map_point(game.ball.position, TablePresentation.BALL_HEIGHT)) < 0.001

func simulate(rate: int, descending: bool) -> Dictionary:
 var p: TablePresentation = game.presentation
 var duration := 1.2
 var start := Vector2(400, 220 if descending else 1900)
 var speed := 1480.0 if descending else -1400.0
 game.ball.position = start
 p.reset_camera(start)
 var previous := p.camera_focus
 var max_step := 0.0
 var framed := true
 var monotonic := true
 for i in int(rate * duration):
  game.ball.position = start + Vector2(0, speed * (i + 1) / rate)
  p._update_camera(1.0 / rate)
  max_step = maxf(max_step, previous.distance_to(p.camera_focus))
  monotonic = monotonic and ((p.camera_focus.y >= previous.y - 0.001) if descending else (p.camera_focus.y <= previous.y + 0.001))
  framed = framed and visible_point(p, TablePresentation.map_point(game.ball.position, TablePresentation.BALL_HEIGHT))
  previous = p.camera_focus
 return {"focus": p.camera_focus, "framed": framed, "monotonic": monotonic, "max_step": max_step}

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 game = load("res://scenes/playground.tscn").instantiate()
 root.add_child(game)
 await create_timer(0.15).timeout
 paused = true
 game.ball.freeze = true
 var p: TablePresentation = game.presentation
 # Disable automatic rendering updates during deterministic manual camera steps.
 p.set_process(false)
 p._process(0.0)
 check(game.chunks.size() == 3 and game.flippers.size() == 5 and p.camera_follow_enabled, "Three-section game starts with five paddles and follow enabled")
 check(p.table_bounds == game.layout.bounds and p.find_children("*", "CollisionObject3D", true, false).is_empty() and aligned(), "All presentation objects use shared world mapping and have no gameplay collision")
 var floor_mesh: BoxMesh = p.get_node("TableFloor").mesh
 check(is_equal_approx(floor_mesh.size.z, (p.table_bounds.size.y + 50.0) * TablePresentation.SCALE), "Board slab spans generated bounds")
 var signature: String = game.layout.signature
 var values: Dictionary = game.tuning.effective.duplicate()
 var position: Vector2 = game.ball.position
 game.debug_panel.camera_follow.button_pressed = false
 for preset in 3:
  game.debug_panel.camera_presets.select(preset)
  game.debug_panel.camera_presets.item_selected.emit(preset)
  await process_frame
  check(overview_framed(p), "%s overview contains full floor and raised-object envelope" % TablePresentation.CAMERA_NAMES[preset])
  await capture("vertical-overview-%d" % preset)
 check(game.layout.signature == signature and game.ball.position == position and game.tuning.effective == values, "Overview and preset changes leave ball, layout and physics unchanged")
 game.debug_panel.camera_presets.select(TablePresentation.CameraPreset.REAL_PINBALL)
 game.debug_panel.camera_presets.item_selected.emit(TablePresentation.CameraPreset.REAL_PINBALL)
 game.debug_panel.camera_follow.button_pressed = true
 var fixed_rotation: Basis = p.camera.basis
 for descending in [false, true]:
  var sixty := simulate(60, descending)
  var one_twenty := simulate(120, descending)
  check(sixty.monotonic and one_twenty.monotonic and sixty.framed and one_twenty.framed and sixty.max_step <= float(p.camera_settings.max_speed) / 60.0 + 0.001 and one_twenty.max_step <= float(p.camera_settings.max_speed) / 120.0 + 0.001, "Camera tracks %s at 60/120 Hz with visible ball and bounded monotonic movement" % ("descent" if descending else "ascent"), str([sixty, one_twenty]))
  check(sixty.focus.distance_to(one_twenty.focus) < 15.0, "Camera response is consistent across 60/120 Hz")
 game.ball.position = Vector2(400, 1100)
 p.reset_camera(game.ball.position)
 game.ball.position.y += float(p.camera_settings.dead_zone_y) * 0.5
 var stationary := p.camera_focus
 p._update_camera(0.05)
 check(p.camera_focus.is_equal_approx(stationary), "Vertical dead zone absorbs small ball movement")
 game.ball.position = Vector2(700, 1100)
 var prior := p.camera_focus
 p._update_camera(1.0 / 60.0)
 check(p.camera_focus.x > prior.x and p.camera_focus.x - prior.x < 3.0, "Horizontal response is gentle instead of snapping toward side bounces")
 game.ball.position = Vector2(100, 200)
 prior = p.camera_focus
 p._update_camera(1.0 / 60.0)
 check(visible_point(p, TablePresentation.map_point(game.ball.position, p.ball_height())) and p.camera.basis.is_equal_approx(fixed_rotation), "Abrupt rebound prioritizes ball visibility over the soft speed cap and keeps rotation fixed")
 prior = p.camera_focus
 p._process(0.5)
 check(p.camera_focus == prior, "Pause freezes follow despite changed ball observations")
 for probe: Dictionary in [{"name": "bottom", "point": Vector2(665, 1820)}, {"name": "middle", "point": Vector2(400, 1050)}, {"name": "top", "point": Vector2(400, 280)}]:
  game.ball.position = probe.point
  p.reset_camera(probe.point)
  p._process(0.0)
  check(visible_point(p, p.ball_visual.position) and aligned(), "Follow %s snapshot keeps mapped ball and five paddles aligned" % probe.name)
  await capture("vertical-follow-" + probe.name)
 p.physics_overlay.visible = true
 p.chunk_overlay.visible = true
 p.connector_overlay.visible = true
 p._process(0.0)
 await capture("vertical-follow-overlay")
 game.ball.serve_pending = false
 game.ball.position = game.ring_field.rings[0].position
 game.ring_field.previous_ball_position = game.ball.position
 game.ring_field._physics_process(1.0 / 120.0)
 p._process(0.0)
 var ring_home: Vector3 = p.ring_visuals[0].position
 game.ball.position += Vector2(90, 60)
 p._process(0.0)
 p._update_ring_visuals(0.10)
 check(p.ring_pickups.has(0) and not game.ring_field.rings[0].active and p.ring_visuals[0].position.is_equal_approx(ring_home.lerp(p.ball_visual.position, 0.25)), "Claimed ring flight still targets the moving ball under the shared mapping")
 game.debug_panel.camera_fields.look_ahead.value = 140.0
 game.debug_panel.camera_fields.max_speed.value = 2200.0
 game.reset_ball(false)
 check(p.camera_focus.y > p.table_bounds.get_center().y and p.ring_pickups.is_empty(), "Reset immediately reframes bottom and clears cosmetic flights")
 game.ring_field.reset_rings()
 game.ball.serve_pending = false
 game.ball.position = game.ring_field.rings[0].position
 game.ring_field.previous_ball_position = game.ball.position
 game.ring_field._physics_process(1.0 / 120.0)
 var old_ring: MeshInstance3D = p.ring_visuals[0]
 var settings := p.camera_settings.duplicate()
 game.request_generation(3, TableGenerator.Difficulty.HARD)
 for i in 3:
  await process_frame
 p = game.presentation
 p.set_process(false)
 p._process(0.0)
 check(p.camera_follow_enabled and p.camera_settings == settings and p.camera_preset == TablePresentation.CameraPreset.REAL_PINBALL and p.camera_focus.y > p.table_bounds.get_center().y and p.ring_pickups.is_empty() and not is_instance_valid(old_ring) and game.ring_field.pickup_claimed.get_connections().size() == 1 and aligned(), "Regeneration preserves camera settings and mode, resets bottom framing and leaves no stale flight objects")
 p.set_camera_follow(false)
 game.request_generation(7, TableGenerator.Difficulty.NORMAL)
 for i in 3:
  await process_frame
 p = game.presentation
 check(not p.camera_follow_enabled and overview_framed(p) and p.camera_settings == settings, "Overview mode and complete bounds framing survive another regeneration")
 print("RESULT | Vertical camera | %d checks | %d failures" % [checks, failures])
 paused = false
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
