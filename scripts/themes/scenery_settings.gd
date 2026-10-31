extends RefCounted
## Authored presentation inputs beside an Act, independent of gameplay resources.
const VERSION := 1
const MAX_SEED := 2147483647
const THEMES := ["green_hill", "chemical_plant", "rooftop_run", "casino_night", "sky_sanctuary", "ice_cap"]
const DEFAULTS := {"seed": 0, "density": 1.0}

static func path_for(act_path: String) -> String:
 return act_path.get_basename() + ".scenery.cfg"

static func valid(values: Dictionary) -> bool:
 return typeof(values.get("seed")) == TYPE_INT and values.seed >= 0 and values.seed <= MAX_SEED and typeof(values.get("density")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(values.density)) and float(values.density) >= 0.5 and float(values.density) <= 1.5

static func read(act_path: String, theme: String) -> Dictionary:
 var result := {"seed": 0, "density": 1.0, "error": ""}
 if act_path.is_empty() or theme not in THEMES: return result
 var path := path_for(act_path)
 if not FileAccess.file_exists(path): return result
 var config := ConfigFile.new()
 var error := config.load(path)
 if error != OK:
  result.error = "Cannot read scenery settings: " + error_string(error)
  return result
 if config.get_value("format", "version", VERSION) != VERSION:
  result.error = "Unsupported scenery settings version."
  return result
 var values := {"seed": config.get_value(theme, "seed", 0), "density": config.get_value(theme, "density", 1.0)}
 if not valid(values):
  result.error = "Scenery settings need an integer seed and density between 0.50 and 1.50."
  return result
 result.seed = values.seed
 result.density = float(values.density)
 return result

static func signature(act_path: String, theme: String) -> String:
 if theme not in THEMES: return "fixed"
 var values := read(act_path, theme)
 if not values.error.is_empty(): return ""
 return signature_for(values)

static func signature_for(values: Dictionary) -> String:
 return var_to_bytes([int(values.seed), float(values.density)]).hex_encode().sha256_text()

static func save(act_path: String, theme: String, values: Dictionary) -> Error:
 if theme not in THEMES or not valid(values): return ERR_INVALID_DATA
 if act_path.get_extension() != "tres" or not FileAccess.file_exists(act_path): return ERR_FILE_BAD_PATH
 var path := ProjectSettings.globalize_path(path_for(act_path))
 var config := ConfigFile.new()
 if FileAccess.file_exists(path):
  var error := config.load(path)
  if error != OK: return error
  if config.get_value("format", "version", VERSION) != VERSION: return ERR_INVALID_DATA
 config.set_value("format", "version", VERSION)
 config.set_value(theme, "seed", int(values.seed))
 config.set_value(theme, "density", float(values.density))
 # Stage beside the destination and preserve other themes/unknown fields.
 var nonce := str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
 var staged := path + ".pending-" + nonce
 var backup := path + ".previous-" + nonce
 var error := config.save(staged)
 if error != OK: return error
 var check := ConfigFile.new()
 if check.load(staged) != OK or check.get_value(theme, "seed") != values.seed or check.get_value(theme, "density") != float(values.density):
  DirAccess.remove_absolute(staged)
  return ERR_FILE_CORRUPT
 var existed := FileAccess.file_exists(path)
 if existed:
  error = DirAccess.rename_absolute(path, backup)
  if error != OK:
   DirAccess.remove_absolute(staged)
   return error
 error = DirAccess.rename_absolute(staged, path)
 if error != OK:
  if existed and DirAccess.rename_absolute(backup, path) != OK:
   push_error("Scenery save recovery copy: " + backup)
  DirAccess.remove_absolute(staged)
  return error
 if existed: DirAccess.remove_absolute(backup)
 return OK
