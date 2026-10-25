extends SceneTree
## Focused presentation integration and real-input gameplay probe. Physics is unchanged.
var game: Node
var failures := 0
var checks := 0
var capture_enabled := false
var captures_only := false
var report: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func frames(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func check(condition: bool, description: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", description)
 else:
  failures += 1
  push_error("FAIL | " + description)

func snapshot(label: String) -> void:
 if not capture_enabled:
  return
 await RenderingServer.frame_post_draw
 var directory := ProjectSettings.globalize_path("res://experiments/visual_lab/captures")
 DirAccess.make_dir_recursive_absolute(directory)
 var ignore := FileAccess.open(directory.path_join(".gdignore"), FileAccess.WRITE)
 ignore.close()
 var error := root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
 check(error == OK, "Rendered gameplay capture: " + label)

func geometry_matches() -> bool:
 game.character._process(0.0)
 if TablePresentation.unmap_point(game.character.marker.position).distance_to(game.ball.position) > 0.001:
  return false
 if game.presentation.find_children("*", "CollisionObject3D", true, false).size() > 0:
  return false
 for i in game.chunks.size():
  var data: ChunkData = game.chunks[i].data
  if game.presentation._outlines[i] != data.world_polygon(data.playfield_outline):
   return false
 for i in game.flippers.size():
  var visual: Node3D = game.presentation.flipper_visuals[i]
  var tip: Vector3 = visual.to_global(Vector3(game.flippers[i].length * TablePresentation.SCALE, 0, 0))
  if TablePresentation.unmap_point(tip).distance_to(game.flippers[i].tip()) > 0.01:
   return false
 return true

func event_probe() -> bool:
 # Each pair is probed through real contacts at several leverage points. A
 # single fixed point can overlap a bank or miss an asymmetric recovery paddle.
 var all_struck := true
 var saved_gravity: float = game.tuning.effective.gravity_scale
 game.tuning.effective.gravity_scale = 0.0
 for pair in [0, 2, 4]:
  var pair_struck := false
  for index in range(pair, mini(pair + 2, game.flippers.size())):
   for fraction: float in [0.5, 0.7, 0.9]:
    game.controls.virtual_left = false
    game.controls.virtual_right = false
    game.reset_ball()
    await frames(20)
    var flipper: PlaygroundFlipper = game.flippers[index]
    var before := flipper.strikes
    var start := flipper.position + Vector2.RIGHT.rotated(flipper.rest_angle()) * flipper.length * fraction + Vector2(0, -42)
    game.ball.teleport_to(start, Vector2(0, 100))
    await frames(3)
    game.controls.virtual_left = flipper.side > 0
    game.controls.virtual_right = flipper.side < 0
    for tick in 15:
     await frames(1)
     pair_struck = pair_struck or (flipper.strikes > before and game.character.event_pose == "jump" and game.character.event_time > 0.0)
    if pair_struck:
     break
   if pair_struck:
    break
  all_struck = all_struck and pair_struck
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 game.tuning.effective.gravity_scale = saved_gravity
 game.reset_ball()
 await frames(20)
 return all_struck

func play(label: String, trigger: float = 48.0) -> Dictionary:
 game.reset_ball()
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 await frames(20)
 var initial_hits: int = game.ball.bumper_hit_count
 var initial_rings: int = game.rings_collected
 var initial_try: int = game.ball_number
 game.launch_ball()
 var result := {"label": label, "trigger": trigger, "sections": [], "fell_from_top": false, "drains": 0, "relaunched": false, "bumper_hits": 0, "rings": 0, "poses": [], "minimum_y": game.ball.position.y, "finite": true, "ring_flights": false, "contact_aligned": true}
 var cooldown := 0
 var captured := false
 for tick in 90 * 120:
  cooldown = maxi(0, cooldown - 1)
  game.controls.virtual_left = cooldown > 15
  game.controls.virtual_right = cooldown > 15
  if result.sections.has(0):
   game.controls.virtual_left = false
   game.controls.virtual_right = false
  if not result.sections.has(0) and cooldown == 0 and game.ball.linear_velocity.y > 0.0:
   for flipper: PlaygroundFlipper in game.flippers:
    var nearest := Geometry2D.get_closest_point_to_segment(game.ball.position, flipper.position, flipper.tip())
    if game.ball.position.y < flipper.position.y + 15.0 and nearest.distance_to(game.ball.position) < trigger:
     cooldown = 30
     game.controls.virtual_left = true
     game.controls.virtual_right = true
     break
  await frames(1)
  var section: int = game.current_chunk_index()
  if section >= 0 and not result.sections.has(section):
   result.sections.append(section)
  if not result.poses.has(game.character.pose):
   result.poses.append(game.character.pose)
  result.fell_from_top = result.fell_from_top or (result.sections.has(0) and section == 2)
  result.minimum_y = minf(result.minimum_y, game.ball.position.y)
  result.finite = result.finite and game.ball.position.is_finite() and game.ball.linear_velocity.is_finite()
  result.ring_flights = result.ring_flights or not game.presentation.ring_pickups.is_empty()
  # Both anchors must match the same rendered physics snapshot. The 2D server
  # may publish its next tick before this SceneTree coroutine resumes.
  var contact_error: float = TablePresentation.unmap_point(game.character.marker.position).distance_to(TablePresentation.unmap_point(game.presentation.ball_visual.position))
  result.contact_aligned = result.contact_aligned and contact_error < 0.001
  result.drains = game.ball_number - initial_try
  result.relaunched = result.relaunched or (result.drains > 0 and not game.ball.serve_pending and game.respawn_time < 0.0 and game.ball.position.y < 1950.0)
  if not captured and tick > 120 and section == 1 and game.character.pose in ["jump", "trick"]:
   await snapshot(label + "_play")
   captured = true
   if captures_only:
    break
  if result.fell_from_top and result.relaunched:
   break
 result.bumper_hits = game.ball.bumper_hit_count - initial_hits
 result.rings = game.rings_collected - initial_rings
 result["strikes"] = []
 for flipper: PlaygroundFlipper in game.flippers:
  result.strikes.append(flipper.strikes)
 game.controls.virtual_left = false
 game.controls.virtual_right = false
 if not captured:
  await snapshot(label + "_play")
 return result

func run() -> void:
 capture_enabled = OS.get_cmdline_user_args().has("--screenshots")
 captures_only = capture_enabled and OS.get_cmdline_user_args().has("--captures-only")
 game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 root.add_child(game)
 await frames(5)
 game.controls.virtual_enabled = true
 game.toggle_debug()
 await frames(3)
 check(game.debug_panel.visible and game.debug_panel.panel.visible and game.debug_panel.generation_panel.visible and not game.lab_ui.visible, "F1 exposes the shared tuning, camera and grid-generator tools")
 game.toggle_debug()
 await frames(3)
 check(not game.debug_panel.visible and game.lab_ui.visible and game.view_container.offset_left == 0.0, "Closing tuning restores the full playable view")
 game._set_close_view(true)
 check(not game.request_generation(23), "Character study cannot regenerate underneath its paused camera")
 game._set_close_view(false)
 for specification: Array in [[18, 0, "normal18"], [23, 0, "normal23"], [18, 1, "grid_base18"], [23, 2, "grid_variant23"]]:
  paused = true
  if specification[1] > 0:
   # Grid shortcuts now preserve seed and difficulty instead of forcing a preset.
   game.request_generation(specification[0], TableGenerator.Difficulty.NORMAL)
   await frames(4)
  var old_terrain: Node3D = game.presentation.terrain_root
  var old_actor: Node3D = game.character
  var saved_tuning: Dictionary = game.tuning.effective.duplicate()
  game.presentation.physics_overlay.visible = true
  game.presentation.construction_grid_overlay.visible = true
  game.presentation.set_camera_value("look_ahead", 120.0)
  game.layout_buttons[["normal18", "normal23", "grid_base18", "grid_variant23"].find(specification[2])].pressed.emit()
  check(game.generation_pending, "Quick-build button requests layout " + specification[2])
  await frames(4)
  game.presentation._process(0.0)
  check(game.generation_seed == specification[0] and game.generation_grid_mode == specification[1] and is_instance_valid(old_actor) and game.character == old_actor and not is_instance_valid(old_terrain) and geometry_matches() and paused and game.ball.serve_pending and game.tuning.effective == saved_tuning and game.presentation.physics_overlay.visible and game.presentation.construction_grid_overlay.visible and game.presentation.camera_settings.look_ahead == 120.0, "Regeneration replaces scenery while retaining the character presenter and settings: " + specification[2])
  var listeners_ok: bool = game.ball.bumper_hit.get_connections().size() == 2 and game.ring_field.pickup_claimed.get_connections().size() == 2
  for flipper: PlaygroundFlipper in game.flippers:
   listeners_ok = listeners_ok and flipper.struck.get_connections().size() == 1
  check(listeners_ok, "Every regenerated paddle has one live pose listener; no stale actor listeners")
  game.presentation.physics_overlay.visible = false
  game.presentation.construction_grid_overlay.visible = false
  game.presentation.set_camera_follow(false)
  await frames(3)
  await snapshot(specification[2] + "_overview")
  game.presentation.set_camera_follow(true)
  paused = false
  check(await event_probe(), "Real bottom, middle and upper paddle contacts animate after regeneration: " + specification[2])
  var sample: Dictionary = {}
  for trigger: float in [58.0, 42.0, 48.0]:
   sample = await play(specification[2], trigger)
   report.append(sample)
   print("PLAY_ATTEMPT | ", JSON.stringify(sample))
   if captures_only or (sample.sections.size() == 3 and sample.fell_from_top):
    break
  if captures_only:
   continue
  check(sample.finite and sample.contact_aligned and sample.ring_flights and sample.sections.size() == 3 and sample.fell_from_top and sample.drains > 0 and sample.relaunched and sample.bumper_hits > 0 and sample.rings > 0, "Continuous normal-input run traverses three sections, falls back, hits bumpers and collects rings: " + specification[2])
  print("PLAY_SAMPLE | ", JSON.stringify(sample))
 if captures_only:
  print("PLAYABLE_CAPTURES | %d checks | %d failures" % [checks, failures])
  game.free()
  quit(0 if failures == 0 else 1)
  return
 # Controlled miss isolates the drain: no paddle presses or velocity edits after release.
 game.reset_ball()
 game.ball.teleport_to(Vector2(400, 1900), Vector2(0, 120))
 var initial_try: int = game.ball_number
 var respawned := false
 var relaunched := false
 for tick in 600:
  await frames(1)
  respawned = respawned or (game.ball_number > initial_try and game.ball.serve_pending)
  relaunched = relaunched or (respawned and not game.ball.serve_pending and game.respawn_time < 0 and game.ball.position.y < 1950)
 check(respawned and relaunched, "A genuine missed shot drains, respawns at the bottom and automatically relaunches")
 paused = true
 var position_before: Vector2 = game.ball.position
 var pulse_before: float = game.character.pulse_time
 await frames(10)
 check(game.ball.position == position_before and game.character.pulse_time == pulse_before, "Pause freezes physics and gameplay effects")
 paused = false
 print("PLAYABLE_GREEN_HILL | %d checks | %d failures" % [checks, failures])
 print("PLAY_REPORT | ", JSON.stringify(report))
 game.free()
 quit(0 if failures == 0 else 1)
