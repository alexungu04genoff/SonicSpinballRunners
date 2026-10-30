class_name ActGeometry
extends Resource
## A single Act's terrain, connectors, gameplay objects and lifecycle authoring data.
const FORMAT_VERSION := 17
const MAX_SCORE_TARGET := 100000000
## The system gutter is outside terrain bounds and is never a thirteenth terrain row.
const RED_GUTTER_CELLS := 1
const SHAPES = preload("res://scripts/act_editor/terrain_shapes.gd")
const OBJECTS = preload("res://scripts/act_editor/gameplay_objects.gd")
const RINGS = preload("res://scripts/act_editor/ring_trails.gd")
const BANKS = preload("res://scripts/act_editor/switch_banks.gd")
const COMPOSITES = preload("res://scripts/act_editor/composite_terrain.gd")
const DECOR = preload("res://scripts/act_editor/decor_slots.gd")
const SCRIPT_PATH := "res://scripts/act_editor/act_geometry.gd"
const PLACEMENT_TYPES := {
 "shape_id": TYPE_STRING,
 "base_size": TYPE_VECTOR2I,
 "anchor": TYPE_VECTOR2I,
 "quarter_turns": TYPE_INT,
 "flip_h": TYPE_BOOL,
 "flip_v": TYPE_BOOL,
}
const COMPOSITE_FIELDS := ["composite_version", "outline", "smoothing_strength"]
const OPTIONAL_TRANSFORM_FIELDS := ["offset", "terrain_scale", "fine_rotation_degrees"]

# Dynamic exports preserve malformed input for validation. Typed Resource fields
# otherwise coerce bool/float versions to integers and invalid arrays to empty ones.
@export var format_version = 0:
 set(value):
  format_version = value
  _format_version_was_set = true
@export var library_version = 0:
 set(value):
  library_version = value
  _library_version_was_set = true
@export var title = "Untitled Act"
@export var grid_size = Vector2i(12, 12)
@export var cell_size = 50.0
@export var placements = []
## Gameplay centers/pivots use exact local pixel coordinates, independently of terrain.
@export var gameplay_objects = []
@export var switch_banks = []
## One record per gesture; generated positions never snap to the terrain grid.
@export var ring_trails = []
## Stable identity survives Save As; populated when the first decoration is authored.
@export var decor_seed = ""
@export var decor_slots = []
## Entry lies on the bottom boundary; exit lies on the top boundary.
## A zero start and width represent an unset connector in an editable draft.
@export var entry_start_x = 0
@export var entry_width = 0
@export var exit_start_x = 0
@export var exit_width = 0
## Zero keeps traversal ungated. Positive values require points earned in this Act.
@export var score_target = 0
## Independent optional guides; entry itself does not activate the checkpoint.
@export_storage var activation_y = null
@export_storage var spawn_position = null
## Required goal object; legacy Acts inherit the validated spawn as its safe default.
@export var goal_position = null
@export var goal_diameter_cells = 1.0

func goal_center() -> Vector2:
 if goal_position is Vector2: return goal_position
 if spawn_position is Vector2: return spawn_position
 return terrain_bounds().get_center()

var _format_version_was_set := false
var _library_version_was_set := false

func _init() -> void:
 # Declared zero defaults force ResourceSaver to write both current versions.
 # Missing fields on load must not inherit constructor defaults invisibly.
 format_version = FORMAT_VERSION
 library_version = SHAPES.VERSION
 _format_version_was_set = false
 _library_version_was_set = false

func get_connector(kind: String) -> Dictionary:
 match kind:
  "entry": return {"start_x": entry_start_x, "width": entry_width}
  "exit": return {"start_x": exit_start_x, "width": exit_width}
 return {}

static func compatible(previous_exit: Dictionary, next_entry: Dictionary) -> bool:
 # Local X is deliberately irrelevant; future assembly will align whole Acts.
 var previous_width: Variant = previous_exit.get("width")
 var next_width: Variant = next_entry.get("width")
 return typeof(previous_width) == TYPE_INT and typeof(next_width) == TYPE_INT and previous_width > 0 and previous_width == next_width

func terrain_bounds() -> Rect2:
 return Rect2(Vector2.ZERO, Vector2(grid_size) * float(cell_size))

func red_gutter_bounds() -> Rect2:
 var terrain := terrain_bounds()
 return Rect2(Vector2(0, terrain.end.y), Vector2(terrain.size.x, float(cell_size) * RED_GUTTER_CELLS))

func validation_errors() -> PackedStringArray:
 var errors := PackedStringArray()
 if goal_position != null and (not goal_position is Vector2 or not goal_position.is_finite()):
  errors.append("Goal position must be a finite Vector2 or the default spawn position.")
 if typeof(goal_diameter_cells) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(goal_diameter_cells)) or float(goal_diameter_cells) < 0.25 or float(goal_diameter_cells) > 8.0:
  errors.append("Goal diameter must be between 0.25 and 8 cells.")
 if typeof(format_version) != TYPE_INT:
  errors.append("Act format version must be an integer.")
 elif format_version != FORMAT_VERSION:
  errors.append("Unsupported Act format version %d; expected %d." % [format_version, FORMAT_VERSION])
 if typeof(library_version) != TYPE_INT:
  errors.append("Terrain library version must be an integer.")
 elif library_version != SHAPES.VERSION:
  errors.append("Unsupported terrain library version %d; expected %d." % [library_version, SHAPES.VERSION])
 if typeof(title) != TYPE_STRING:
  errors.append("Act title must be a string.")
 if typeof(score_target) != TYPE_INT or score_target < 0 or score_target > MAX_SCORE_TARGET:
  errors.append("Score target must be an integer between 0 (disabled) and %d." % MAX_SCORE_TARGET)
 var valid_grid_type := typeof(grid_size) == TYPE_VECTOR2I
 if not valid_grid_type:
  errors.append("Act grid dimensions must use integer grid coordinates (Vector2i).")
 elif grid_size.x < 1 or grid_size.y < 1:
  errors.append("Act grid dimensions must both be positive integers.")
 if typeof(cell_size) not in [TYPE_FLOAT, TYPE_INT]:
  errors.append("Grid cell size must be a number.")
 elif not is_finite(cell_size) or cell_size <= 0.0:
  errors.append("Grid cell size must be finite and greater than zero.")
 for kind: String in ["entry", "exit"]:
  var connector := get_connector(kind)
  if typeof(connector.start_x) != TYPE_INT or typeof(connector.width) != TYPE_INT:
   errors.append("%s connector start and width must both be integers." % kind.capitalize())
   continue
  if connector.width == 0:
   if connector.start_x != 0:
    errors.append("%s connector must use start 0 when its width is 0 (unset)." % kind.capitalize())
  elif connector.width < 0 or connector.start_x < 0:
   errors.append("%s connector needs a positive width and nonnegative start." % kind.capitalize())
  elif valid_grid_type and (connector.width > grid_size.x or connector.start_x > grid_size.x - connector.width):
   errors.append("%s connector span must fit inside the Act's horizontal grid boundary." % kind.capitalize())
 errors.append_array(_gameplay_validation_errors())
 errors.append_array(BANKS.validation_errors(switch_banks, gameplay_objects))
 errors.append_array(_ring_validation_errors())
 errors.append_array(_decor_validation_errors())
 errors.append_array(_lifecycle_validation_errors())
 if goal_position is Vector2 and valid_grid_type and typeof(cell_size) in [TYPE_FLOAT, TYPE_INT] and cell_size > 0.0 and not terrain_bounds().has_point(goal_position):
  errors.append("Goal center must stay inside the Act bounds.")
 if typeof(placements) != TYPE_ARRAY:
  errors.append("Terrain placements must be an array of dictionaries.")
  return errors
 for index in placements.size():
  var prefix := "Placement %d: " % (index + 1)
  if typeof(placements[index]) != TYPE_DICTIONARY:
   errors.append(prefix + "terrain placement must be a dictionary.")
   continue
  var placement: Dictionary = placements[index]
  var composite: bool = placement.get("shape_id") == "composite"
  var valid_types := true
  for key: String in PLACEMENT_TYPES:
   if not placement.has(key) or typeof(placement[key]) != PLACEMENT_TYPES[key]:
    errors.append(prefix + "%s must be %s." % [key, type_string(PLACEMENT_TYPES[key])])
    valid_types = false
  for key: Variant in placement:
   if typeof(key) != TYPE_STRING or (not PLACEMENT_TYPES.has(key) and key not in OPTIONAL_TRANSFORM_FIELDS and (not composite or key not in COMPOSITE_FIELDS)):
    errors.append(prefix + "unrecognized placement field; only terrain reference and transform fields are supported.")
  if not valid_types:
   continue
  if placement.has("offset"):
   if typeof(placement.offset) != TYPE_VECTOR2:
    errors.append(prefix + "offset must be a fractional-cell Vector2.")
    continue
   if not placement.offset.is_finite() or placement.offset.x < 0.0 or placement.offset.y < 0.0 or placement.offset.x >= 1.0 or placement.offset.y >= 1.0:
    errors.append(prefix + "offset must be finite and between 0 (inclusive) and 1 (exclusive).")
    continue
  if placement.has("terrain_scale"):
   if typeof(placement.terrain_scale) not in [TYPE_INT, TYPE_FLOAT] or placement.terrain_scale not in [0.5, 1.0]:
    errors.append(prefix + "terrain_scale must be 0.5 or 1.0.")
    continue
  if placement.has("fine_rotation_degrees"):
   if typeof(placement.fine_rotation_degrees) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(placement.fine_rotation_degrees):
    errors.append(prefix + "fine_rotation_degrees must be a finite angle.")
    continue
  if composite:
   var composite_errors := _composite_validation_errors(placement)
   for error: String in composite_errors: errors.append(prefix + error)
   if not composite_errors.is_empty(): continue
  var definition: Dictionary = SHAPES.definition_for_placement(placement)
  if definition.is_empty():
   errors.append(prefix + "unknown terrain shape '%s'." % placement.shape_id)
   continue
  if placement.base_size != definition.size:
   errors.append(prefix + "base footprint does not match its shape definition.")
  if placement.quarter_turns < 0 or placement.quarter_turns > 3:
   errors.append(prefix + "rotation must be 0, 1, 2 or 3 quarter-turns.")
  var frame := SHAPES.scaled_size(placement)
  var anchor := SHAPES.placement_position(placement)
  # Frame bounds are the only spatial restriction. Overlap is deliberately valid.
  if valid_grid_type and (anchor.x < 0 or anchor.y < 0 or anchor.x > grid_size.x - frame.x or anchor.y > grid_size.y - frame.y):
   errors.append(prefix + "the transformed footprint must fit inside this Act.")
 return errors

func _composite_validation_errors(placement: Dictionary) -> PackedStringArray:
 var errors := PackedStringArray()
 if typeof(placement.get("composite_version")) != TYPE_INT or placement.get("composite_version") != COMPOSITES.VERSION:
  errors.append("composite_version must be the supported integer version %d." % COMPOSITES.VERSION)
 if typeof(placement.get("smoothing_strength")) not in [TYPE_INT, TYPE_FLOAT]:
  errors.append("smoothing_strength must be a number between 0 and 5 (0%–500%).")
 elif not is_finite(placement.smoothing_strength) or placement.smoothing_strength < 0.0 or placement.smoothing_strength > COMPOSITES.MAX_STRENGTH:
  errors.append("smoothing_strength must be finite and between 0 and 5 (0%–500%).")
 if placement.base_size.x <= 0 or placement.base_size.y <= 0 or placement.base_size.x > COMPOSITES.MAX_COORDINATE or placement.base_size.y > COMPOSITES.MAX_COORDINATE:
  errors.append("composite base footprint must be positive and within the supported terrain extent.")
 if typeof(placement.get("outline")) != TYPE_PACKED_VECTOR2_ARRAY:
  errors.append("composite outline must be a PackedVector2Array in local cell coordinates.")
 else:
  var outline: PackedVector2Array = placement.outline
  var geometry_error: String = COMPOSITES.validation_error(outline)
  if not geometry_error.is_empty(): errors.append(geometry_error)
  for point: Vector2 in outline:
   if point.x < 0.0 or point.y < 0.0 or point.x > placement.base_size.x or point.y > placement.base_size.y:
    errors.append("composite outline must stay inside its local base footprint.")
    break
 return errors

func _lifecycle_validation_errors() -> PackedStringArray:
 var errors := PackedStringArray()
 var valid_bounds: bool = typeof(grid_size) == TYPE_VECTOR2I and grid_size.x > 0 and grid_size.y > 0 and typeof(cell_size) in [TYPE_INT, TYPE_FLOAT] and is_finite(cell_size) and cell_size > 0
 var bounds := terrain_bounds() if valid_bounds else Rect2()
 if valid_bounds and not bounds.size.is_finite():
  valid_bounds = false
  if activation_y != null or spawn_position != null:
   errors.append("Act terrain bounds must be finite to place lifecycle markers.")
 if activation_y != null:
  if typeof(activation_y) not in [TYPE_FLOAT, TYPE_INT]:
   errors.append("Activation trigger Y must be a number or unset.")
  elif not is_finite(activation_y):
   errors.append("Activation trigger Y must be finite.")
  elif valid_bounds and (activation_y < 0 or activation_y >= bounds.end.y):
   errors.append("Activation trigger must be inside the terrain: 0 <= Y < %s. The bottom boundary and red gutter are outside." % bounds.end.y)
 if spawn_position != null:
  if typeof(spawn_position) != TYPE_VECTOR2:
   errors.append("Spawn position must be a local pixel Vector2 or unset.")
  elif not spawn_position.is_finite():
   errors.append("Spawn position must contain finite local coordinates.")
  elif valid_bounds and not bounds.has_point(spawn_position):
   errors.append("Spawn position must be inside the terrain. Right/bottom boundaries and the red gutter are outside.")
 # Bounds are half-open, matching Rect2.has_point. Never repair authored positions.
 return errors

func _gameplay_validation_errors() -> PackedStringArray:
 var errors := PackedStringArray()
 if typeof(gameplay_objects) != TYPE_ARRAY:
  errors.append("Gameplay objects must be an array of dictionaries.")
  return errors
 var ids: Dictionary = {}
 for index in gameplay_objects.size():
  var prefix := "Gameplay object %d: " % (index + 1)
  if typeof(gameplay_objects[index]) != TYPE_DICTIONARY:
   errors.append(prefix + "placement must be a dictionary.")
   continue
  var placement: Dictionary = gameplay_objects[index]
  if typeof(placement.get("type")) != TYPE_STRING:
   errors.append(prefix + "type must be a string.")
  elif OBJECTS.get_definition(placement.type).is_empty():
   errors.append(prefix + "unknown gameplay object type '%s'." % placement.type)
  if typeof(placement.get("position")) != TYPE_VECTOR2:
   errors.append(prefix + "position must be a local pixel Vector2.")
  elif not placement.position.is_finite():
   errors.append(prefix + "position must contain finite local coordinates.")
  if typeof(placement.get("rotation_degrees")) not in [TYPE_FLOAT, TYPE_INT]:
   errors.append(prefix + "rotation_degrees must be a number.")
  elif not is_finite(placement.rotation_degrees):
   errors.append(prefix + "rotation_degrees must be finite.")
  for error: String in OBJECTS.property_errors(placement): errors.append(prefix + error)
  if typeof(placement.get("object_id")) == TYPE_STRING:
   if ids.has(placement.object_id): errors.append(prefix + "duplicate object_id.")
   ids[placement.object_id] = true
  for key: Variant in placement:
   if typeof(key) != TYPE_STRING or key not in ["type", "position", "rotation_degrees", "object_id", "properties"]:
    errors.append(prefix + "unrecognized object field.")
 # Gameplay data has no grid bounds, occupancy rules, angle normalization or snapping.
 return errors

func _ring_validation_errors() -> PackedStringArray:
 var errors := PackedStringArray()
 if typeof(ring_trails) != TYPE_ARRAY:
  errors.append("Ring trails must be an array.")
  return errors
 var ids := {}
 for index in ring_trails.size():
  var error: String = RINGS.validation_error(ring_trails[index])
  if not error.is_empty():
   errors.append("Ring trail %d: %s" % [index + 1, error])
   continue
  var id := RINGS.pattern_id(ring_trails[index], index)
  if ids.has(id): errors.append("Ring pattern IDs must be unique within an Act.")
  ids[id] = true
 return errors

func _decor_validation_errors() -> PackedStringArray:
 var errors := PackedStringArray()
 if typeof(decor_seed) != TYPE_STRING:
  errors.append("Decor seed must be a string.")
 if typeof(decor_slots) != TYPE_ARRAY:
  errors.append("Decor slots must be an array.")
  return errors
 var ids: Dictionary = {}
 for index in decor_slots.size():
  var error: String = DECOR.validation_error(decor_slots[index])
  if not error.is_empty():
   errors.append("Decor slot %d: %s" % [index + 1, error])
  else:
   var id: String = decor_slots[index].slot_id
   if ids.has(id): errors.append("Decor slot %d: duplicate slot_id." % (index + 1))
   ids[id] = true
 return errors

func decor_identity() -> String:
 return decor_seed if not decor_seed.is_empty() else resource_path.replace("\\", "/")

func fingerprint() -> String:
 # Arrays make field order explicit, independent of Dictionary insertion order.
 var ordered_placements: Array = []
 if typeof(placements) == TYPE_ARRAY:
  for placement: Variant in placements:
   if typeof(placement) == TYPE_DICTIONARY:
    ordered_placements.append([
     placement.get("shape_id"), placement.get("base_size"), placement.get("anchor"),
     placement.get("quarter_turns"), placement.get("flip_h"), placement.get("flip_v"),
    ])
    if placement.has("offset") or placement.has("terrain_scale"):
     ordered_placements.back().append_array([placement.get("offset", Vector2.ZERO), placement.get("terrain_scale", 1.0)])
    if placement.has("fine_rotation_degrees"):
     ordered_placements.back().append(placement.fine_rotation_degrees)
    if placement.get("shape_id") == "composite":
     var strength: Variant = placement.get("smoothing_strength")
     if typeof(strength) in [TYPE_INT, TYPE_FLOAT]: strength = float(strength)
     ordered_placements.back().append_array([placement.get("composite_version"), placement.get("outline"), strength])
   else:
    ordered_placements.append(placement)
 else:
  ordered_placements.append(placements)
 var ordered_objects: Array = []
 if typeof(gameplay_objects) == TYPE_ARRAY:
  for placement: Variant in gameplay_objects:
   if typeof(placement) == TYPE_DICTIONARY:
    var angle: Variant = placement.get("rotation_degrees")
    if typeof(angle) in [TYPE_FLOAT, TYPE_INT]:
     angle = float(angle)
    ordered_objects.append([placement.get("type"), placement.get("position"), angle])
    ordered_objects.back().append(OBJECTS.identity(placement, ordered_objects.size() - 1))
    var props: Variant = placement.get("properties", {})
    var ordered: Array = []
    if props is Dictionary:
     var keys: Array = props.keys()
     keys.sort()
     for key: Variant in keys:
      var value: Variant = props[key]
      ordered.append([key, float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else value])
    else: ordered.append(props)
    ordered_objects.back().append(ordered)
   else:
    ordered_objects.append(placement)
 else:
  ordered_objects.append(gameplay_objects)
 # ResourceSaver can omit an integer cell size equal to the default float size.
 # Treat equivalent numeric cell sizes identically while preserving their value.
 var normalized_cell_size: Variant = float(cell_size) if typeof(cell_size) in [TYPE_INT, TYPE_FLOAT] else cell_size
 var normalized_activation: Variant = float(activation_y) if typeof(activation_y) in [TYPE_INT, TYPE_FLOAT] else activation_y
 var ordered_trails: Array = []
 if typeof(ring_trails) == TYPE_ARRAY:
  for trail: Variant in ring_trails:
   if trail is Dictionary:
    var spacing: Variant = trail.get("spacing")
    if typeof(spacing) in [TYPE_INT, TYPE_FLOAT]: spacing = float(spacing)
    ordered_trails.append([trail.get("start"), trail.get("end"), spacing])
    if trail.has("kind"):
     ordered_trails.back().append_array([trail.kind, trail.get("fill"), float(trail.get("rotation_degrees", 0.0))])
    ordered_trails.back().append(["pattern_id", RINGS.pattern_id(trail, ordered_trails.size() - 1)])
    for key: String in ["bonus_rack", "completion_bonus", "timeout", "respawn_delay"]:
     if trail.has(key):
      var value: Variant = trail[key]
      ordered_trails.back().append([key, float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else value])
   else:
    ordered_trails.append(trail)
 else:
  ordered_trails.append(ring_trails)
 # Hash native scalar bits: decimal formatting can collapse adjacent float values.
 return var_to_bytes([format_version, library_version, title, grid_size, normalized_cell_size, ordered_placements, entry_start_x, entry_width, exit_start_x, exit_width, ordered_objects, normalized_activation, spawn_position, ordered_trails, decor_seed, DECOR.fingerprint_records(decor_slots), BANKS.fingerprint_records(switch_banks), score_target, goal_position, float(goal_diameter_cells)]).hex_encode().sha256_text()

func copy_document() -> Resource:
 var result: Resource = get_script().new()
 result.format_version = format_version
 result.library_version = library_version
 result.title = title
 result.grid_size = grid_size
 result.cell_size = cell_size
 result.placements = placements.duplicate(true) if typeof(placements) == TYPE_ARRAY else placements
 result.gameplay_objects = gameplay_objects.duplicate(true) if typeof(gameplay_objects) == TYPE_ARRAY else gameplay_objects
 result.switch_banks = switch_banks.duplicate(true) if typeof(switch_banks) == TYPE_ARRAY else switch_banks
 result.ring_trails = ring_trails.duplicate(true) if typeof(ring_trails) == TYPE_ARRAY else ring_trails
 result.decor_seed = decor_seed
 result.decor_slots = decor_slots.duplicate(true) if typeof(decor_slots) == TYPE_ARRAY else decor_slots
 result.entry_start_x = entry_start_x
 result.entry_width = entry_width
 result.exit_start_x = exit_start_x
 result.exit_width = exit_width
 result.score_target = score_target
 result.activation_y = activation_y
 result.spawn_position = spawn_position
 result.goal_position = goal_position
 result.goal_diameter_cells = goal_diameter_cells
 return result

static func load_document(path: String) -> Dictionary:
 if path.get_extension().to_lower() != "tres":
  return {"document": null, "error": "Choose an Act Geometry .tres file."}
 if not FileAccess.file_exists(path):
  return {"document": null, "error": "The selected Act file does not exist."}
 # Never return the ResourceLoader cache: loading must reflect the saved file.
 var loaded := ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
 if loaded == null or loaded.get_script() != load(SCRIPT_PATH):
  return {"document": null, "error": "The selected file is not an Act Geometry resource."}
 if not loaded._format_version_was_set or not loaded._library_version_was_set:
  return {"document": null, "error": "This Act file is missing its required format or terrain library version."}
 if typeof(loaded.format_version) == TYPE_INT and loaded.format_version < 16 and (loaded.goal_position != null or loaded.goal_diameter_cells != 1.0):
  return {"document": null, "error": "Authored goal settings require Act format 16."}
 var source_version: Variant = loaded.format_version
 if typeof(loaded.format_version) == TYPE_INT and loaded.format_version in [15, 16]: loaded.format_version = FORMAT_VERSION
 if typeof(loaded.format_version) == TYPE_INT and loaded.format_version in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14] and typeof(loaded.library_version) == TYPE_INT and loaded.library_version == SHAPES.VERSION:
  if typeof(loaded.score_target) != TYPE_INT or loaded.score_target != 0:
   return {"document": null, "error": "Act score targets require Act format 15."}
  if typeof(loaded.switch_banks) != TYPE_ARRAY or (loaded.format_version < 13 and not loaded.switch_banks.is_empty()):
   return {"document": null, "error": "Switch banks require Act format 13."}
  for bank: Variant in loaded.switch_banks:
   if loaded.format_version < 14 and bank is Dictionary and (bank.has("actions") or bank.has("completion_bonus") or bank.has("reset_delay")):
    return {"document": null, "error": "Bank actions and feature bonuses require Act format 14."}
  if typeof(loaded.gameplay_objects) == TYPE_ARRAY:
   for item: Variant in loaded.gameplay_objects:
    if item is Dictionary and item.get("type") == "spinner" and item.get("properties", {}) is Dictionary:
     for key: String in ["completion_enabled", "target_ticks", "completion_bonus"]:
      if item.get("properties", {}).has(key): return {"document": null, "error": "Spinner goals require Act format 15."}
    if loaded.format_version < 14 and item is Dictionary and item.get("type") in ["lane_barrier", "wall_switch", "diverter", "dash_panel"]:
     return {"document": null, "error": "Lane barriers, wall switches, diverters and dash panels require Act format 14."}
    if loaded.format_version < 13 and item is Dictionary and item.get("type") in ["one_way_gate", "switch_target", "spring"]:
     return {"document": null, "error": "Gates, switches and springs require Act format 13."}
  if typeof(loaded.ring_trails) == TYPE_ARRAY:
   for trail: Variant in loaded.ring_trails:
    if loaded.format_version < 13 and trail is Dictionary and trail.has("kind"): return {"document": null, "error": "Ring ellipses require Act format 13."}
    if trail is Dictionary:
     for key: String in RINGS.SCORING_KEYS:
      if trail.has(key): return {"document": null, "error": "Ring rack settings require Act format 15."}
  if loaded.format_version < 12 and typeof(loaded.decor_slots) == TYPE_ARRAY:
   for slot: Variant in loaded.decor_slots:
    if slot is Dictionary and slot.has("placement_source"):
     return {"document": null, "error": "Scattered decor ownership requires Act format 12."}
  if loaded.format_version < 10 and typeof(loaded.decor_slots) == TYPE_ARRAY:
   for slot: Variant in loaded.decor_slots:
    if slot is Dictionary and (slot.get("variant_mode", "auto") != "auto" or slot.has("variant_index")):
     return {"document": null, "error": "Fixed decor variants require Act format 10."}
  if loaded.format_version < 7 and (typeof(loaded.decor_slots) != TYPE_ARRAY or not loaded.decor_slots.is_empty() or loaded.decor_seed != ""):
   return {"document": null, "error": "Previous Act formats cannot contain decor slots or a decor seed."}
  if loaded.format_version == 2 and (typeof(loaded.gameplay_objects) != TYPE_ARRAY or not loaded.gameplay_objects.is_empty()):
   return {"document": null, "error": "Terrain-and-connector format 2 cannot contain gameplay object data."}
  if loaded.format_version < 4 and (loaded.activation_y != null or loaded.spawn_position != null):
   return {"document": null, "error": "Previous Act formats cannot contain lifecycle marker data."}
  if loaded.format_version < 5 and (typeof(loaded.ring_trails) != TYPE_ARRAY or not loaded.ring_trails.is_empty()):
   return {"document": null, "error": "Previous Act formats cannot contain ring trails."}
  if loaded.format_version < 6 and typeof(loaded.placements) == TYPE_ARRAY:
   for placement: Variant in loaded.placements:
    if placement is Dictionary and (placement.get("shape_id") == "composite" or placement.has("outline") or placement.has("composite_version") or placement.has("smoothing_strength")):
     return {"document": null, "error": "Previous Act formats cannot contain composite terrain."}
  if typeof(loaded.placements) == TYPE_ARRAY:
   for placement: Variant in loaded.placements:
    if placement is Dictionary and loaded.format_version < 8 and (placement.has("offset") or placement.has("terrain_scale")):
     return {"document": null, "error": "Fractional terrain transforms require Act format 8."}
    if placement is Dictionary and loaded.format_version < 9 and placement.has("fine_rotation_degrees"):
     return {"document": null, "error": "Fine terrain rotation requires Act format 9."}
  # Old Acts keep their exact authored data; only explicit saving writes the current version.
  loaded.format_version = FORMAT_VERSION
 var transform_decode_error := _decode_stored_terrain_transforms(loaded)
 if not transform_decode_error.is_empty():
  return {"document": null, "error": transform_decode_error}
 var composite_decode_error := _decode_stored_composites(loaded)
 if not composite_decode_error.is_empty():
  return {"document": null, "error": composite_decode_error}
 var decode_error := _decode_stored_angles(loaded)
 if not decode_error.is_empty():
  return {"document": null, "error": decode_error}
 if typeof(loaded.activation_y) == TYPE_PACKED_BYTE_ARRAY:
  var decoded: Variant = _decode_numeric_payload(loaded.activation_y)
  if decoded == null:
   return {"document": null, "error": "Activation trigger: invalid stored numeric Y coordinate."}
  loaded.activation_y = decoded
 if typeof(loaded.ring_trails) == TYPE_ARRAY:
  for index in loaded.ring_trails.size():
   var trail: Variant = loaded.ring_trails[index]
   if not trail is Dictionary: continue
   # Materialize legacy identity before edits can reorder or delete patterns.
   if not trail.has("pattern_id"): trail["pattern_id"] = RINGS.pattern_id(trail, index)
   for key: String in ["spacing", "rotation_degrees", "completion_bonus", "timeout", "respawn_delay"]:
    if typeof(trail.get(key)) == TYPE_PACKED_BYTE_ARRAY:
     var decoded: Variant = _decode_numeric_payload(trail[key])
     if decoded == null: return {"document": null, "error": "Ring pattern: invalid stored " + key}
     trail[key] = decoded
   if source_version in [15, 16]: RINGS.migrate_legacy_timing(trail)
 if typeof(loaded.decor_slots) == TYPE_ARRAY:
  for slot: Variant in loaded.decor_slots:
   if not slot is Dictionary: continue
   for key: String in ["rotation_degrees", "scale"]:
    if typeof(slot.get(key)) == TYPE_PACKED_BYTE_ARRAY:
     var decoded: Variant = _decode_numeric_payload(slot[key])
     if decoded == null: return {"document": null, "error": "Decor slot: invalid stored " + key}
     slot[key] = decoded
 var property_error := _decode_object_properties(loaded)
 if not property_error.is_empty(): return {"document": null, "error": property_error}
 if loaded.switch_banks is Array:
  for bank: Variant in loaded.switch_banks:
   if not bank is Dictionary: continue
   for key: String in ["completion_bonus", "reset_delay"]:
    if typeof(bank.get(key)) == TYPE_PACKED_BYTE_ARRAY:
     var decoded: Variant = _decode_numeric_payload(bank[key])
     if decoded == null: return {"document": null, "error": "Invalid stored bank " + key}
     bank[key] = decoded
 var errors: PackedStringArray = loaded.validation_errors()
 if not errors.is_empty():
  return {"document": null, "error": "\n".join(errors)}
 return {"document": loaded, "error": ""}

static func _decode_stored_terrain_transforms(document: Resource) -> String:
 if typeof(document.placements) != TYPE_ARRAY: return ""
 for placement: Variant in document.placements:
  if not placement is Dictionary: continue
  if typeof(placement.get("fine_rotation_degrees")) == TYPE_PACKED_BYTE_ARRAY:
   var decoded: Variant = _decode_numeric_payload(placement.fine_rotation_degrees)
   if decoded == null: return "Invalid stored fine terrain angle."
   placement.fine_rotation_degrees = decoded
  if typeof(placement.get("offset")) == TYPE_PACKED_BYTE_ARRAY:
   var payload: PackedByteArray = placement.offset
   var layout := var_to_bytes(Vector2.ZERO)
   if payload.size() != layout.size() or payload.decode_u32(0) != layout.decode_u32(0):
    return "Invalid stored terrain offset."
   placement.offset = bytes_to_var(payload)
 return ""

static func _decode_stored_composites(document: Resource) -> String:
 if typeof(document.placements) != TYPE_ARRAY: return ""
 for index in document.placements.size():
  var placement: Variant = document.placements[index]
  if not placement is Dictionary or placement.get("shape_id") != "composite": continue
  if typeof(placement.get("outline")) == TYPE_PACKED_BYTE_ARRAY:
   var payload: PackedByteArray = placement.outline
   var empty_layout := var_to_bytes(PackedVector2Array())
   var one_layout := var_to_bytes(PackedVector2Array([Vector2.ZERO]))
   var stride := one_layout.size() - empty_layout.size()
   # Accept only this engine's packed Vector2 layout and a bounded exact length.
   # Object/container headers never reach bytes_to_var (object decoding is off).
   if payload.size() < empty_layout.size() or payload.decode_u32(0) != empty_layout.decode_u32(0):
    return "Composite %d: invalid stored outline payload." % (index + 1)
   var count := payload.decode_u32(4)
   if count < 3 or count > COMPOSITES.MAX_VERTICES or payload.size() != empty_layout.size() + count * stride:
    return "Composite %d: invalid stored outline length." % (index + 1)
   placement.outline = bytes_to_var(payload)
  if typeof(placement.get("smoothing_strength")) == TYPE_PACKED_BYTE_ARRAY:
   var decoded: Variant = _decode_numeric_payload(placement.smoothing_strength)
   if decoded == null: return "Composite %d: invalid stored smoothing strength." % (index + 1)
   placement.smoothing_strength = decoded
 return ""

static func _decode_stored_angles(document: Resource) -> String:
 if typeof(document.gameplay_objects) != TYPE_ARRAY:
  return "" # The ordinary schema validator reports malformed collections.
 for index in document.gameplay_objects.size():
  var placement: Variant = document.gameplay_objects[index]
  if typeof(placement) != TYPE_DICTIONARY or typeof(placement.get("rotation_degrees")) != TYPE_PACKED_BYTE_ARRAY:
   continue
  var decoded: Variant = _decode_numeric_payload(placement.rotation_degrees)
  if decoded == null:
   return "Gameplay object %d: invalid stored numeric angle." % (index + 1)
  placement.rotation_degrees = decoded
 return ""

static func _decode_numeric_payload(payload: PackedByteArray) -> Variant:
 # Derive only primitive numeric layouts; do not accept objects or containers.
 # Null indicates malformed storage and must not become an unset marker.
 if payload.size() >= 4:
  for layout: PackedByteArray in [var_to_bytes(0), var_to_bytes(2147483648), var_to_bytes(0.0), var_to_bytes(PI)]:
   if payload.size() == layout.size() and payload.decode_u32(0) == layout.decode_u32(0):
    # bytes_to_var disables object decoding; only numeric headers reach it.
    return bytes_to_var(payload)
 return null

func _storage_document() -> Resource:
 var stored: Resource = copy_document()
 for placement: Dictionary in stored.placements:
  if placement.has("offset"): placement.offset = var_to_bytes(placement.offset)
  if placement.has("fine_rotation_degrees"): placement.fine_rotation_degrees = var_to_bytes(placement.fine_rotation_degrees)
  if placement.shape_id == "composite":
   # Preserve every float bit across text Resource serialization and new sessions.
   placement.outline = var_to_bytes(placement.outline)
   placement.smoothing_strength = var_to_bytes(placement.smoothing_strength)
 for placement: Dictionary in stored.gameplay_objects:
  # Godot 4.7's text float parser can shift arbitrary double scalars by one ULP.
  # Store the angle once as a native numeric byte payload in the same field.
  # Live documents and undo snapshots retain normal numeric rotation_degrees.
  placement.rotation_degrees = var_to_bytes(placement.rotation_degrees)
  for key: Variant in placement.get("properties", {}):
   if typeof(placement.properties[key]) in [TYPE_FLOAT, TYPE_INT, TYPE_PACKED_VECTOR2_ARRAY]:
    placement.properties[key] = var_to_bytes(placement.properties[key])
 for bank: Dictionary in stored.switch_banks:
  for key: String in ["completion_bonus", "reset_delay"]:
   if bank.has(key): bank[key] = var_to_bytes(bank[key])
 if stored.activation_y != null:
  # Use the same single-authority scalar representation as authored angles.
  stored.activation_y = var_to_bytes(stored.activation_y)
 for trail: Dictionary in stored.ring_trails:
  trail.spacing = var_to_bytes(trail.spacing)
  for key: String in ["rotation_degrees", "completion_bonus", "timeout", "respawn_delay"]:
   if trail.has(key): trail[key] = var_to_bytes(trail[key])
 for slot: Dictionary in stored.decor_slots:
  slot.rotation_degrees = var_to_bytes(slot.rotation_degrees)
  if slot.has("scale"): slot.scale = var_to_bytes(slot.scale)
 return stored

func save_document(path: String) -> Error:
 if not validation_errors().is_empty():
  return ERR_INVALID_DATA
 if path.get_extension().to_lower() != "tres":
  return ERR_FILE_UNRECOGNIZED
 var target := ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
 if not target.is_absolute_path() or not DirAccess.dir_exists_absolute(target.get_base_dir()):
  return ERR_FILE_BAD_PATH
 if DirAccess.dir_exists_absolute(target):
  return ERR_FILE_CANT_WRITE
 # Staging stays beside the destination so every rename stays on one filesystem.
 # Its .tres suffix is essential for ResourceSaver's format selection.
 var staged := _unused_sibling(target, "staging")
 var error := ResourceSaver.save(_storage_document(), staged)
 if error != OK:
  _remove_if_present(staged)
  return error
 var roundtrip := load_document(staged)
 if roundtrip.document == null or roundtrip.document.fingerprint() != fingerprint():
  _remove_if_present(staged)
  return ERR_FILE_CORRUPT
 var backup := ""
 if FileAccess.file_exists(target):
  backup = _unused_sibling(target, "backup")
  error = DirAccess.rename_absolute(target, backup)
  if error != OK:
   _remove_if_present(staged)
   return error
 error = DirAccess.rename_absolute(staged, target)
 if error != OK:
  if not backup.is_empty():
   var restore_error := DirAccess.rename_absolute(backup, target)
   if restore_error != OK:
    # Preserve both files if recovery is blocked; never delete the old contents.
    push_error("Act save could not restore its previous file. Recovery copy: " + backup)
    return restore_error
  _remove_if_present(staged)
  return error
 # The validated staged file now owns the destination. Only now remove backup.
 if not backup.is_empty():
  var cleanup_error := DirAccess.remove_absolute(backup)
  if cleanup_error != OK:
   push_warning("Act saved successfully; previous file remains at: " + backup)
 return OK

static func _unused_sibling(target: String, suffix: String) -> String:
 var stem := target.get_basename() + "." + suffix + "-" + str(Time.get_ticks_usec())
 var result := stem + ".tres"
 var collision := 0
 while FileAccess.file_exists(result) or DirAccess.dir_exists_absolute(result):
  collision += 1
  result = stem + "-" + str(collision) + ".tres"
 return result

static func _remove_if_present(path: String) -> void:
 if FileAccess.file_exists(path):
  DirAccess.remove_absolute(path)

static func _decode_object_properties(document: Resource) -> String:
 if typeof(document.gameplay_objects) != TYPE_ARRAY: return ""
 for index in document.gameplay_objects.size():
  var item: Variant = document.gameplay_objects[index]
  if not item is Dictionary: continue
  # Deterministic legacy identity survives repeated loads; new placements use random IDs.
  if not item.has("object_id"):
   item["object_id"] = OBJECTS.identity(item, index)
  if not item.has("properties"): item["properties"] = {}
  if not item.properties is Dictionary: continue
  for key: Variant in item.properties:
   if typeof(item.properties[key]) != TYPE_PACKED_BYTE_ARRAY: continue
   var payload: PackedByteArray = item.properties[key]
   if key == "points":
    var layout := var_to_bytes(PackedVector2Array())
    var stride := var_to_bytes(PackedVector2Array([Vector2.ZERO])).size() - layout.size()
    if payload.size() < 8 or payload.decode_u32(0) != layout.decode_u32(0): return "Invalid stored rail points."
    var count := payload.decode_u32(4)
    var maximum := OBJECTS.MAX_POSTS if item.get("type") == "lane_barrier" else 64
    if count < 2 or count > maximum or payload.size() != layout.size() + count * stride: return "Invalid stored path point count."
    item.properties[key] = bytes_to_var(payload)
   else:
    var decoded: Variant = _decode_numeric_payload(payload)
    if decoded == null: return "Invalid stored gameplay property: " + str(key)
    item.properties[key] = decoded
 return ""
