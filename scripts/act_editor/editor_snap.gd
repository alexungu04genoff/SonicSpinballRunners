extends RefCounted
## Relative snapping rounds movement; absolute snapping rounds the reference point.
enum Mode { FREE, RELATIVE, ABSOLUTE }
const LABELS := ["Free", "Relative Grid", "Absolute Grid"]

static func cell_center(point: Vector2, step: float) -> Vector2:
 return ((point / step).floor() + Vector2(0.5, 0.5)) * step

static func position(point: Vector2, origin: Variant, mode: int, step: float) -> Vector2:
 if mode == Mode.FREE: return point
 var grid := Vector2.ONE * step
 if mode == Mode.RELATIVE and origin is Vector2:
  return Vector2(origin) + (point - Vector2(origin)).snapped(grid)
 return point.snapped(grid)
