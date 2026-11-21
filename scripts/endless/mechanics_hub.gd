extends Node
## One adapter for the shared ball; each Act keeps independent switches and rails.
var runtimes: Array[Node] = []
var rail_owner: Node

func cancel_loop(runtime: Node, safe_spawn: Vector2) -> void:
 if rail_owner == runtime and runtime.ramp.get("type") == "sonic_loop":
  runtime.leave_ramp()
  rail_owner = null
  runtime.ball.teleport_to(safe_spawn, Vector2.ZERO, true)

func reset() -> void:
 for runtime: Node in runtimes: runtime.reset()
 rail_owner = null

func reset_for_retry() -> void:
 for runtime: Node in runtimes:
  if runtime.scoring_active: runtime.reset_for_retry()
 if is_instance_valid(rail_owner) and not rail_owner.scoring_active:
  rail_owner.leave_ramp()
 rail_owner = null

func tick(delta: float) -> void:
 for runtime: Node in runtimes: runtime.tick(delta)

func reset_motion() -> void:
 for runtime: Node in runtimes: runtime.reset_motion()

func apply_fields(state: PhysicsDirectBodyState2D) -> void:
 for runtime: Node in runtimes: runtime.apply_fields(state)

func observe_motion(state: PhysicsDirectBodyState2D) -> bool:
 # Every resident Act samples actual travel even when another Act redirects it.
 for runtime: Node in runtimes: runtime.observe_actual_motion(state)
 for runtime: Node in runtimes:
  if runtime.observe_motion(state, false):
   if not runtime.ramp.is_empty():
    rail_owner = runtime
    reset_motion()
   return true
 return false

func advance_ramp(state: PhysicsDirectBodyState2D, delta: float) -> void:
 var owner := rail_owner
 if not is_instance_valid(owner): return
 owner.advance_ramp(state, delta)
 # A blocked return can reset the Ball (and clear this owner) inside advance.
 if rail_owner == owner and owner.ramp.is_empty():
  rail_owner = null
  reset_motion()
