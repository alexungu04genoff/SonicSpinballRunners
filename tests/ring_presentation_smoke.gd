extends SceneTree
## Deterministic pickup lifecycle checks; graphical runs also capture the flight.
var game: Node
var field: RingField
var checks := 0
var failures := 0
var events := 0
const STEP := 1.0 / 120.0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, label: String) -> void:
 checks += 1
 if condition:
  print("PASS | ", label)
 else:
  failures += 1
  push_error("FAIL | " + label)

func capture(name: String) -> void:
 if DisplayServer.get_name() == "headless":
  return
 # Hold the manually positioned physics fixture while waiting for the render thread.
 var was_paused := paused
 paused = true
 game.presentation._process(0.0)
 await RenderingServer.frame_post_draw
 var result: int = game.view.get_texture().get_image().save_png("res://test-results/pickup-" + name + ".png")
 paused = was_paused
 check(result == OK, "Rendered pickup-" + name)

func prepare() -> void:
 field.reset_rings()
 game.score = 0
 game.rings_collected = 0
 game.special_meter = 0
 game.ring_reset_time = -1
 game.respawn_time = -1
 game.auto_launch_time = -1
 events = 0
 game.tuning.set_value("ring_magnet_radius", 50)
 game.ball.position = Vector2(190, 180)
 # This frozen-body fixture supplies its own settled position instead of letting
 # the physics server consume the previous reset's queued teleport.
 game.ball._teleport_pending = false
 game.ball.serve_pending = false
 field.previous_ball_position = game.ball.position

func claim_three() -> void:
 game.ball.position = Vector2(190, 500)
 field._physics_process(STEP)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var document = preload("res://scripts/act_editor/act_geometry.gd").new()
 document.title = "Ring pickup fixture"
 document.cell_size = 100.0
 document.grid_size = Vector2i(8, 11)
 document.spawn_position = Vector2(400, 1000)
 # Keep unclaimed rings away from the sweep, so this tests pickup scoring
 # independently of the separate rack-clear bonus.
 document.ring_trails = [{"start": Vector2(190, 260), "end": Vector2(190, 460), "spacing": 100.0},
  {"start": Vector2(600, 800), "end": Vector2(700, 800), "spacing": 100.0}]
 var path := "res://test-results/ring-pickup-act.tres"
 check(document.save_document(path) == OK, "Save authored pickup fixture")
 game = load("res://scenes/playground.tscn").instantiate()
 game.authored_act_path = path

 root.add_child(game)
 await create_timer(0.1).timeout
 game.set_physics_process(false)
 game.ball.freeze = true
 game.controls.virtual_enabled = true
 field = game.ring_field
 field.set_physics_process(false)
 field.collected.connect(func(_where: Vector2): events += 1)
 var presentation: TablePresentation = game.presentation
 presentation.set_process(false)
 prepare()
 game.ball.teleport_to(Vector2(190, 500))
 field._physics_process(STEP)
 check(events == 0 and field.rings[0].active and presentation.ring_pickups.is_empty(), "Queued teleports cannot collect rings along an artificial movement segment")
 prepare()
 field._physics_process(STEP)
 presentation._process(1.0)
 var home := TablePresentation.map_point(field.rings[0].home, presentation.ring_height())
 check(events == 0 and presentation.ring_visuals[0].position == home and presentation.ring_visuals[0].visible, "Unclaimed rings stay at home outside magnet radius")

 claim_three()
 check(events == 3 and game.score == 75 and game.rings_collected == 3 and game.special_meter == 15 and presentation.ring_pickups.size() == 3 and presentation.ring_visuals[0].visible, "One fast sweep awards three rings immediately while all three visuals remain alive")
 await capture("claimed")
 presentation._process(0.05)
 var early_distance: float = presentation.ring_visuals[0].position.distance_to(home)
 presentation._process(0.05)
 var later_distance: float = presentation.ring_visuals[0].position.distance_to(home)
 check(early_distance > 0 and later_distance > early_distance * 3.5 and presentation.ring_visuals[0].visible, "Pickup accelerates toward the ball instead of moving at constant speed")

 game.ball.position = Vector2(560, 540)
 game.tuning.set_value("ring_magnet_radius", 0)
 presentation._process(0.05)
 var visual := presentation.ring_visuals[0]
 var toward_current := (presentation.ball_visual.position - home).normalized()
 check((visual.position - home).normalized().dot(toward_current) > 0.999 and visual.visible and visual.scale.x < 1.0 and presentation.ring_pickups.size() == 3, "Claimed rings follow the moving visible ball outside radius, even after magnetism is disabled")
 await capture("chasing")
 var paused_position := visual.position
 var paused_scale := visual.scale
 paused = true
 presentation._process(1.0)
 check(visual.position == paused_position and visual.scale == paused_scale and presentation.ring_pickups.size() == 3, "Pause freezes flight and its final shrink")
 paused = false
 game.ball.position += Vector2(80, 30)
 presentation._process(0.05)
 var all_arrived := true
 for i in 3:
  all_arrived = all_arrived and not presentation.ring_visuals[i].visible and presentation.ring_visuals[i].position.is_equal_approx(presentation.ball_visual.position)
 presentation._process(1.0)
 check(all_arrived and presentation.ring_pickups.is_empty() and events == 3 and game.score == 75 and game.special_meter == 15, "All flights reach the current ball at 0.20 seconds and vanish without duplicate rewards")
 await capture("arrived")

 prepare()
 claim_three()
 presentation._process(0.08)
 game.reset_ball(false)
 presentation._process(0.01)
 check(presentation.ring_pickups.is_empty() and not presentation.ring_visuals[0].visible and not field.rings[0].active and game.score == 75 and game.rings_collected == 3, "Ball reset clears flights and keeps earned rings instead of flying to serve")

 prepare()
 claim_three()
 game.ball.position = Vector2(400, 1460)
 game._physics_process(STEP)
 check(game.respawn_time > 0 and presentation.ring_pickups.is_empty() and not presentation.ring_visuals[0].visible and game.score == 75, "Drain clears active flights without undoing rewards")
 for i in 79:
  game._physics_process(STEP)
 check(game.ball.serve_pending and presentation.ring_pickups.is_empty(), "Automatic respawn does not resurrect old flights")

 prepare()
 claim_three()
 presentation._process(0.16)
 field.reset_rings()
 check(presentation.ring_pickups.is_empty() and visual.visible and visual.position == home and visual.scale == Vector3.ONE, "Rack reset restores visual positions and scale while cancelling any unfinished flights")
 field.previous_ball_position = Vector2(190, 180)
 claim_three()
 check(presentation.ring_pickups.size() == 3 and visual.position == home and events == 6, "A rack reset and recollection in one frame start fresh flights and award once per rack")
 presentation._process(1.0)
 check(presentation.ring_pickups.is_empty() and not visual.visible, "A long frame completes pickups without leaving stale visuals")

 prepare()
 claim_three()
 var old_visual: MeshInstance3D = presentation.ring_visuals[0]
 paused = true
 var requested: bool = game.request_replay()
 await process_frame
 await process_frame
 check(requested and not is_instance_valid(old_visual) and is_instance_valid(presentation) and game.presentation == presentation and game.presentation.ring_pickups.is_empty() and game.rings_collected == 0 and field.pickup_claimed.get_connections().size() == 1, "Paused Act replay replaces old ring meshes on the retained presenter and leaves one live pickup listener")
 paused = false
 game.presentation.set_process(false)
 game.ball.freeze = true
 game.ball._teleport_pending = false # Settle the reloaded frozen-body fixture.
 game.ball.serve_pending = false
 game.ball.position = field.rings[0].position
 field.previous_ball_position = game.ball.position
 field._physics_process(STEP)
 game.presentation._process(0.1)
 check(not field.rings[0].active and game.presentation.ring_visuals[0].visible and game.presentation.ring_pickups.has(0) and game.presentation.find_children("*", "CollisionObject3D", true, false).is_empty(), "Reloaded Act pickups animate normally with no 3D collision objects")

 print("RESULT | Ring presentation | %d checks | %d failures" % [checks, failures])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
