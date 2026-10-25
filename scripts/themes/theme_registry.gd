extends RefCounted
## The only list of available production themes; Acts never store these IDs.
const IDS := ["green_hill", "chemical_plant"]
const NAMES := ["Green Hill", "Chemical Plant"]
const GreenHill = preload("res://scripts/themes/green_hill_theme.gd")

static func create(theme_id: String) -> RefCounted:
 if theme_id == "chemical_plant":
  return load("res://scripts/themes/chemical_plant_theme.gd").new()
 return GreenHill.new()
