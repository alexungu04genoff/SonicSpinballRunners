extends RefCounted
## Data-only, user-local transport for an unsaved Lab appearance.
const Fields = preload("res://scripts/atmosphere/fields.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")

static func validation_error(preview: Dictionary) -> String:
 if preview.get("theme", "") not in Registry.IDS: return "Unknown atmosphere preview theme."
 if not preview.get("values") is Dictionary or not Fields.valid_values(preview.theme, preview.values): return "Invalid atmosphere preview values."
 return ""

static func save_preview(preview: Dictionary) -> Dictionary:
 var error := validation_error(preview)
 if not error.is_empty(): return {"error": error, "path": ""}
 preview = preview.duplicate(true)
 preview.values = Fields.appearance_values(preview.values)
 var directory := "user://atmosphere_playtests"
 var result := DirAccess.make_dir_recursive_absolute(directory)
 var path := directory.path_join("preview_%d_%d.bin" % [OS.get_process_id(), Time.get_ticks_usec()])
 if result == OK:
  var file := FileAccess.open(path, FileAccess.WRITE)
  result = FileAccess.get_open_error()
  if file != null:
   # Variant storage preserves float/Color precision; objects are never encoded.
   file.store_var({"version": 1, "preview": preview}, false)
   result = file.get_error()
 return {"error": "" if result == OK else "Cannot save atmosphere preview: " + error_string(result), "path": ProjectSettings.globalize_path(path)}

static func read_preview(path: String) -> Dictionary:
 var file := FileAccess.open(path, FileAccess.READ)
 if file == null:
  return {"error": "Cannot read atmosphere preview.", "preview": {}}
 var data: Variant = file.get_var(false)
 if not data is Dictionary or data.get("version", 0) != 1: return {"error": "Invalid atmosphere preview format.", "preview": {}}
 var preview: Variant = data.get("preview", {})
 if not preview is Dictionary: return {"error": "Invalid atmosphere preview.", "preview": {}}
 var error := validation_error(preview)
 if error.is_empty(): preview.values = Fields.appearance_values(preview.values)
 return {"error": error, "preview": preview}
