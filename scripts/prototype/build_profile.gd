extends RefCounted
## Optional immutable content limits for a named playtest export.
const Registry = preload("res://scripts/themes/theme_registry.gd")

static func theme_ids() -> Array:
 return Array(ProjectSettings.get_setting("playtest/themes", Registry.IDS))

static func character_ids() -> Array:
 return Array(ProjectSettings.get_setting("playtest/characters", CharacterSpecials.CHARACTERS.keys()))

static func default_themes() -> Array:
 var available := theme_ids()
 if ProjectSettings.has_setting("playtest/themes"): return available.duplicate()
 var result: Array = ["green_hill", "chemical_plant"].filter(func(id): return id in available)
 return result if not result.is_empty() else available.duplicate()
