extends RefCounted
## Optional immutable content limits for a named playtest export.
const Registry = preload("res://scripts/themes/theme_registry.gd")

static func theme_ids() -> Array:
 var allowed := Array(ProjectSettings.get_setting("playtest/themes", Registry.IDS))
 return Registry.IDS.filter(func(id): return id in allowed)

static func character_ids() -> Array:
 return Array(ProjectSettings.get_setting("playtest/characters", CharacterSpecials.CHARACTERS.keys()))

static func default_themes() -> Array:
 return theme_ids()
