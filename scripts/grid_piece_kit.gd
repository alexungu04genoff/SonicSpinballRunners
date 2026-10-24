class_name GridPieceKit
extends RefCounted
## Gameplay definitions only. Points and footprints use construction-grid units.
## Piece orientation is explicit in its name; rotations are not supported.
const CELL_SIZE := 50.0
const VERSION := 5

static func definition(name: String, span: int = 1) -> Dictionary:
 if name.begins_with("mounted_"):
  var paddle := definition(name.trim_prefix("mounted_"), span)
  if paddle.get("kind", "") != "flipper":
   return {}
  paddle.wall_mount = true
  return paddle
 var points := PackedVector2Array()
 match name:
  "open":
   return {"kind": "open", "footprint": Rect2(0, 0, 1, 1)}
  "rail_v": points = PackedVector2Array([Vector2.ZERO, Vector2(0, span)])
  "rail_h": points = PackedVector2Array([Vector2.ZERO, Vector2(span, 0)])
  "slope_right": points = PackedVector2Array([Vector2.ZERO, Vector2(span, span)])
  "slope_left": points = PackedVector2Array([Vector2.ZERO, Vector2(-span, span)])
  "slope_shallow_right": points = PackedVector2Array([Vector2.ZERO, Vector2(1, 2)])
  "slope_shallow_left": points = PackedVector2Array([Vector2.ZERO, Vector2(-1, 2)])
  "corner_right": points = PackedVector2Array([Vector2.ZERO, Vector2(span, 0), Vector2(span, span)])
  "corner_left": points = PackedVector2Array([Vector2.ZERO, Vector2(-span, 0), Vector2(-span, span)])
  "bank_right": points = PackedVector2Array([Vector2.ZERO, Vector2(1, 2), Vector2(0, 4)])
  "bank_left": points = PackedVector2Array([Vector2.ZERO, Vector2(-1, 2), Vector2(0, 4)])
  "curve_right": points = PackedVector2Array([Vector2.ZERO, Vector2(0.5, 1), Vector2(0.75, 2), Vector2(0.5, 3), Vector2(0, 4)])
  "curve_left": points = PackedVector2Array([Vector2.ZERO, Vector2(-0.5, 1), Vector2(-0.75, 2), Vector2(-0.5, 3), Vector2(0, 4)])
  "soft_bank_left", "soft_bank_right":
   var direction := -1.0 if name == "soft_bank_left" else 1.0
   # A rounded, shallow bulge meets the straight walls almost tangentially.
   # The sampled boundary drives both collision capsules and the rendered outline.
   for step in 17:
    var progress := step / 16.0
    points.append(Vector2(direction * 0.30 * (1.0 - cos(TAU * progress)), progress * 4.0))
  "wide_bank_left", "wide_bank_right":
   var direction := -1.0 if name == "wide_bank_left" else 1.0
   # An eight-row bank reaches an integer-cell apex, providing an explicit
   # mount anchor without introducing a corner in the rounded Easy boundary.
   for step in 17:
    var progress := step / 16.0
    points.append(Vector2(direction * 0.5 * (1.0 - cos(TAU * progress)), progress * 8.0))
  "bumper", "bumper_small", "bumper_large", "wall_bumper_left", "wall_bumper_right":
   var radius := 0.48 if name == "bumper_small" else (0.96 if name == "bumper_large" else 0.72)
   return {"kind": "circle", "radius": radius, "attachment": name.trim_prefix("wall_bumper_") if name.begins_with("wall_bumper_") else "", "footprint": Rect2(-radius, -radius, radius * 2.0, radius * 2.0)}
  "sling_left", "sling_right":
   var direction := 1.0 if name == "sling_left" else -1.0
   var vertices := PackedVector2Array([Vector2(0, -1), Vector2(direction * 1.4, 0), Vector2(0, 1)])
   return {"kind": "triangle", "points": vertices, "attachment": name.trim_prefix("sling_"), "footprint": Rect2(minf(0, direction * 1.4), -1, 1.4, 2)}
  "ring":
   return {"kind": "ring", "footprint": Rect2(-0.2, -0.2, 0.4, 0.4)}
  "flipper_left", "flipper_right", "side_flipper_left", "side_flipper_right", "short_flipper_left", "short_flipper_right":
   var side := 1.0 if name.ends_with("left") else -1.0
   var length := 2.5 if side > 0.0 else 2.3
   if name.begins_with("short_"):
    length = 1.6
   var offset := Vector2(-side * 0.5, 0) if name.begins_with("side_") else Vector2.ZERO
   var box := Rect2(-0.26, -length * sin(0.48) - 0.26, length + 0.52, length * (sin(0.48) + sin(0.32)) + 0.52)
   if side < 0.0:
    box.position.x = -length - 0.26
   box.position += offset
   return {"kind": "flipper", "side": side, "length": length, "offset": offset, "footprint": box}
  _: return {}
 if span < 1:
  return {}
 var footprint := Rect2(points[0], Vector2.ZERO)
 for point: Vector2 in points:
  footprint = footprint.expand(point)
 return {"kind": "rail", "points": points, "ports": PackedVector2Array([points[0], points[points.size() - 1]]), "footprint": footprint}
