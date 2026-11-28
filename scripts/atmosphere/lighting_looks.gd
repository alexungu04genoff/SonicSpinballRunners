extends RefCounted
## Selectable lighting recipes shared by Atmosphere Lab and Prototype.

const Palette := preload("res://scripts/atmosphere/palette_recipes.gd")
const LOOKS := {
 "Arcade daylight": {
  "fill": "c4d2f5", "key": "ffe0a2", "zenith": "469dd4", "horizon": "f7dfaa",
  "ambient": 0.81, "sun": 1.22, "pitch": -32, "yaw": 43,
  "fog": 0.28, "glow": 0.16, "cast": 4, "ao": 14, "radius": 0.44,
 },
 "Daytime": {
  "fill": "d4e3ef", "key": "fff3d3", "zenith": "439ed2", "horizon": "d6ece8",
  "ambient": 0.84, "sun": 1.02, "pitch": -61, "yaw": -28,
  "fog": 0.25, "glow": 0.1, "cast": 8, "ao": 12, "radius": 0.38,
 },
 "Morning": {
  "fill": "c5dce8", "key": "ffe0bd", "zenith": "679fc0", "horizon": "f3c8ae",
  "ambient": 0.88, "sun": 0.99, "pitch": -34, "yaw": -59,
  "fog": 0.4, "glow": 0.17, "cast": 5, "ao": 12.75, "radius": 0.4,
 },
 "Golden hour": {
  "fill": "cacfec", "key": "ffd39e", "zenith": "7294bf", "horizon": "ffd392",
  "ambient": 0.87, "sun": 1.14, "pitch": -30, "yaw": 52,
  "fog": 0.38, "glow": 0.23, "cast": 5, "ao": 13.5, "radius": 0.43,
 },
 "Sunset": {
  "fill": "cccae5", "key": "ffc6a4", "zenith": "52578b", "horizon": "ef9e91",
  "ambient": 0.94, "sun": 1.04, "pitch": -28, "yaw": 62,
  "fog": 0.43, "glow": 0.22, "cast": 5, "ao": 14, "radius": 0.45,
 },
 "Dusk": {
  "fill": "cccee8", "key": "f4cee9", "zenith": "3d487b", "horizon": "b18aa5",
  "ambient": 0.97, "sun": 0.89, "pitch": -37, "yaw": 34,
  "fog": 0.39, "glow": 0.25, "cast": 0, "ao": 13.5, "radius": 0.43,
 },
 "Blue hour": {
  "fill": "bfd6ef", "key": "efdff5", "zenith": "344e86", "horizon": "809ac1",
  "ambient": 1.01, "sun": 0.9, "pitch": -42, "yaw": -54,
  "fog": 0.36, "glow": 0.22, "cast": 0, "ao": 13, "radius": 0.44,
 },
 "Night": {
  "fill": "c2d4ee", "key": "e3e9ff", "zenith": "182a51", "horizon": "526780",
  "ambient": 1, "sun": 0.88, "pitch": -47, "yaw": 39,
  "fog": 0.3, "glow": 0.28, "cast": 0, "ao": 14, "radius": 0.42,
 },
 "Moonlit": {
  "fill": "bad6ea", "key": "eaf5ff", "zenith": "22436a", "horizon": "80a7bb",
  "ambient": 0.95, "sun": 1.04, "pitch": -37, "yaw": -49,
  "fog": 0.38, "glow": 0.21, "cast": 8, "ao": 14, "radius": 0.45,
 },
 "Indoors": {
  "fill": "dcd6c9", "key": "fff0c3", "zenith": "4b5269", "horizon": "a59186",
  "ambient": 0.91, "sun": 1.03, "pitch": -68, "yaw": -24,
  "fog": 0.23, "glow": 0.23, "cast": 4, "ao": 14.5, "radius": 0.39,
 },
 "Overcast": {
  "fill": "d3dfe7", "key": "faf5dc", "zenith": "718ba1", "horizon": "bacbd1",
  "ambient": 1.02, "sun": 0.78, "pitch": -54, "yaw": -38,
  "fog": 0.48, "glow": 0.1, "cast": 0, "ao": 13.75, "radius": 0.48,
 },
 "Stormfront": {
  "fill": "b9d2e0", "key": "fff0c8", "zenith": "344c64", "horizon": "869a97",
  "ambient": 0.98, "sun": 1.06, "pitch": -34, "yaw": 70,
  "fog": 0.54, "glow": 0.18, "cast": 5, "ao": 15, "radius": 0.49,
 },
 "Neon night": {
  "fill": "c6cee8", "key": "f6d2ec", "zenith": "262147", "horizon": "76618e",
  "ambient": 1.01, "sun": 0.88, "pitch": -46, "yaw": -38,
  "fog": 0.33, "glow": 0.49, "cast": 4, "ao": 13.75, "radius": 0.38,
 },
 "Neutral inspection": {
  "fill": "e7ebef", "key": "fffdf6", "zenith": "8296ad", "horizon": "c1cad3",
  "ambient": 0.9, "sun": 0.91, "pitch": -50, "yaw": -30,
  "fog": 0, "glow": 0, "cast": 0, "ao": 12, "radius": 0.39,
 },
}

# Each signature starts with a time of day, then sets its own light and environmental pigments.
const SIGNATURES := {
 "green_hill": {
  "Mango Tide": {"pitch": -23, "yaw": 58, "fog": 0.32, "mood": "Sunset", "fill": "cfdae9", "key": "ffcb91", "zenith": "6485b6", "horizon": "ffb66f",
   "palette": {"ocean_deep": "175d6c", "ocean_wave": "38ac9d", "ocean_sun": "ffdb8d"}},
  "Firefly Cove": {"yaw": -54, "glow": 0.34, "mood": "Night", "fill": "c5e2de", "key": "eaf8bd", "zenith": "193b4b", "horizon": "65958a",
   "palette": {"ocean_wave": "328b7c", "ocean_sun": "d6ed9b", "cloud_highlight": "a6ceba"}},
  "Rainwashed Palms": {"pitch": -39, "radius": 0.46, "mood": "Stormfront", "fill": "c0dfeb", "key": "fff0a5", "zenith": "436579", "horizon": "a7cbbb",
   "palette": {"ocean_deep": "176876", "ocean_reflection": "a7d5c7", "cloud_shadow": "749baf"}},
 },
 "casino_night": {
  "Cherry Jackpot": {"yaw": -42, "glow": 0.38, "mood": "Sunset", "fill": "dbd2ef", "key": "ffd0cb", "zenith": "63396f", "horizon": "e48296",
   "palette": {"neon_pink": "ff5c89", "blue_spill": "839cf7", "marquee": "ffdeac"}},
  "Mint Condition": {"pitch": -63, "cast": 5, "mood": "Neon night", "fill": "bae0e8", "key": "edffef", "zenith": "1c3657", "horizon": "6aaba4",
   "palette": {"neon_aqua": "49e2eb", "neon_mint": "a2f7b7", "purple_accent": "6d64a7"}},
  "After the Encore": {"pitch": -54, "glow": 0.30, "mood": "Indoors", "fill": "c6d3ec", "key": "ffe3b8", "zenith": "35365f", "horizon": "a78da5",
   "palette": {"skyline_tint": "a4a1c1", "marquee": "ffedb8", "warm_spill": "ffb789"}},
 },
 "ice_cap": {
  "Sundog Halo": {"yaw": -62, "glow": 0.18, "mood": "Golden hour", "fill": "c3d7ed", "key": "ffd7b7", "zenith": "8896c6", "horizon": "ffd4bb",
   "palette": {"lake_base": "426788", "lake_reflection": "f5c7c5", "crystal_tint": "f7e5f5"}},
  "Magnetic Midnight": {"pitch": -31, "radius": 0.50, "mood": "Night", "fill": "bfd9ec", "key": "e8daff", "zenith": "1d2a59", "horizon": "8494b7",
   "palette": {"aurora_primary": "75ffc2", "aurora_secondary": "7bbaff", "aurora_tertiary": "d389ef", "aurora_strength": 1.32}},
  "Diamond Dust": {"fog": 0.43, "glow": 0.19, "mood": "Overcast", "fill": "cbdfea", "key": "f4f1ff", "zenith": "739eb7", "horizon": "cee4e8",
   "palette": {"ice_sky_glow": "9cc9d1", "crystal_tint": "d4f8ff", "lake_base": "3d7891"}},
 },
 "rooftop_run": {
  "Bell Tower Blush": {"pitch": -24, "yaw": 51, "mood": "Sunset", "fill": "d4d4e8", "key": "ffceac", "zenith": "767ca6", "horizon": "efaaa1",
   "palette": {"roof_tint": "ffcfaa", "canal_reflection": "e7bac5", "distant_haze": "deb7b4"}},
  "Rain on Terracotta": {"yaw": -68, "radius": 0.46, "mood": "Stormfront", "fill": "c4d6ed", "key": "ffe9cc", "zenith": "4d607d", "horizon": "a7adb5",
   "palette": {"roof_tint": "eec6bd", "canal_deep": "416a78", "distant_haze": "a3aebc"}},
  "Festival of Kites": {"pitch": -46, "fog": 0.28, "mood": "Morning", "fill": "cddeef", "key": "ffe5a9", "zenith": "4d9fc3", "horizon": "f6d2a1",
   "palette": {"architecture_tint": "fff0d9", "canal_reflection": "97d7d6", "vegetation_tint": "d5eab9"}},
 },
 "aquarium_park": {
  "Lantern Parade": {"pitch": -55, "glow": 0.40, "mood": "Dusk", "fill": "c6dce6", "key": "ffd9b4", "zenith": "344f79", "horizon": "c8929a",
   "palette": {"lantern_emission": "ffaa62", "lantern_paper": "ffce94", "lantern_reflection": "efae7c", "lagoon_deep": "115669"}},
  "Koi Moon": {"yaw": 64, "fog": 0.33, "mood": "Moonlit", "fill": "bfdfdf", "key": "f4ead8", "zenith": "214863", "horizon": "8cb9b6",
   "palette": {"water_reflection": "a2d5d0", "lagoon_wave": "329a92", "coral": "ff9b8d"}},
  "Sea Glass Morning": {"pitch": -39, "cast": 8, "mood": "Morning", "fill": "c3e5e3", "key": "fff1bf", "zenith": "538fa1", "horizon": "bde4c9",
   "palette": {"glass_base": "5cb6be", "caustic": "81e6bb", "lagoon_deep": "22687d"}},
 },
 "egg_fleet": {
  "Signal Flare": {"pitch": -29, "glow": 0.34, "mood": "Sunset", "fill": "cdd6e4", "key": "ffcd97", "zenith": "685581", "horizon": "efaa83"},
  "Searchlight Watch": {"pitch": -52, "cast": 4, "mood": "Night", "fill": "bcd6ec", "key": "f1f3d6", "zenith": "293c5b", "horizon": "698699"},
  "Cloudbreak Convoy": {"yaw": -58, "fog": 0.40, "mood": "Stormfront", "fill": "c4d9e6", "key": "ffe6ac", "zenith": "566d80", "horizon": "acc9ca"},
 },
}

# Snow needs less direct light than grass or metal to retain its surface detail.
const SUN_RESPONSE := {"green_hill": 1.02, "casino_night": 0.92, "ice_cap": 0.62,
 "rooftop_run": 1.05, "aquarium_park": 0.84, "egg_fleet": 0.94}

static func titles(theme: String) -> Array:
 return LOOKS.keys() + SIGNATURES.get(theme, {}).keys()

static func preset_id(title: String) -> String:
 return "look_" + title.to_snake_case()

static func create(title: String, base: Dictionary, theme: String) -> Dictionary:
 var signature: Dictionary = SIGNATURES.get(theme, {}).get(title, {})
 var mood: String = signature.get("mood", title)
 var result := base.duplicate(true)
 if not LOOKS.has(mood): return result
 var look: Dictionary = LOOKS[mood].merged(signature, true)
 var horizon := Color(look.horizon)
 var top := Color(look.zenith)
 var neutral := mood == "Neutral inspection"
 var night := mood in ["Night", "Moonlit", "Neon night", "Dusk", "Blue hour"]
 result.merge({
  "env/tonemap_mode": Environment.TONE_MAPPER_LINEAR, "env/tonemap_exposure": 1.04,
  "env/ambient_light_energy": float(look.ambient), "env/ambient_light_color": Color(look.fill),
  "env/ambient_light_sky_contribution": 0.0, "env/background_energy_multiplier": 1.0,
  "sun/light_energy": float(look.sun) * float(SUN_RESPONSE.get(theme, 1.0)),
  "sun/light_color": Color(look.key), "sun_pitch": float(look.pitch), "sun_yaw": float(look.yaw),
  "sun/light_specular": 0.72 if neutral else 0.84,
  "env/adjustment_enabled": not neutral, "env/adjustment_contrast": 1.025, "env/adjustment_saturation": 1.035,
  "sun/shadow_enabled": true, "sun/shadow_opacity": 0.84, "sun/shadow_blur": 6.5 if look.cast == 0 else 3.5,
  "shadow/levels": look.cast, "ssao/levels": 0, "ssao/strength": float(look.ao),
  "ssao/radius": float(look.radius), "ssao/contrast": 1.90 if night else 1.75,
  "env/fog_enabled": not neutral, "env/fog_mode": Environment.FOG_MODE_DEPTH,
  "env/fog_density": float(look.fog), "env/fog_depth_begin": 5.5, "env/fog_depth_end": 32.0,
  "env/fog_depth_curve": 1.6, "env/fog_light_color": horizon, "env/fog_light_energy": 0.86,
  "env/fog_sky_affect": 0.08, "directional_fog/enabled": not neutral and (mood == "Stormfront" or theme in ["ice_cap", "aquarium_park"]),
  "directional_fog/angle": float(look.yaw) * 0.4, "directional_fog/start": 250.0,
  "directional_fog/length": 900.0, "directional_fog/density": float(look.fog) * 0.42,
  "directional_fog/curve": 1.5, "directional_fog/color": horizon, "directional_fog/brightness": 0.88,
  "env/glow_enabled": not neutral, "env/glow_intensity": float(look.glow), "env/glow_hdr_threshold": 1.22,
  "env/glow_strength": 1.08, "env/glow_normalized": true, "env/glow_bloom": 0.0,
  "env/glow_levels/3": 0.5, "env/glow_levels/5": 0.37, "env/glow_levels/7": 0.13,
  "emission": 1.06 if night else 0.82,
 }, true)
 if theme == "egg_fleet":
  result["env/background_color"] = horizon.lerp(top, 0.55)
 elif theme != "ice_cap":
  result["sky/sky_top_color"] = top
  result["sky/sky_horizon_color"] = horizon
  result["sky/ground_horizon_color"] = horizon
  result["sky/ground_bottom_color"] = top.darkened(0.24)
  result["sky/sky_curve"] = 0.32
  result["sky/ground_curve"] = 0.3
 if not neutral:
  Palette.apply(theme, top, horizon, Color(look.key), night, result)
  for role: String in signature.get("palette", {}):
   var value: Variant = signature.palette[role]
   result["palette/" + role] = Color(value) if value is String else value
 return result
