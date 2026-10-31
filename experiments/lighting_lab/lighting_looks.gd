extends RefCounted
## Quick art directions relative to each theme's authored lighting, not production defaults.
## Keep shadow quality, material geometry and physics unchanged when choosing a look.
const LOOKS := {
 "Daytime": {"ambient": 1.1, "ambient_color": "dceaff", "sun": 1.05, "sun_color": "fff5e5", "pitch": -55.0, "yaw": -30.0, "exposure": 1.0, "sky": 1.0, "emission": 0.8, "glow": 0.6},
 "Morning": {"ambient": 0.85, "ambient_color": "b8cbe8", "sun": 0.9, "sun_color": "ffe0b8", "pitch": -28.0, "yaw": -55.0, "exposure": 0.98, "sky": 0.8, "emission": 0.8, "glow": 0.6},
 "Golden hour": {"ambient": 0.85, "ambient_color": "c1b6d6", "sun": 1.05, "sun_color": "ffcd8c", "pitch": -28.0, "yaw": 45.0, "exposure": 0.98, "sky": 0.85, "emission": 0.8, "glow": 0.6},
 "Sunset": {"ambient": 0.65, "ambient_color": "a7a0cc", "sun": 1.0, "sun_color": "ffb875", "pitch": -18.0, "yaw": 55.0, "exposure": 0.9, "sky": 0.48, "emission": 0.9, "glow": 0.75},
 "Dusk": {"ambient": 0.55, "ambient_color": "939bc9", "sun": 0.4, "sun_color": "dfadce", "pitch": -12.0, "yaw": 65.0, "exposure": 0.88, "sky": 0.3, "emission": 0.75, "glow": 0.8},
 "Blue hour": {"ambient": 0.65, "ambient_color": "809bc9", "sun": 0.2, "sun_color": "c1caef", "pitch": -10.0, "yaw": 65.0, "exposure": 0.9, "sky": 0.55, "emission": 0.9, "glow": 0.8},
 "Night": {"ambient": 0.35, "ambient_color": "7895cb", "sun": 0.18, "sun_color": "adc8ff", "pitch": -40.0, "yaw": -35.0, "exposure": 0.82, "sky": 0.12, "emission": 0.55, "glow": 0.7},
 "Moonlit": {"ambient": 0.65, "ambient_color": "93aed4", "sun": 0.5, "sun_color": "c5daff", "pitch": -38.0, "yaw": -50.0, "exposure": 0.95, "sky": 0.3, "emission": 0.7, "glow": 0.65},
 "Indoors": {"ambient": 1.25, "ambient_color": "dfc8aa", "sun": 0.35, "sun_color": "ffe1b0", "pitch": -70.0, "yaw": -15.0, "exposure": 0.95, "sky": 0.12, "emission": 0.85, "glow": 0.65},
 "Overcast": {"ambient": 1.35, "ambient_color": "c1cddd", "sun": 0.4, "sun_color": "edf2ff", "pitch": -55.0, "yaw": -30.0, "exposure": 0.95, "sky": 0.65, "emission": 0.7, "glow": 0.4},
 "Stormfront": {"ambient": 0.95, "ambient_color": "9daec5", "sun": 0.22, "sun_color": "ccd5e5", "pitch": -50.0, "yaw": -30.0, "exposure": 0.88, "sky": 0.5, "emission": 0.8, "glow": 0.55},
 "Neon night": {"ambient": 0.28, "ambient_color": "777ca8", "sun": 0.12, "sun_color": "a1c7ef", "pitch": -45.0, "yaw": -30.0, "exposure": 0.8, "sky": 0.08, "emission": 1.4, "glow": 1.1},
 "Neutral inspection": {"ambient": 1.1, "ambient_color": "ffffff", "sun": 0.85, "sun_color": "ffffff", "pitch": -50.0, "yaw": -30.0, "exposure": 1.0, "sky": 1.0, "emission": 1.0, "glow": 0.0},
}
# Shared palette recipes are applied only to properties present in the current
# theme's baseline. Theme-owned shader colors have separate semantic recipes.
# Daytime/Neutral keep the authored palette; all values remain editable in the lab.
const SKY_PALETTES := {
 "Morning": {"top": "477ca5", "horizon": "f5c8b2", "bottom": "526779", "curve": 0.25, "brightness": 0.9, "solid": "302637"},
 "Golden hour": {"top": "476c9e", "horizon": "ffd29c", "bottom": "635060", "curve": 0.3, "brightness": 0.9, "solid": "302330"},
 "Sunset": {"top": "303c72", "horizon": "ef9b83", "bottom": "463047", "curve": 0.3, "brightness": 0.8, "solid": "231322"},
 "Dusk": {"top": "192747", "horizon": "8b6387", "bottom": "221c38", "curve": 0.25, "brightness": 0.75, "solid": "111121"},
 "Blue hour": {"top": "152641", "horizon": "4e648c", "bottom": "1c2440", "curve": 0.28, "brightness": 0.8, "solid": "0b1428"},
 "Night": {"top": "050e22", "horizon": "202d4c", "bottom": "080f22", "curve": 0.2, "brightness": 0.7, "solid": "030611"},
 "Moonlit": {"top": "0c1c38", "horizon": "456082", "bottom": "15243b", "curve": 0.23, "brightness": 0.85, "solid": "081225"},
 "Indoors": {"top": "302830", "horizon": "685449", "bottom": "211c24", "curve": 0.3, "brightness": 0.5, "solid": "181219"},
 "Overcast": {"top": "748397", "horizon": "bac0ca", "bottom": "505b6c", "curve": 0.4, "brightness": 0.8, "solid": "202631"},
 "Stormfront": {"top": "253349", "horizon": "70798d", "bottom": "202b3c", "curve": 0.4, "brightness": 0.7, "solid": "101725"},
 "Neon night": {"top": "030611", "horizon": "141326", "bottom": "03050d", "curve": 0.25, "brightness": 0.6, "solid": "02030a"},
}

static func create(title: String, authored: Dictionary, theme := "") -> Dictionary:
 var result := authored.duplicate(true)
 if not LOOKS.has(title): return result
 var look: Dictionary = LOOKS[title]
 result["env/tonemap_exposure"] = float(authored["env/tonemap_exposure"]) * float(look.exposure)
 result["env/ambient_light_energy"] = float(authored["env/ambient_light_energy"]) * float(look.ambient)
 result["env/ambient_light_color"] = Color(look.ambient_color)
 result["env/ambient_light_sky_contribution"] = 0.0 if title == "Neutral inspection" else 0.15
 result["sun/light_energy"] = float(authored["sun/light_energy"]) * float(look.sun)
 result["sun/light_color"] = Color(look.sun_color)
 result["sun_pitch"] = look.pitch
 result["sun_yaw"] = look.yaw
 result["env/background_energy_multiplier"] = float(authored["env/background_energy_multiplier"]) * float(look.sky)
 result["emission"] = look.emission
 result["env/glow_enabled"] = title != "Neutral inspection" and (bool(authored["env/glow_enabled"]) or title in ["Night", "Neon night"])
 result["env/glow_intensity"] = float(authored["env/glow_intensity"]) * float(look.glow)
 result["env/fog_enabled"] = false
 result["env/adjustment_enabled"] = false
 if title == "Neutral inspection": result["env/tonemap_mode"] = Environment.TONE_MAPPER_LINEAR
 if SKY_PALETTES.has(title):
  var palette: Dictionary = SKY_PALETTES[title]
  if authored.has("sky/sky_top_color"):
   result["sky/sky_top_color"] = Color(palette.top)
   result["sky/sky_horizon_color"] = Color(palette.horizon)
   result["sky/ground_bottom_color"] = Color(palette.bottom)
   # Match both sides of the horizon to avoid a hard seam in sky-facing views.
   result["sky/ground_horizon_color"] = Color(palette.horizon)
   result["sky/sky_curve"] = float(palette.curve)
   result["sky/ground_curve"] = float(palette.curve)
   # Palette colors already encode darkness; do not dim them a second time
   # with the stronger multiplier used for an unchanged custom shader sky.
   result["env/background_energy_multiplier"] = float(authored["env/background_energy_multiplier"]) * float(palette.brightness)
  elif authored.has("env/background_color"):
   result["env/background_color"] = Color(palette.solid)
   result["env/background_energy_multiplier"] = float(authored["env/background_energy_multiplier"]) * float(palette.brightness)
 preload("res://experiments/lighting_lab/palette_recipes.gd").apply(title, theme, result)
 if authored.has("palette/ice_horizon") and SKY_PALETTES.has(title):
  # Ice's palette encodes darkness too; avoid multiplying by the old recipe
  # intended for a fixed-color custom sky.
  result["env/background_energy_multiplier"] = float(authored["env/background_energy_multiplier"]) * float(SKY_PALETTES[title].brightness)
 return result
