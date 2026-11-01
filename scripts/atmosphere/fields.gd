extends RefCounted
## Shared, bounded authoring vocabulary for production and the Lab.
const GROUPS := {
 "Light": [
  ["Exposure", "env/tonemap_exposure", "number", 0.05, 4.0, 0.01],
  ["Tonemapper", "env/tonemap_mode", "tone"],
  ["Ambient energy", "env/ambient_light_energy", "number", 0.0, 3.0, 0.01],
  ["Ambient color", "env/ambient_light_color", "color"],
  ["Sky contribution", "env/ambient_light_sky_contribution", "number", 0.0, 1.0, 0.01],
  ["Sun energy", "sun/light_energy", "number", 0.0, 4.0, 0.01],
  ["Sun color", "sun/light_color", "color"],
  ["Sun elevation", "sun_pitch", "number", -90.0, 0.0, 0.5],
  ["Sun azimuth", "sun_yaw", "number", -180.0, 180.0, 0.5],
  ["Sun specular", "sun/light_specular", "number", 0.0, 2.0, 0.01],
  ["Color adjustment", "env/adjustment_enabled", "bool"],
  ["Contrast", "env/adjustment_contrast", "number", 0.5, 1.5, 0.01],
  ["Saturation", "env/adjustment_saturation", "number", 0.0, 2.0, 0.01],
 ],
 "Sky": [],
 "Palette": [],
 "Hue": [],
 "Glow & Fog": [
  ["Glow enabled", "env/glow_enabled", "bool"],
  ["Glow intensity", "env/glow_intensity", "number", 0.0, 2.0, 0.01],
  ["Glow spread", "env/glow_strength", "number", 0.1, 2.0, 0.01],
  ["Tight halo", "env/glow_levels/3", "number", 0.0, 1.0, 0.01],
  ["Wide / soft halo", "env/glow_levels/5", "number", 0.0, 1.0, 0.01],
  ["Diffuse halo", "env/glow_levels/7", "number", 0.0, 1.0, 0.01],
  ["Normalize halo brightness", "env/glow_normalized", "bool"],
  ["Bloom", "env/glow_bloom", "number", 0.0, 1.0, 0.005],
  ["Glow threshold", "env/glow_hdr_threshold", "number", 0.0, 4.0, 0.01],
  ["Emission multiplier", "emission", "number", 0.0, 3.0, 0.01],
  ["Surface halo width", "surface_halo_spread", "number", 0.25, 2.0, 0.01],
  ["Fog enabled", "env/fog_enabled", "bool"],
  ["Fog mode", "env/fog_mode", "fog_mode"],
  ["Fog density", "env/fog_density", "number", 0.0, 1.0, 0.0005],
  ["Start distance (3D units)", "env/fog_depth_begin", "number", 0.0, 1000.0, 0.5],
  ["End distance (0 = far)", "env/fog_depth_end", "number", 0.0, 2000.0, 0.5],
  ["Depth density curve", "env/fog_depth_curve", "number", 0.1, 8.0, 0.05],
  ["Fog color", "env/fog_light_color", "color"],
  ["Fog brightness", "env/fog_light_energy", "number", 0.0, 3.0, 0.01],
  ["Fog sky influence", "env/fog_sky_affect", "number", 0.0, 1.0, 0.01],
 ],
 "Directional Fog": preload("res://scripts/atmosphere/directional_fog.gd").FIELDS,
 "Shadows": [
  ["Shadows enabled", "sun/shadow_enabled", "bool"],
  ["Opacity", "sun/shadow_opacity", "number", 0.0, 1.0, 0.01],
  ["Softness (Forward+)", "sun/light_angular_distance", "number", 0.0, 5.0, 0.05],
  ["Depth bias", "sun/shadow_bias", "number", 0.0, 2.0, 0.01],
  ["Normal bias", "sun/shadow_normal_bias", "number", 0.0, 8.0, 0.05],
  ["Shadow distance", "sun/directional_shadow_max_distance", "number", 10.0, 500.0, 1.0],
  ["Shadow maps", "sun/directional_shadow_mode", "shadow"],
 ],
 "Scenery": [],
}
const PROCEDURAL_SKY_FIELDS := [
 ["Sky top", "sky/sky_top_color", "color"],
 ["Sky horizon", "sky/sky_horizon_color", "color"],
 ["Ground / bottom", "sky/ground_bottom_color", "color"],
 ["Ground horizon", "sky/ground_horizon_color", "color"],
 ["Sky horizon blend", "sky/sky_curve", "number", 0.01, 1.0, 0.01],
 ["Ground horizon blend", "sky/ground_curve", "number", 0.01, 1.0, 0.01],
]

const HUE_FIELDS := [
 ["Decor hue", "hue/decor", "number", -0.7, 0.7, 0.005],
 ["Decor saturation", "saturation/decor", "number", 0.0, 2.0, 0.01],
 ["Decor brightness", "brightness/decor", "number", 0.0, 3.0, 0.01],
 ["Override ground floor", "override/terrain_ground", "bool"],
 ["Ground floor hue", "hue/terrain_ground", "number", -0.7, 0.7, 0.005],
 ["Ground floor saturation", "saturation/terrain_ground", "number", 0.0, 2.0, 0.01],
 ["Ground floor brightness", "brightness/terrain_ground", "number", 0.0, 3.0, 0.01],
 ["Override raised tops / upper floor", "override/terrain_upper", "bool"],
 ["Raised tops / upper floor hue", "hue/terrain_upper", "number", -0.7, 0.7, 0.005],
 ["Raised tops / upper floor saturation", "saturation/terrain_upper", "number", 0.0, 2.0, 0.01],
 ["Raised tops / upper floor brightness", "brightness/terrain_upper", "number", 0.0, 3.0, 0.01],
 ["Override walls / cliffs", "override/terrain_walls", "bool"],
 ["Walls / cliffs hue", "hue/terrain_walls", "number", -0.7, 0.7, 0.005],
 ["Walls / cliffs saturation", "saturation/terrain_walls", "number", 0.0, 2.0, 0.01],
 ["Walls / cliffs brightness", "brightness/terrain_walls", "number", 0.0, 3.0, 0.01],
 ["Override ledges / borders / edges", "override/terrain_borders", "bool"],
 ["Ledges / borders / edges hue", "hue/terrain_borders", "number", -0.7, 0.7, 0.005],
 ["Ledges / borders / edges saturation", "saturation/terrain_borders", "number", 0.0, 2.0, 0.01],
 ["Ledges / borders / edges brightness", "brightness/terrain_borders", "number", 0.0, 3.0, 0.01],

 ["Neon hue", "hue/neon", "number", -0.7, 0.7, 0.005],
 ["Neon saturation", "saturation/neon", "number", 0.0, 2.0, 0.01],
 ["Neon brightness", "brightness/neon", "number", 0.0, 3.0, 0.01],
 ["Terrain hue", "hue/terrain", "number", -0.7, 0.7, 0.005],
 ["Terrain saturation", "saturation/terrain", "number", 0.0, 2.0, 0.01],
 ["Terrain brightness", "brightness/terrain", "number", 0.0, 3.0, 0.01],
 ["Background hue", "hue/background", "number", -0.7, 0.7, 0.005],
 ["Background saturation", "saturation/background", "number", 0.0, 2.0, 0.01],
 ["Background brightness", "brightness/background", "number", 0.0, 3.0, 0.01],
 ["Foliage hue", "hue/foliage", "number", -0.7, 0.7, 0.005],
 ["Foliage saturation", "saturation/foliage", "number", 0.0, 2.0, 0.01],
 ["Foliage brightness", "brightness/foliage", "number", 0.0, 3.0, 0.01],
]
static func specs(theme: String) -> Dictionary:
 var result := {}
 for group: Array in GROUPS.values():
  for field: Array in group: result[field[1]] = field
 for field: Array in PROCEDURAL_SKY_FIELDS + HUE_FIELDS + preload("res://scripts/atmosphere/color_ranges.gd").fields() + preload("res://scripts/themes/theme_atmosphere.gd").fields(theme): result[field[1]] = field
 for field: Array in preload("res://scripts/atmosphere/color_ranges.gd").stack_fields(theme): result[field[1]] = field
 result["env/background_energy_multiplier"] = ["Background brightness", "env/background_energy_multiplier", "number", 0.0, 3.0, 0.01]
 result["env/background_color"] = ["Background color", "env/background_color", "color"]
 return result

static func valid_values(theme: String, values: Dictionary) -> bool:
 var allowed := specs(theme)
 for key: Variant in values:
  if not allowed.has(key): return false
  var spec: Array = allowed[key]
  var value: Variant = values[key]
  match spec[2]:
   "color":
    if not value is Color or not is_finite(value.r) or not is_finite(value.g) or not is_finite(value.b) or not is_finite(value.a): return false
   "bool":
    if not value is bool: return false
   "number":
    if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) or value < spec[3] or value > spec[4]: return false
   "tone", "shadow":
    if not value is int or value < 0 or value > (4 if spec[2] == "tone" else 2): return false
   "fog_mode":
    if not value is int or value not in [0, 1]: return false
 return true
