extends RefCounted
## Deliberate art-direction vocabulary. This is not a material/property inspector.
## Bindings are consumed on atmosphere changes, never by a per-frame traversal.
const FIELDS := {
 "green_hill": [
  ["Nearby sand", "local_sand"], ["Rock tint", "rock_tint"],
  ["Ocean deep", "ocean_deep"], ["Ocean wave", "ocean_wave"],
  ["Sky reflection", "ocean_reflection"], ["Sun highlight", "ocean_sun"],
  ["Cloud shadow", "cloud_shadow"], ["Cloud highlight", "cloud_highlight"],
  ["Distant vegetation tint", "vegetation_tint"], ["Distant sand / stone tint", "shore_tint"],
 ],
 "rooftop_run": [
  ["Roof tint", "roof_tint"],
  ["Canal deep", "canal_deep"], ["Canal reflection", "canal_reflection"],
  ["Distant haze", "distant_haze"], ["Architecture tint", "architecture_tint"],
  ["Vegetation tint", "vegetation_tint"],
 ],
 "casino_night": [
  ["Housing tint", "housing_tint"], ["Decorative metal tint", "metal_tint"],
  ["Neon pink", "neon_pink"], ["Neon aqua", "neon_aqua"],
  ["Neon mint", "neon_mint"], ["Neon amber", "neon_amber"],
  ["Skyline tint", "skyline_tint"], ["Purple accent", "purple_accent"],
  ["Window gold", "window_gold"], ["Marquee", "marquee"],
  ["Warm spill light", "warm_spill"], ["Blue spill light", "blue_spill"],
 ],
 "ice_cap": [
  ["Snow tint", "snow_tint"], ["Solid ice tint", "ice_tint"], ["Mountain ridge tint", "ridge_tint"],
  ["Sky horizon", "ice_horizon"], ["Sky upper", "ice_upper"],
  ["Sky aurora glow", "ice_sky_glow"], ["Star tint", "star_tint"],
  ["Star intensity", "star_intensity", "number", 0.0, 3.0, 0.01],
  ["Frozen lake", "lake_base"], ["Lake aurora reflection", "lake_reflection"],
  ["Aurora primary", "aurora_primary"], ["Aurora secondary", "aurora_secondary"],
  ["Aurora tertiary", "aurora_tertiary"],
  ["Aurora strength", "aurora_strength", "number", 0.0, 3.0, 0.01],
  ["Crystal tint", "crystal_tint"],
 ],
 "aquarium_park": [
  ["Architecture tint", "architecture_tint"], ["Roof tint", "roof_tint"],
  ["Lagoon deep", "lagoon_deep"], ["Lagoon wave", "lagoon_wave"],
  ["Caustic glow", "caustic"], ["Water reflection", "water_reflection"],
  ["Lantern reflection", "lantern_reflection"], ["Glass base", "glass_base"],
  ["Glass glow tint", "glass_glow_tint"], ["Lantern paper", "lantern_paper"],
  ["Lantern emission", "lantern_emission"], ["Coral", "coral"],
  ["Aquatic accent tint", "aquatic_tint"],
  ["Left lantern spill", "lantern_left"], ["Right lantern spill", "lantern_right"],
 ],
}

# Only these shader uniforms participate. Raw vec3 colors intentionally retain
# the old shader's linear constants; the Lab converts color-picker sRGB once on
# apply. This avoids changing the authored image when introducing uniforms.
const SHADERS := {
 "green_hill_ocean": {"deep_color": "ocean_deep", "wave_color": "ocean_wave", "reflection_color": "ocean_reflection", "sun_color": "ocean_sun"},
 "green_hill_cloud": {"shadow_color": "cloud_shadow", "highlight_color": "cloud_highlight"},
 "rooftop_canal": {"deep_color": "canal_deep", "reflection_color": "canal_reflection"},
 "ice_sky": {"horizon_color": "ice_horizon", "upper_color": "ice_upper", "glow_color": "ice_sky_glow", "star_color": "star_tint", "star_intensity": "star_intensity"},
 "ice_lake": {"base_color": "lake_base", "reflection_color": "lake_reflection"},
 "ice_aurora": {"primary_color": "aurora_primary", "secondary_color": "aurora_secondary", "tertiary_color": "aurora_tertiary", "atmosphere_strength": "aurora_strength"},
 "ice_crystal": {"atmosphere_tint": "crystal_tint"},
 "aquarium_water": {"deep_color": "lagoon_deep", "wave_color": "lagoon_wave", "caustic_color": "caustic", "reflection_color": "water_reflection", "lantern_color": "lantern_reflection"},
 "aquarium_glass": {"base_color": "glass_base", "glow_tint": "glass_glow_tint"},
}

static func tag(target: Object, property: String, key: String, mode := "direct", extra: Dictionary = {}) -> void:
 # Resource.duplicate() can retain shared metadata dictionaries. Retagging a
 # scenery copy must not overwrite the source material's palette ownership.
 var bindings: Dictionary = target.get_meta("atmosphere_bindings", {}).duplicate(true)
 var binding := {"key": key, "mode": mode}
 binding.merge(extra)
 bindings[property] = binding
 target.set_meta("atmosphere_bindings", bindings)

static func color(material: BaseMaterial3D, key: String, mode := "direct") -> void:
 tag(material, "albedo_color", key, mode)
 if material.emission_enabled: tag(material, "emission", key, mode)

static func foliage(material: Material) -> void:
 material.set_meta("atmosphere_hue", "foliage")

static func is_foliage(material: Material) -> bool:
 if material.get_meta("atmosphere_hue", "") == "foliage": return true
 for binding: Dictionary in material.get_meta("atmosphere_bindings", {}).values():
  if binding.get("key") == "vegetation_tint": return true
 return false

const HARDWARE_FIELDS := [
 ["Rubber", "hardware_rubber"],
 ["Bumper face", "hardware_face"],
 ["Metal trim", "hardware_trim"],
 ["Markings / stars / chevrons", "hardware_mark"],
 ["Flipper face", "hardware_paddle"],
 ["Hardware base", "hardware_base"],
 ["Mechanism body", "mechanism_body"],
 ["Mechanism trim", "mechanism_trim"],
 ["Mechanism accent", "mechanism_light"],
 ["Spinner frame", "spinner_frame"],
 ["Spinner paddle", "spinner_paddle"],
 ["Spinner accent / inset", "spinner_accent"],
 ["Dash chassis", "dash_chassis"],
 ["Dash frame", "dash_frame"],
 ["Dash chevrons", "dash_chevrons"],
 ["Rail accent", "rail_accent"],
]

static func fields(theme: String) -> Array:
 var result: Array = []
 for field: Array in FIELDS.get(theme, []) + HARDWARE_FIELDS:
  var spec := field.duplicate()
  spec[1] = "palette/" + spec[1]
  if spec.size() == 2: spec.append("color")
  result.append(spec)
 return result
