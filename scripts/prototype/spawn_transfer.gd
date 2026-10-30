extends Node
## Presentation-only checkpoint travel; the run owns the inert physics ball.
signal arrived
var game: Node
var proxy: Node3D
var start := Vector2.ZERO
var destination := Vector2.ZERO
var elapsed := 0.0
var drain := false
const DURATION := 1.25

func begin(owner_game: Node, target: Vector2, drained: bool) -> void:
 game = owner_game
 start = game.ball.position
 destination = target
 drain = drained
 process_mode = Node.PROCESS_MODE_PAUSABLE
 proxy = game.character.spin_root.duplicate()
 game.presentation.add_child(proxy)
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
 proxy.rotation.z = progress * TAU

func _exit_tree() -> void:
 if is_instance_valid(proxy): proxy.queue_free()
