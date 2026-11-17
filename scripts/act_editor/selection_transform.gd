extends RefCounted
## Shared geometric transforms for mixed editor selections. Work on a candidate
## document so validation can reject the entire edit without partial changes.
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const Decor = preload("res://scripts/act_editor/decor_slots.gd")
const EditorSelection = preload("res://scripts/act_editor/editor_selection.gd")

static func bounds(document: Resource, selection: Dictionary) -> Rect2:
 var points := PackedVector2Array()
 var cell := float(document.cell_size)
 for index: int in selection.get("terrain", []):
  var piece: Dictionary = document.placements[index]
  var start := Shapes.placement_position(piece) * cell
  points.append(start)
  points.append(start + Shapes.scaled_size(piece) * cell)
 for index: int in selection.get("gameplay", []):
  var item: Dictionary = document.gameplay_objects[index]
  points.append(item.position)
  for point: Vector2 in Objects.local_points(item, cell):
   points.append(Vector2(item.position) + point.rotated(deg_to_rad(float(item.rotation_degrees))))
  if item.type == "teleporter": points.append(Objects.teleporter_exit(item))
  if item.type == "buzz_bomber":
   var props := Objects.properties(item)
   var axis := Vector2.RIGHT.rotated(deg_to_rad(float(item.rotation_degrees)))
   points.append(Vector2(item.position) + axis * float(props.patrol_left))
   points.append(Vector2(item.position) + axis * float(props.patrol_right))
 for index: int in selection.get("decor", []):
  var slot: Dictionary = document.decor_slots[index]
  var radius: Vector2 = Vector2.ONE * Decor.RADII[Decor.TYPES.find(slot.slot_type)] * cell * float(slot.get("scale", 1.0))
  points.append(slot.position - radius)
  points.append(slot.position + radius)
 for index: int in selection.get("ring", []): points.append_array(Rings.positions(document.ring_trails[index]))
 for kind: String in selection.get("markers", []):
  if kind == "spawn" and document.spawn_position != null: points.append(document.spawn_position)
  elif kind == "goal":
   var radius := Vector2.ONE * float(document.goal_diameter_cells) * cell * 0.5
   points.append(document.goal_center() - radius)
   points.append(document.goal_center() + radius)
  elif kind == "activation" and document.activation_y != null:
   points.append(Vector2(0, float(document.activation_y)))
   points.append(Vector2(float(document.grid_size.x) * cell, float(document.activation_y)))
 if points.is_empty(): return Rect2()
 var result := Rect2(points[0], Vector2.ZERO)
 for point: Vector2 in points: result = result.expand(point)
 return result

static func apply(document: Resource, selection: Dictionary, pivot: Vector2, factor: float, degrees: float) -> void:
 var angle := deg_to_rad(degrees)
 var transform_point := func(point: Vector2) -> Vector2: return pivot + ((point - pivot) * factor).rotated(angle)
 var cell := float(document.cell_size)
 # Resolve implicit Goal before moving Spawn, which otherwise moves it twice.
 var goal: Vector2 = document.goal_center()
 for index: int in selection.get("terrain", []):
  var piece: Dictionary = document.placements[index]
  var center := (Shapes.placement_position(piece) + Shapes.scaled_size(piece) * 0.5) * cell
  piece["terrain_scale"] = float(piece.get("terrain_scale", 1.0)) * factor
  piece["fine_rotation_degrees"] = float(piece.get("fine_rotation_degrees", 0.0)) + degrees
  Shapes.set_placement_position(piece, transform_point.call(center) / cell - Shapes.scaled_size(piece) * 0.5)
 for index: int in selection.get("gameplay", []):
  var item: Dictionary = document.gameplay_objects[index]
  item.position = transform_point.call(item.position)
  item.rotation_degrees += degrees
  if not is_equal_approx(factor, 1.0): item["properties"] = Objects.scaled_properties(item, factor)
 for index: int in selection.get("decor", []):
  var slot: Dictionary = document.decor_slots[index]
  slot.position = transform_point.call(slot.position)
  slot.rotation_degrees += degrees
  slot["scale"] = float(slot.get("scale", 1.0)) * factor
  slot.erase("placement_source")
 for index: int in selection.get("ring", []):
  var trail: Dictionary = document.ring_trails[index]
  if trail.get("kind") == "ellipse":
   var center: Vector2 = transform_point.call((trail.start + trail.end) * 0.5)
   var extent: Vector2 = (trail.end - trail.start) * 0.5 * factor
   trail.start = center - extent
   trail.end = center + extent
   trail.rotation_degrees += degrees
  else:
   trail.start = transform_point.call(trail.start)
   trail.end = transform_point.call(trail.end)
  trail.spacing *= factor
 for kind: String in selection.get("markers", []):
  if kind == "spawn" and document.spawn_position != null: document.spawn_position = transform_point.call(document.spawn_position)
  elif kind == "goal":
   document.goal_position = transform_point.call(goal)
   document.goal_diameter_cells *= factor
  elif kind == "activation" and document.activation_y != null:
   # Checkpoint lines remain horizontal; they are metadata, not terrain.
   document.activation_y = pivot.y + (float(document.activation_y) - pivot.y) * factor

static func translate(document: Resource, selection: Dictionary, offset: Vector2) -> void:
 var goal: Vector2 = document.goal_center()
 for index: int in selection.get("terrain", []):
  var piece: Dictionary = document.placements[index]
  Shapes.set_placement_position(piece, Shapes.placement_position(piece) + offset / float(document.cell_size))
 for index: int in selection.get("gameplay", []): document.gameplay_objects[index].position += offset
 for index: int in selection.get("decor", []):
  document.decor_slots[index].position += offset
  document.decor_slots[index].erase("placement_source")
 for index: int in selection.get("ring", []):
  document.ring_trails[index].start += offset
  document.ring_trails[index].end += offset
 for kind: String in selection.get("markers", []):
  if kind == "spawn": document.spawn_position += offset
  elif kind == "goal": document.goal_position = goal + offset
  elif kind == "activation": document.activation_y += offset.y

static func arrange(document: Resource, selection: Dictionary, operation: String) -> String:
 if not selection.get("markers", []).is_empty(): return "Align objects and groups without lifecycle markers selected."
 var units := EditorSelection.units(document, selection)
 var distribute := operation.begins_with("distribute")
 if units.size() < (3 if distribute else 2): return "Select at least %d independent objects or groups." % (3 if distribute else 2)
 var axis := 1 if operation in ["top", "middle", "bottom", "distribute_y"] else 0
 var frames: Array[Rect2] = []
 for unit: Dictionary in units: frames.append(bounds(document, unit))
 if distribute:
  var ordered: Array[int] = []
  for index in units.size(): ordered.append(index)
  ordered.sort_custom(func(a, b): return frames[a].get_center()[axis] < frames[b].get_center()[axis])
  var first: float = frames[ordered.front()].get_center()[axis]
  var last: float = frames[ordered.back()].get_center()[axis]
  for slot in range(1, ordered.size() - 1):
   var index := ordered[slot]
   var offset := Vector2.ZERO
   offset[axis] = lerpf(first, last, float(slot) / (ordered.size() - 1)) - frames[index].get_center()[axis]
   translate(document, units[index], offset)
 else:
  var all := bounds(document, selection)
  var target: float = all.get_center()[axis]
  if operation in ["left", "top"]: target = all.position[axis]
  elif operation in ["right", "bottom"]: target = all.end[axis]
  for index in units.size():
   var current: float = frames[index].get_center()[axis]
   if operation in ["left", "top"]: current = frames[index].position[axis]
   elif operation in ["right", "bottom"]: current = frames[index].end[axis]
   var offset := Vector2.ZERO
   offset[axis] = target - current
   translate(document, units[index], offset)
 return ""
