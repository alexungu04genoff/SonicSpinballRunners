extends RefCounted
## The only list of available production themes; Acts never store these IDs.
const IDS := ["green_hill", "chemical_plant", "rooftop_run", "casino_night", "sky_sanctuary", "ice_cap"]
const NAMES := ["Green Hill", "Chemical Plant", "Rooftop Run", "Casino Night", "Sky Sanctuary", "Ice Cap"]
const GreenHill = preload("res://scripts/themes/green_hill_theme.gd")

static func create(theme_id: String) -> RefCounted:
 if theme_id == "ice_cap":
  return load("res://scripts/themes/ice_cap_theme.gd").new()
 if theme_id == "sky_sanctuary":
  return load("res://scripts/themes/sky_sanctuary_theme.gd").new()
 if theme_id == "casino_night":
  return load("res://scripts/themes/casino_night_theme.gd").new()
 if theme_id == "rooftop_run":
  return load("res://scripts/themes/rooftop_run_theme.gd").new()
 if theme_id == "chemical_plant":
  return load("res://scripts/themes/chemical_plant_theme.gd").new()
 return GreenHill.new()
