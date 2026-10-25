extends RefCounted
## Shared authored-world proportions in construction cells, used by both the
## editor and runtime. Dimensions scale; saved centers, anchors and pivots do not.
const ROUND_RADIUS_CELLS := 0.25
const SLING_HEIGHT_CELLS := 0.60
const FLIPPER_LENGTH_CELLS := 0.65 # Pivot-to-tip centerline; caps give 0.75 overall.
const FLIPPER_RADIUS_CELLS := 0.05
const RING_RADIUS_CELLS := 0.09
## Preserves the existing 14-pixel ball at a 100-pixel cell; 50-pixel cells use 7.
const BALL_RADIUS_CELLS := 0.14

static func sling_points(cell_size: float) -> PackedVector2Array:
 # Scale the original 90-pixel-tall sling uniformly around its original anchor.
 var points := PackedVector2Array()
 var scale_factor := SLING_HEIGHT_CELLS * cell_size / 90.0
 for point: Vector2 in [Vector2(-40, 35), Vector2(-15, -55), Vector2(45, 35)]:
  points.append(point * scale_factor)
 return points
