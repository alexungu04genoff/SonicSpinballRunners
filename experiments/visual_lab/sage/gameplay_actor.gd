extends "res://experiments/visual_lab/sage/actor.gd"
## The shared traversal controller selects actions. This presenter supplies Sage's rig and effects.
const VICTORIES := ["Victory Reach", "Victory Guard", "Victory Kick"]
var animated := false
var victory_index := -1
var victory_hold := 0.0
var victory_reveal := 0.0

func prepare_gameplay(model_path := MODEL) -> void:
 animated = FileAccess.file_exists(model_path) and prepare(model_path)
 if not ball_root: prepare_ball()
 play(BALL)

func celebrate(duration: float) -> void:
 if not animated: return
 victory_index = (victory_index + 1) % VICTORIES.size()
 play(VICTORIES[victory_index], true)
 victory_reveal = morph_duration if morph else 0.0
 victory_hold = duration

func advance_on_ball(controller: Node, delta: float) -> void:
 var presenter: Node3D = controller.presenter
 var ball: PlaygroundBall = presenter.ball
 var camera: Camera3D = presenter.table.camera
 var anchor: Vector3 = presenter.spin_root.global_position
 var fit := float(controller.radius) / ball_radius
 global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * fit), anchor)
 var frame := camera.global_basis.orthonormalized()
 var clip := "Hover" if ball.serve_pending else BALL
 var lift := Vector3.UP * ball_radius * (0.65 + 0.1 * sin(elapsed * TAU / 1.6))
 var pose_at := -1.0
 if controller.motion == &"loop": victory_hold = 0.0
 if victory_hold > 0.0:
  clip = VICTORIES[victory_index]
  var progress := clampf((elapsed + delta - victory_reveal) / victory_hold, 0.0, 1.0)
  frame = VictoryTurn.basis(camera.global_basis, progress)
  pose_at = progress * player.get_animation(clip).length
  lift = Vector3.ZERO
  if progress >= 1.0: victory_hold = 0.0
 else:
  match controller.motion:
   &"flight":
    clip = "Flight"
    var steer := ball.controls.steering
    if not is_zero_approx(steer): controller.flight_heading = Vector2(signf(steer), 0)
    frame = controller.player_facing_basis(camera, controller.flight_heading.x)
   &"spring":
    clip = "Ring Dash"
    frame = controller.spring_basis(camera, anchor, controller.motion_direction)
   &"dash_panel", &"loop":
    clip = "Boost Hover"
    if controller.motion == &"loop":
     var forward := -ball.track_frame.z if ball.track_speed >= 0.0 else ball.track_frame.z
     frame = Basis.looking_at(forward, ball.track_frame.y, true)
    else: frame = controller.Presenter.flat_roll_frame(controller.motion_direction)
    lift = frame.y * (HEIGHT * 0.5 - ball_radius * 0.6)
 if not animated: clip = BALL
 if action != clip: play(clip, true)
 if rig: rig.transform = Transform3D(frame, lift - frame.y * HEIGHT * 0.5)
 sample(elapsed + delta, pose_at)
