extends RefCounted
## Swept center crossings; independent from collision, rendering and checkpoint ownership.

static func crossings(document: Resource, from: Vector2, to: Vector2) -> Dictionary:
 var result := {"activation": false, "exit": false, "drain": false}
 if document == null or not from.is_finite() or not to.is_finite():
  return result
 var bounds: Rect2 = document.terrain_bounds()
 if document.activation_y != null:
  result.activation = _crosses_up(from, to, float(document.activation_y), 0.0, bounds.end.x)
 var exit: Dictionary = document.get_connector("exit")
 if exit.width > 0:
  result.exit = _crosses_up(from, to, 0.0, exit.start_x * float(document.cell_size), (exit.start_x + exit.width) * float(document.cell_size))
 # The full one-cell gutter is recovery space. Its bottom is the drain threshold.
 # Apply it across all X so an authored opening at either side can still drain.
 result.drain = to.y >= document.red_gutter_bounds().end.y
 return result

static func _crosses_up(from: Vector2, to: Vector2, y: float, left: float, right: float) -> bool:
 if from.y < y or to.y >= y or to.y >= from.y:
  return false
 var fraction := (y - from.y) / (to.y - from.y)
 var x := lerpf(from.x, to.x, fraction)
 return x >= left and x < right
