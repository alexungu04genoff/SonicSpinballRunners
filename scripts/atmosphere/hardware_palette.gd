extends RefCounted
## Cosmetic materials shared by a presentation; animated materials opt out.
const Palette := preload("res://scripts/themes/theme_atmosphere.gd")
const DEFAULTS := {
 "spinner_frame": "b8cbd9", "spinner_crossbar": "dbe7ef",
 "spinner_paddle": "ffbf48", "spinner_accent": "244362",
 "dash_chassis": "182336", "dash_frame": "7456ad", "dash_chevrons": "58f2ff",
 "lane_chassis": "172435", "lane_crown": "77f9e5",
}

static func material(p: Node, key: String, color: Color, glow := 0.0, animated := false) -> StandardMaterial3D:
 var cache: Dictionary = p.get_meta("hardware_palette_materials", {})
 var id := str(p.call("_pinball_theme_id")) + "/" + key + "/" + color.to_html() + "/" + str(glow)
 if not animated and cache.has(id): return cache[id]
 var result: StandardMaterial3D = p.call("material", color, glow)
 Palette.color(result, key)
 if not animated:
  cache[id] = result
  p.set_meta("hardware_palette_materials", cache)
 return result

static func fixed(p: Node, key: String, glow := 0.0, animated := false, source_key := "") -> StandardMaterial3D:
 return material(p, key, Color(DEFAULTS[key if source_key.is_empty() else source_key]), glow, animated)

static func protect(material: Material) -> void:
 material.set_meta("atmosphere_protected", true)

static func ramp_material(p: Node, source: Material, role: String) -> Material:
 # A theme may reuse its terrain or decor material in a rail style. Keep
 # ramp ownership separate while sharing the copy across matching rails.
 var cache: Dictionary = p.get_meta("hardware_ramp_materials", {})
 var key := str(source.get_instance_id()) + "/" + role
 if cache.has(key): return cache[key]
 var result: Material = source.duplicate()
 if role == "deck": result.set_meta("atmosphere_hue", "ramps")
 elif result is BaseMaterial3D: Palette.color(result, "rail_accent")
 cache[key] = result
 p.set_meta("hardware_ramp_materials", cache)
 return result
