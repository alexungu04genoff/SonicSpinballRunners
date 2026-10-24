class_name ActGeometry
extends Resource
## A single Act's editable terrain references. No runtime or gameplay objects.
const FORMAT_VERSION := 1
const SHAPES = preload("res://scripts/act_editor/terrain_shapes.gd")
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

var _format_version_was_set := false
var _library_version_was_set := false

func _init() -> void:
 # Declared zero defaults force ResourceSaver to write both current versions.
 # Missing fields on load must not inherit constructor defaults invisibly.
 format_version = FORMAT_VERSION
 library_version = SHAPES.VERSION
 _format_version_was_set = false
 _library_version_was_set = false

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
 # ResourceSaver can omit an integer cell size equal to the default float size.
 # Treat equivalent numeric cell sizes identically while preserving their value.
 var normalized_cell_size: Variant = float(cell_size) if typeof(cell_size) in [TYPE_INT, TYPE_FLOAT] else cell_size
 return var_to_str([format_version, library_version, title, grid_size, normalized_cell_size, ordered_placements]).sha256_text()

func copy_document() -> Resource:
 var result: Resource = get_script().new()
 result.format_version = format_version
 result.library_version = library_version
 result.title = title
 result.grid_size = grid_size
 result.cell_size = cell_size
 result.placements = placements.duplicate(true) if typeof(placements) == TYPE_ARRAY else placements
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
 var errors: PackedStringArray = loaded.validation_errors()
 if not errors.is_empty():
  return {"document": null, "error": "\n".join(errors)}
 return {"document": loaded, "error": ""}

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
 var error := ResourceSaver.save(copy_document(), staged)
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
