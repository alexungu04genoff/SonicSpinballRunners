extends Node
## One adapter for the shared ball; each Act keeps independent switches and rails.
var runtimes: Array[Node] = []
var rail_owner: Node

func reset() -> void:
 for runtime: Node in runtimes: runtime.reset()
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
 if is_instance_valid(rail_owner):
  rail_owner.advance_ramp(state, delta)
  if rail_owner.ramp.is_empty():
   rail_owner = null
   reset_motion()
