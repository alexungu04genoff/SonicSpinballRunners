class_name ActGeometry
extends Resource
## A single Act's terrain, boundary connectors and exact gameplay authoring data.
const FORMAT_VERSION := 3
const SHAPES = preload("res://scripts/act_editor/terrain_shapes.gd")
const OBJECTS = preload("res://scripts/act_editor/gameplay_objects.gd")
const SCRIPT_PATH := "res://scripts/act_editor/act_geometry.gd"
const PLACEMENT_TYPES := {
 "shape_id": TYPE_STRING,
 "base_size": TYPE_VECTOR2I,
 "anchor": TYPE_VECTOR2I,
 "quarter_turns": TYPE_INT,
 "flip_h": TYPE_BOOL,
 "flip_v": TYPE_BOOL,
}

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
## Entry lies on the bottom boundary; exit lies on the top boundary.
## A zero start and width represent an unset connector in an editable draft.
@export var entry_start_x = 0
@export var entry_width = 0
@export var exit_start_x = 0
@export var exit_width = 0

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

func validation_errors() -> PackedStringArray:
 var errors := PackedStringArray()
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
 if typeof(placements) != TYPE_ARRAY:
  errors.append("Terrain placements must be an array of dictionaries.")
  return errors
 for index in placements.size():
  var prefix := "Placement %d: " % (index + 1)
  if typeof(placements[index]) != TYPE_DICTIONARY:
   errors.append(prefix + "terrain placement must be a dictionary.")
   continue
  var placement: Dictionary = placements[index]
  var valid_types := true
  for key: String in PLACEMENT_TYPES:
   if not placement.has(key) or typeof(placement[key]) != PLACEMENT_TYPES[key]:
    errors.append(prefix + "%s must be %s." % [key, type_string(PLACEMENT_TYPES[key])])
    valid_types = false
  for key: Variant in placement:
   if typeof(key) != TYPE_STRING or not PLACEMENT_TYPES.has(key):
    errors.append(prefix + "unrecognized placement field; only terrain reference and transform fields are supported.")
  if not valid_types:
   continue
  var definition: Dictionary = SHAPES.get_definition(placement.shape_id)
  if definition.is_empty():
   errors.append(prefix + "unknown terrain shape '%s'." % placement.shape_id)
   continue
  if placement.base_size != definition.size:
   errors.append(prefix + "base footprint does not match its shape definition.")
  if placement.quarter_turns < 0 or placement.quarter_turns > 3:
   errors.append(prefix + "rotation must be 0, 1, 2 or 3 quarter-turns.")
  var frame: Vector2i = SHAPES.transformed_size(placement)
  var anchor: Vector2i = placement.anchor
  # Frame bounds are the only spatial restriction. Overlap is deliberately valid.
  if valid_grid_type and (anchor.x < 0 or anchor.y < 0 or anchor.x > grid_size.x - frame.x or anchor.y > grid_size.y - frame.y):
   errors.append(prefix + "the transformed footprint must fit inside this Act.")
 return errors

func _gameplay_validation_errors() -> PackedStringArray:
 var errors := PackedStringArray()
 if typeof(gameplay_objects) != TYPE_ARRAY:
  errors.append("Gameplay objects must be an array of dictionaries.")
  return errors
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
  for key: Variant in placement:
   if typeof(key) != TYPE_STRING or key not in ["type", "position", "rotation_degrees"]:
    errors.append(prefix + "unrecognized object field; only type, position and rotation_degrees are supported.")
 # Gameplay data has no grid bounds, occupancy rules, angle normalization or snapping.
 return errors

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
   else:
    ordered_objects.append(placement)
 else:
  ordered_objects.append(gameplay_objects)
 # ResourceSaver can omit an integer cell size equal to the default float size.
 # Treat equivalent numeric cell sizes identically while preserving their value.
 var normalized_cell_size: Variant = float(cell_size) if typeof(cell_size) in [TYPE_INT, TYPE_FLOAT] else cell_size
 # Hash native scalar bits: decimal formatting can collapse adjacent float values.
 return var_to_bytes([format_version, library_version, title, grid_size, normalized_cell_size, ordered_placements, entry_start_x, entry_width, exit_start_x, exit_width, ordered_objects]).hex_encode().sha256_text()

func copy_document() -> Resource:
 var result: Resource = get_script().new()
 result.format_version = format_version
 result.library_version = library_version
 result.title = title
 result.grid_size = grid_size
 result.cell_size = cell_size
 result.placements = placements.duplicate(true) if typeof(placements) == TYPE_ARRAY else placements
 result.gameplay_objects = gameplay_objects.duplicate(true) if typeof(gameplay_objects) == TYPE_ARRAY else gameplay_objects
 result.entry_start_x = entry_start_x
 result.entry_width = entry_width
 result.exit_start_x = exit_start_x
 result.exit_width = exit_width
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
 if typeof(loaded.format_version) == TYPE_INT and loaded.format_version == 2 and typeof(loaded.library_version) == TYPE_INT and loaded.library_version == SHAPES.VERSION:
  if typeof(loaded.gameplay_objects) != TYPE_ARRAY or not loaded.gameplay_objects.is_empty():
   return {"document": null, "error": "Terrain-and-connector format 2 cannot contain gameplay object data."}
  # Previous Acts gain an empty object list in memory. Only an explicit save writes v3.
  loaded.format_version = FORMAT_VERSION
 var decode_error := _decode_stored_angles(loaded)
 if not decode_error.is_empty():
  return {"document": null, "error": decode_error}
 var errors: PackedStringArray = loaded.validation_errors()
 if not errors.is_empty():
  return {"document": null, "error": "\n".join(errors)}
 return {"document": loaded, "error": ""}

static func _decode_stored_angles(document: Resource) -> String:
 if typeof(document.gameplay_objects) != TYPE_ARRAY:
  return "" # The ordinary schema validator reports malformed collections.
 # Derive Godot's supported primitive numeric layouts without accepting objects
 # or arbitrary encoded containers. The payload has only one numeric authority.
 var numeric_layouts := [var_to_bytes(0), var_to_bytes(2147483648), var_to_bytes(0.0), var_to_bytes(PI)]
 for index in document.gameplay_objects.size():
  var placement: Variant = document.gameplay_objects[index]
  if typeof(placement) != TYPE_DICTIONARY or typeof(placement.get("rotation_degrees")) != TYPE_PACKED_BYTE_ARRAY:
   continue
  var payload: PackedByteArray = placement.rotation_degrees
  var valid_layout := false
  if payload.size() >= 4:
   for layout: PackedByteArray in numeric_layouts:
    if payload.size() == layout.size() and payload.decode_u32(0) == layout.decode_u32(0):
     valid_layout = true
     break
  if not valid_layout:
   return "Gameplay object %d: invalid stored numeric angle." % (index + 1)
  # bytes_to_var disables object decoding by default; only numeric headers passed.
  placement.rotation_degrees = bytes_to_var(payload)
 return ""

func _storage_document() -> Resource:
 var stored: Resource = copy_document()
 for placement: Dictionary in stored.gameplay_objects:
  # Godot 4.7's text float parser can shift arbitrary double angles by one ULP.
  # Store the angle once as a native numeric byte payload in the same field.
  # Live documents and undo snapshots retain normal numeric rotation_degrees.
  placement.rotation_degrees = var_to_bytes(placement.rotation_degrees)
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
