extends RefCounted
## A short shell-only pulse at the boundary between rolling and an action.
const RISE := 0.025
const DURATION := 0.10
var elapsed := DURATION
var from_opacity := 0.0

func start(current: float) -> void:
 from_opacity = current
 elapsed = 0.0

func advance(delta: float) -> void:
 elapsed = minf(DURATION, elapsed + delta)

func opacity(rest: float, strength: float) -> float:
 if elapsed >= DURATION or strength <= 0.0: return rest
 var peak := minf(1.0, strength * 1.5)
 if elapsed < RISE: return lerpf(from_opacity, peak, smoothstep(0.0, RISE, elapsed))
 return lerpf(peak, rest, smoothstep(RISE, DURATION, elapsed))
