extends RefCounted
## Project-owned Theme atmospheres. Data is deliberately outside bake dependencies.
const DIRECTORY := "res://data/atmospheres"
const Fields := preload("res://scripts/atmosphere/fields.gd")
const THEMES := ["green_hill", "chemical_plant", "rooftop_run", "casino_night", "sky_sanctuary", "ice_cap", "lava_reef", "aquarium_park"]
var directory := DIRECTORY
var error := ""

static func baseline() -> Dictionary:
 return {"id": "default", "name": "Default", "enabled": true, "weight": 1.0, "values": {}}

func path(theme: String) -> String:
 return directory.path_join(theme + ".cfg")

func revision(theme: String) -> String:
 return FileAccess.get_sha256(path(theme)) if FileAccess.file_exists(path(theme)) else ""

func read(theme: String) -> Array[Dictionary]:
 error = ""
 var result: Array[Dictionary] = []
 if theme not in THEMES:
  error = "Unknown theme."
  return [baseline()]
 var file := ConfigFile.new()
 if file.load(path(theme)) != OK or file.get_value("format", "version", 0) != 1:
  error = "Cannot read atmosphere format: " + path(theme)
  return [baseline()]
 for id: String in file.get_sections():
  if id == "format": continue
  result.append({"id": id, "name": file.get_value(id, "name", ""), "enabled": file.get_value(id, "enabled", false), "weight": file.get_value(id, "weight", -1), "values": file.get_value(id, "values", {})})
 error = validate(theme, result)
 if not error.is_empty(): return [baseline()]
 result.sort_custom(func(a: Dictionary, b: Dictionary): return a.id == "default" or (b.id != "default" and a.id < b.id))
 return result

static func validate(theme: String, records: Array[Dictionary]) -> String:
 var ids := {}
 var names := {}
 var total := 0.0
 for record: Dictionary in records:
  var id: Variant = record.get("id")
  var title: Variant = record.get("name")
  if not id is String or id.is_empty() or not id.is_valid_identifier() or ids.has(id): return "Variant IDs must be unique identifiers."
  if not title is String or title.strip_edges().is_empty() or title.length() > 64 or names.has(title.to_lower()): return "Choose a unique name of 1–64 characters."
  ids[id] = true
  names[title.to_lower()] = true
  if not record.get("enabled") is bool: return "Enabled must be a boolean."
  var weight: Variant = record.get("weight")
  if typeof(weight) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(weight)) or weight < 0 or weight > 1000000: return "Weight must be finite, between 0 and 1000000."
  if not record.get("values") is Dictionary or not Fields.valid_values(theme, record.values): return "Unsupported atmosphere value or range."
  if id == "default" and (title != "Default" or not record.values.is_empty()): return "Default appearance is protected. Duplicate it to author a look."
  if record.enabled: total += weight
 if not ids.has("default"): return "Default cannot be deleted."
 if total <= 0: return "Keep at least one enabled variant with positive weight."
 return ""

func save(theme: String, records: Array[Dictionary], expected_revision: String) -> bool:
 error = validate(theme, records)
 if theme not in THEMES: error = "Unknown theme."
 if not error.is_empty(): return false
 if revision(theme) != expected_revision:
  error = "Project variants changed on disk. Revert/reload before saving."
  return false
 var file := ConfigFile.new()
 file.set_value("format", "version", 1)
 for record: Dictionary in records:
  for key: String in ["name", "enabled", "weight", "values"]: file.set_value(record.id, key, record[key])
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 var temporary := path(theme) + ".tmp"
 var result := file.save(temporary)
 if result == OK: result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path(theme)))
 if result != OK: error = "Save failed: " + error_string(result)
 return result == OK

static func chance(records: Array[Dictionary], id: String) -> float:
 var total := 0.0
 var weight := 0.0
 for record: Dictionary in records:
  if not record.enabled: continue
  total += record.weight
  if record.id == id: weight = record.weight
 return weight / total if total > 0 else 0.0

func choose(theme: String, run_seed: int, zone: int, override_id := "") -> Dictionary:
 var records := read(theme)
 if not override_id.is_empty():
  for record: Dictionary in records:
   if record.id == override_id: return record.duplicate(true)
  push_error("Unknown atmosphere override: " + theme + "/" + override_id)
  return baseline()
 var random := RandomNumberGenerator.new()
 random.seed = ("atmosphere/v1/%d/%d/%s" % [run_seed, zone, theme]).sha256_text().left(15).hex_to_int()
 var total := 0.0
 for record: Dictionary in records:
  if record.enabled: total += record.weight
 var roll := random.randf() * total
 for record: Dictionary in records:
  if not record.enabled or record.weight <= 0: continue
  roll -= record.weight
  if roll <= 0: return record.duplicate(true)
 return baseline()
