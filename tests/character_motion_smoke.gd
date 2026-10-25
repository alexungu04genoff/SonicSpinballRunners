extends SceneTree
## Controlled presentation paths; no claims about input-only gameplay feel.
var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
 else:
  print("PASS | ", label)

func run() -> void:
 var game = load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 root.add_child(game)
 await process_frame
 await process_frame
 paused = true
 var actor = game.character
 actor.set_process(false)
 game.presentation.set_process(false)
 var trail = actor.trail
 var camera: Camera3D = game.presentation.camera
 var center: Vector3 = actor.spin_root.position + Vector3(0, 2.0, -1.0)
 camera.position = center + Vector3(0.4, 2, 1.8)
 camera.look_at(center + Vector3(0.4, 0, 0.2))
 camera.fov = 30.0
 var velocity: Vector2 = game.ball.linear_velocity
 var position: Vector2 = game.ball.position
 for id in ["sonic", "tails", "knuckles", "shadow"]:
  actor.character_id = id
  actor._apply_character_color()
  for step in 32:
   var angle := float(step) / 31.0 * 1.8
   var point := center + Vector3(sin(angle) * 0.7, 0.0, cos(angle) * 0.7)
   trail.advance(1.0 / 120.0, point, true, camera)
   actor.spin_root.position = point
   actor.spin_root.rotation = Vector3(-0.6, 0.5, 0.3)
  var expected_hue: float = Color("2635f5").h if id == "sonic" else CharacterSpecials.CHARACTERS[id].color.h
  check(trail.visible and trail.tint.s > 0.8 and absf(trail.tint.h - expected_hue) < 0.01, id + " has a continuous character-colored ribbon")
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   game.view.get_texture().get_image().save_png("res://test-results/character-motion-" + id + ".png")
 var ages: Array = trail.ages.duplicate()
 trail.advance(0.0, actor.spin_root.position, true, camera)
 check(trail.ages == ages, "Paused ribbon retains its age and samples")
 trail.advance(0.4, actor.spin_root.position, false, camera)
 check(not trail.visible and trail.points.is_empty(), "Stopped ribbon expires instead of leaving stale geometry")
 trail.advance(0.01, center, true, camera)
 trail.advance(0.01, center + Vector3.RIGHT, true, camera)
 actor.resume_gameplay()
 check(not trail.visible and trail.points.is_empty(), "Resume/reset clears the ribbon immediately")
 var start_basis: Basis = actor.spin_root.basis
 actor._advance_spin(0.1, Vector2.ZERO)
 check(not actor.spin_root.basis.is_equal_approx(start_basis), "Curled spin continues at zero velocity near a jump apex")
 var paused_basis: Basis = actor.spin_root.basis
 actor._advance_spin(0.0, Vector2(800, 0))
 check(actor.spin_root.basis == paused_basis, "Zero simulation delta freezes spin")
 actor.spin_root.basis = Basis.IDENTITY
 actor._spin_axis = Vector3.RIGHT
 for tick in 60:
  actor._advance_spin(1.0 / 60.0, Vector2.ZERO)
 var at_60: Basis = actor.spin_root.basis
 actor.spin_root.basis = Basis.IDENTITY
 for tick in 120:
  actor._advance_spin(1.0 / 120.0, Vector2.ZERO)
 check(actor.spin_root.basis.is_equal_approx(at_60), "Spin rate remains consistent at 60 and 120 FPS")
 if DisplayServer.get_name() != "headless":
  actor.character_id = "sonic"
  actor._apply_character_color()
  for frame in 18:
   actor._advance_spin(1.0 / 30.0, Vector2.ZERO)
   await RenderingServer.frame_post_draw
   game.view.get_texture().get_image().save_png("res://test-results/character-spin-%02d.png" % frame)
 check(game.ball.position == position and game.ball.linear_velocity == velocity, "Visual updates leave authoritative position and velocity untouched")
 print("CHARACTER_MOTION_SMOKE | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
