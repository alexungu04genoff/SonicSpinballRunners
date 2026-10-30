extends RefCounted
## Stable, run-local input. Preferences store exclusions so new Acts opt in.
const Registry = preload("res://scripts/themes/theme_registry.gd")
const ACTS_PER_ZONE := 3
var zone_count := 2
var selected_theme_ids: Array = ["green_hill", "chemical_plant"]
var selected_act_paths: Array = []

func _init(paths: Array = []) -> void:
 selected_act_paths = paths.duplicate()
 selected_act_paths.sort()

func validation_error() -> String:
 if zone_count < 1 or zone_count > 7: return "Choose 1–7 Zones."
 if selected_theme_ids.is_empty(): return "Select at least one theme."
 for id: String in selected_theme_ids:
  if id not in Registry.IDS: return "Unknown theme: " + id
 if selected_act_paths.size() < ACTS_PER_ZONE: return "Select at least 3 Acts (3 distinct Acts per Zone)."
 if selected_act_paths.size() != _unique(selected_act_paths).size(): return "Select distinct Act sources."
 return ""

static func _unique(values: Array) -> Array:
 var result: Array = []
 for value: Variant in values:
  if value not in result: result.append(value)
 result.sort()
 return result

func snapshot() -> Dictionary:
 return {"zone_count": zone_count, "acts_per_zone": ACTS_PER_ZONE,
  "selected_themes": _unique(selected_theme_ids), "selected_acts": _unique(selected_act_paths)}

func fingerprint() -> String:
 return JSON.stringify(snapshot()).sha256_text()

func read_preferences(settings: ConfigFile, available: Array) -> void:
 zone_count = clampi(int(settings.get_value("run_setup", "zone_count", 2)), 1, 7)
 selected_theme_ids = []
 for id: Variant in settings.get_value("run_setup", "selected_themes", ["green_hill", "chemical_plant"]):
  if id in Registry.IDS and id not in selected_theme_ids: selected_theme_ids.append(id)
 var excluded: Array = settings.get_value("run_setup", "excluded_acts", [])
 selected_act_paths = []
 for path: String in available:
  if path not in excluded: selected_act_paths.append(path)
 selected_act_paths.sort()

func write_preferences(settings: ConfigFile, available: Array) -> void:
 settings.set_value("run_setup", "zone_count", zone_count)
 settings.set_value("run_setup", "selected_themes", _unique(selected_theme_ids))
 var excluded: Array = []
 for path: String in available:
  if path not in selected_act_paths: excluded.append(path)
 settings.set_value("run_setup", "excluded_acts", excluded)
