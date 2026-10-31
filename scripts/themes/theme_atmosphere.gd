extends RefCounted
## Deliberate art-direction vocabulary. This is not a material/property inspector.
## Bindings are consumed on atmosphere changes, never by a per-frame traversal.
const FIELDS := {
 "green_hill": [
  ["Ocean deep", "ocean_deep"], ["Ocean wave", "ocean_wave"],
  ["Sky reflection", "ocean_reflection"], ["Sun highlight", "ocean_sun"],
  ["Cloud shadow", "cloud_shadow"], ["Cloud highlight", "cloud_highlight"],
  ["Distant vegetation tint", "vegetation_tint"], ["Distant sand / stone tint", "shore_tint"],
 ],
 "chemical_plant": [
  ["Reservoir deep", "reservoir_deep"], ["Reservoir ripple", "reservoir_ripple"],
  ["Industrial cyan", "industrial_cyan"], ["Signal pink", "signal_pink"],
 ],
 "rooftop_run": [
  ["Canal deep", "canal_deep"], ["Canal reflection", "canal_reflection"],
  ["Distant haze", "distant_haze"], ["Architecture tint", "architecture_tint"],
  ["Vegetation tint", "vegetation_tint"],
 ],
 "casino_night": [
  ["Neon pink", "neon_pink"], ["Neon aqua", "neon_aqua"],
  ["Neon mint", "neon_mint"], ["Neon amber", "neon_amber"],
  ["Skyline tint", "skyline_tint"], ["Purple accent", "purple_accent"],
  ["Window gold", "window_gold"], ["Marquee", "marquee"],
  ["Warm spill light", "warm_spill"], ["Blue spill light", "blue_spill"],
 ],
 "sky_sanctuary": [
  ["Cloud sea shadow", "sea_shadow"], ["Cloud sea highlight", "sea_highlight"],
  ["Cloud bank shadow", "bank_shadow"], ["Cloud bank highlight", "bank_highlight"],
  ["Ruin haze", "ruin_haze"],
 ],
 "ice_cap": [
  ["Sky horizon", "ice_horizon"], ["Sky upper", "ice_upper"],
  ["Sky aurora glow", "ice_sky_glow"], ["Star tint", "star_tint"],
  ["Star intensity", "star_intensity", "number", 0.0, 3.0, 0.01],
  ["Frozen lake", "lake_base"], ["Lake aurora reflection", "lake_reflection"],
  ["Aurora primary", "aurora_primary"], ["Aurora secondary", "aurora_secondary"],
  ["Aurora tertiary", "aurora_tertiary"],
  ["Aurora strength", "aurora_strength", "number", 0.0, 3.0, 0.01],
  ["Crystal tint", "crystal_tint"],
 ],
 "lava_reef": [
  ["Magma dark", "magma_dark"], ["Magma hot", "magma_hot"],
  ["Magma core", "magma_core"], ["Magma crust", "magma_crust"],
  ["Cavern tint", "cavern_tint"], ["Cavern deep", "cavern_deep"],
  ["Cavern magma bounce", "cavern_bounce"], ["Crystal dark", "crystal_dark"],
  ["Crystal highlight", "crystal_highlight"], ["Crystal vein", "crystal_vein"],
  ["Embers", "ember"], ["Magma bounce lights", "magma_light"],
 ],
 "aquarium_park": [
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
 "chemical_reservoir": {"deep_color": "reservoir_deep", "ripple_color": "reservoir_ripple"},
 "rooftop_canal": {"deep_color": "canal_deep", "reflection_color": "canal_reflection"},
 "sanctuary_clouds": {"shadow_color": "sea_shadow", "highlight_color": "sea_highlight"},
 "sanctuary_cloud_volume": {"shadow_color": "bank_shadow", "highlight_color": "bank_highlight"},
 "ice_sky": {"horizon_color": "ice_horizon", "upper_color": "ice_upper", "glow_color": "ice_sky_glow", "star_color": "star_tint", "star_intensity": "star_intensity"},
 "ice_lake": {"base_color": "lake_base", "reflection_color": "lake_reflection"},
 "ice_aurora": {"primary_color": "aurora_primary", "secondary_color": "aurora_secondary", "tertiary_color": "aurora_tertiary", "atmosphere_strength": "aurora_strength"},
 "ice_crystal": {"atmosphere_tint": "crystal_tint"},
 "lava_molten": {"dark_color": "magma_dark", "hot_color": "magma_hot", "core_color": "magma_core", "crust_color": "magma_crust"},
 "lava_cavern": {"atmosphere_tint": "cavern_tint", "deep_color": "cavern_deep", "bounce_color": "cavern_bounce"},
 "lava_crystal": {"dark_color": "crystal_dark", "highlight_color": "crystal_highlight", "vein_color": "crystal_vein"},
 "lava_embers": {"ember_color": "ember"},
 "aquarium_water": {"deep_color": "lagoon_deep", "wave_color": "lagoon_wave", "caustic_color": "caustic", "reflection_color": "water_reflection", "lantern_color": "lantern_reflection"},
 "aquarium_glass": {"base_color": "glass_base", "glow_tint": "glass_glow_tint"},
}

static func tag(target: Object, property: String, key: String, mode := "direct", extra: Dictionary = {}) -> void:
 var bindings: Dictionary = target.get_meta("atmosphere_bindings", {})
 var binding := {"key": key, "mode": mode}
 binding.merge(extra)
 bindings[property] = binding
 target.set_meta("atmosphere_bindings", bindings)

static func color(material: BaseMaterial3D, key: String, mode := "direct") -> void:
 tag(material, "albedo_color", key, mode)
 if material.emission_enabled: tag(material, "emission", key, mode)

static func fields(theme: String) -> Array:
 var result: Array = []
 for field: Array in FIELDS.get(theme, []):
  var spec := field.duplicate()
  spec[1] = "palette/" + spec[1]
  if spec.size() == 2: spec.append("color")
  result.append(spec)
 return result
