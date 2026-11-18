extends "res://tests/prototype_act_playtest_regression.gd"
## Run with -- --act "res://data/acts/Experiments/Side to Side.tres".

func steps(count: int) -> void:
 for frame in count: await physics_frame

func run() -> void:
 session = Session.new()
 session.settings_path = "user://side-to-side-test-%d.cfg" % Time.get_ticks_usec()
 root.add_child(session)
 if not await wait_started():
  push_error("Side to Side did not start")
  quit(1)
  return
 var game: Node = session.game
 var manager: Node = game.active.runtime.mechanics
 var bumper: Dictionary = manager.by_id.shuttle
 var chute: Dictionary = manager.by_id.bars
 var ball: PlaygroundBall = game.ball
 var camera: TablePresentation = game.presentation
 var initial := camera.camera_preset
 var close_extent := camera._follow_window_size()
 var original_angle := camera.camera.basis
 var key := InputEventKey.new()
 key.keycode = KEY_C
 key.pressed = true
 root.push_input(key, true)
 check(camera.camera_preset == camera.CameraPreset.WIDE_PINBALL and camera._follow_window_size().y > close_extent.y and camera.camera.basis.is_equal_approx(original_angle), "C widens the table at the same angle")
 key.echo = true
 root.push_input(key, true)
 check(camera.camera_preset == camera.CameraPreset.WIDE_PINBALL, "Holding C does not skip views")
 key.echo = false
 root.push_input(key, true)
 check(not camera.camera.basis.is_equal_approx(original_angle), "Next view changes elevation")
 root.push_input(key, true)
 check(camera.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Top-down uses orthographic projection")
 root.push_input(key, true)
 check(camera.camera_preset == initial, "Camera cycle returns to the starting view")
 key.shift_pressed = true
 root.push_input(key, true)
 check(camera.camera_preset == camera.CameraPreset.TOP_DOWN, "Shift+C cycles backward")
 var top := Vector2(chute.position) + Vector2.UP * float(chute.properties.width) * 0.3
 var initial_score: int = game.score
 ball.teleport_to(top + Vector2.DOWN * 48.0, Vector2.UP * 800.0)
 await steps(16)
 check(not ball.on_ramp and ball.position.y < top.y and game.score == initial_score, "Upward shot passes through without an award")
 ball.teleport_to(top + Vector2.UP * 20, Vector2.DOWN * 700.0)
 await steps(12)
 check(ball.on_ramp and chute.lit_bars == 1 and game.score == initial_score + 25, "Top crossing captures the ball and pays the first bar")
 await steps(20)
 check(chute.lit_bars == 2 and game.score == initial_score + 50, "Second bar pays once")
 await steps(20)
 check(chute.lit_bars == 3 and game.score == initial_score + 75, "Third bar pays once")
 await steps(20)
 check(not ball.on_ramp and ball.collision_mask != 0 and ball.position.y > chute.position.y and game.score == initial_score + 75, "Ball releases downward with its collisions restored")
 ball.teleport_to(top + Vector2.UP * 20, Vector2.DOWN * 700.0)
 await steps(12)
 ball.teleport_to(game.ball.serve_position, Vector2.ZERO, true)
 await steps(65)
 check(not ball.on_ramp and chute.lit_bars == 0 and game.score == initial_score + 100, "Retry cancels remaining ticks")
 var at: Vector2 = bumper.body.position
 var hits := ball.bumper_hit_count
 ball.teleport_to(at + Vector2.UP * 54.0, Vector2.DOWN * 650.0)
 await steps(12)
 check(ball.bumper_hit_count == hits + 1 and ball.linear_velocity.y < 0, "Moving oval rebounds and counts one physical bumper hit")
 check(game.score >= initial_score + 200, "Moving oval awards normal bumper points")
 check(bumper.body.position.x != at.x and is_equal_approx(bumper.body.position.y, at.y) and is_zero_approx(bumper.body.rotation), "Collision body moves horizontally without spinning")
 var seen_reverse := false
 var previous_x: float = bumper.body.position.x
 var previous_step := 0.0
 for frame in 200:
  await physics_frame
  var shift: float = bumper.body.position.x - previous_x
  if shift * previous_step < 0: seen_reverse = true
  if not is_zero_approx(shift): previous_step = shift
  previous_x = bumper.body.position.x
 check(seen_reverse, "Bumper reverses at the end of its patrol")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(session._camera_settings_path()))
 await session._close_run("finished")
 session.free()
 paused = false
 print("RESULT | Side to Side | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
