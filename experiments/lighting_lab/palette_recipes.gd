extends RefCounted
## Editable starting recipes, never saved or promoted to production automatically.
## Only obvious environmental relationships are mapped; structural/readability
## colors and unmatched controls keep their authored values.
const SUNSET := {
 "green_hill": {"ocean_deep": "23485f", "ocean_wave": "526b83", "ocean_reflection": "d6979b", "ocean_sun": "ffd7a1", "cloud_shadow": "77799d", "cloud_highlight": "f5cfbc", "vegetation_tint": "b8bdcf", "shore_tint": "efc8b7"},
 "chemical_plant": {"reservoir_deep": "292240", "reservoir_ripple": "8a4764"},
 "rooftop_run": {"canal_deep": "304a63", "canal_reflection": "be9592", "distant_haze": "83768e", "architecture_tint": "ffd6b4", "vegetation_tint": "a8b5c5"},
 "sky_sanctuary": {"sea_shadow": "797b9c", "sea_highlight": "efd0bb", "bank_shadow": "6b7193", "bank_highlight": "ffddbf", "ruin_haze": "a59bb8"},
 "ice_cap": {"ice_horizon": "b987a6", "ice_upper": "303658", "ice_sky_glow": "34484f", "star_intensity": 0.15, "lake_base": "292e48", "lake_reflection": "956f83", "aurora_strength": 0.35},
 "aquarium_park": {"lagoon_deep": "132c43", "lagoon_wave": "28495d", "water_reflection": "786e91", "lantern_reflection": "b8784b"},
}
const NIGHT := {
 "green_hill": {"ocean_deep": "0c1e32", "ocean_wave": "1a354d", "ocean_reflection": "426686", "ocean_sun": "718aa7", "cloud_shadow": "16263d", "cloud_highlight": "526985", "vegetation_tint": "7893b9", "shore_tint": "8199bb"},
 "chemical_plant": {"reservoir_deep": "0e1027", "reservoir_ripple": "392851"},
 "rooftop_run": {"canal_deep": "122538", "canal_reflection": "385873", "distant_haze": "293b55", "architecture_tint": "7f96bd", "vegetation_tint": "6884a7"},
 "casino_night": {"skyline_tint": "7b83ae"},
 "sky_sanctuary": {"sea_shadow": "142137", "sea_highlight": "425a79", "bank_shadow": "19263e", "bank_highlight": "5b7495", "ruin_haze": "3c5275"},
 "ice_cap": {"ice_horizon": "242c4c", "ice_upper": "060d24", "ice_sky_glow": "183f4a", "star_tint": "b9d7f3", "star_intensity": 1.15, "lake_base": "0c192e", "lake_reflection": "205f67"},
 "lava_reef": {"cavern_tint": "7e91b4", "cavern_deep": "101023"},
 "aquarium_park": {"lagoon_deep": "071a2c", "lagoon_wave": "102c3f", "caustic": "286878", "water_reflection": "224761", "glass_base": "123b50", "glass_glow_tint": "7795b5"},
}
const NEON := {
 "chemical_plant": {"reservoir_deep": "190d2c", "reservoir_ripple": "6d245c", "industrial_cyan": "44dfee", "signal_pink": "ff538b"},
 "casino_night": {"neon_pink": "f9398c", "neon_aqua": "28b6ef", "neon_mint": "54e8ae", "neon_amber": "ffbc50"},
 "aquarium_park": {"caustic": "258b9a", "lantern_emission": "ff9b60"},
}

static func apply(title: String, theme: String, values: Dictionary) -> void:
 var recipe: Dictionary = {}
 if title in ["Sunset", "Golden hour", "Morning"]: recipe = SUNSET.get(theme, {})
 elif title in ["Night", "Neon night", "Moonlit", "Dusk", "Blue hour"]: recipe = NIGHT.get(theme, {})
 recipe = recipe.duplicate()
 if title == "Neon night": recipe.merge(NEON.get(theme, {}), true)
 for key: String in recipe:
  var property := "palette/" + key
  if not values.has(property): continue
  values[property] = Color(recipe[key]) if recipe[key] is String else recipe[key]
