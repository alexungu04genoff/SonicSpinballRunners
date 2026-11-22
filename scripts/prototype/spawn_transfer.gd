extends Node
## Presentation-only checkpoint travel; the run owns the inert physics ball.
signal arrived
var game: Node
var proxy: Node3D
var start := Vector2.ZERO
var destination := Vector2.ZERO
var elapsed := 0.0
var drain := false
var upright_roll: MeshInstance3D
var trailing_tails: MeshInstance3D
var start_roll_angle := 0.0
const DURATION := 1.25

func begin(owner_game: Node, target: Vector2, drained: bool) -> void:
 game = owner_game
 start = game.ball.position
 destination = target
 drain = drained
 process_mode = Node.PROCESS_MODE_PAUSABLE
 proxy = game.character.spin_root.duplicate()
 game.presentation.add_child(proxy)
 if game.character.character_id in ["sonic", "tails"]:
  var heading: Vector2 = game.character.roll_heading
  if not drain and not start.is_equal_approx(destination): heading = start.direction_to(destination)
  proxy.basis = game.character.flat_roll_frame(heading)
  upright_roll = proxy.get_child(game.character.rolling_mesh.get_index())
  if game.character.character_id == "tails": trailing_tails = proxy.get_node_or_null("TrailingTails")
  start_roll_angle = game.character.roll_angle
 game.character.hide()
 _draw(0.0)

func _process(delta: float) -> void:
 elapsed = minf(elapsed + delta, DURATION)
 _draw(elapsed / DURATION)
 if elapsed >= DURATION:
  set_process(false)
  proxy.queue_free()
  proxy = null
  game.character.show()
  arrived.emit()
  queue_free()

func _draw(progress: float) -> void:
 var point := start
 var size := 1.0
 var lift := 0.0
 if drain:
  # Shrink completely before moving the inert body. Never sweep through geometry.
  if progress < 0.35: size = 1.0 - smoothstep(0.0, 0.35, progress)
  else:
   point = destination
   size = smoothstep(0.65, 1.0, progress)
 else:
  point = start.lerp(destination, smoothstep(0.0, 1.0, progress))
  lift = sin(progress * PI) * game.ball.radius * TablePresentation.SCALE * 3.0
 game.ball.position = point
 proxy.position = TablePresentation.map_point(point, game.presentation.ball_height() + lift)
 proxy.scale = Vector3.ONE * maxf(0.001, size)
 proxy.visible = size > 0.001
 if upright_roll:
  var angle := start_roll_angle + progress * TAU * float(game.character.roll_speed_scale)
  upright_roll.basis = Basis(Vector3.RIGHT, angle)
  if trailing_tails: preload("res://experiments/visual_lab/runners_sonic_assets.gd").sample_roll_tails(trailing_tails, angle)
 else:
  proxy.rotation.z = progress * TAU

func _exit_tree() -> void:
 if is_instance_valid(proxy): proxy.queue_free()
