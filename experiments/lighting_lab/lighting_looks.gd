extends RefCounted
## Quick art directions relative to each theme's authored lighting, not production defaults.
## Keep shadow quality, material geometry and physics unchanged when choosing a look.
const LOOKS := {
 "Daytime": {"ambient": 1.1, "ambient_color": "dceaff", "sun": 1.05, "sun_color": "fff5e5", "pitch": -55.0, "yaw": -30.0, "exposure": 1.0, "sky": 1.0, "emission": 0.8, "glow": 0.6},
 "Morning": {"ambient": 0.85, "ambient_color": "b8cbe8", "sun": 0.9, "sun_color": "ffe0b8", "pitch": -28.0, "yaw": -55.0, "exposure": 0.98, "sky": 0.8, "emission": 0.8, "glow": 0.6},
 "Sunset": {"ambient": 0.65, "ambient_color": "a7a0cc", "sun": 1.0, "sun_color": "ffb875", "pitch": -18.0, "yaw": 55.0, "exposure": 0.9, "sky": 0.48, "emission": 0.9, "glow": 0.75},
 "Dusk": {"ambient": 0.55, "ambient_color": "939bc9", "sun": 0.4, "sun_color": "dfadce", "pitch": -12.0, "yaw": 65.0, "exposure": 0.88, "sky": 0.3, "emission": 0.75, "glow": 0.8},
 "Night": {"ambient": 0.35, "ambient_color": "7895cb", "sun": 0.18, "sun_color": "adc8ff", "pitch": -40.0, "yaw": -35.0, "exposure": 0.82, "sky": 0.12, "emission": 0.55, "glow": 0.7},
 "Indoors": {"ambient": 1.25, "ambient_color": "dfc8aa", "sun": 0.35, "sun_color": "ffe1b0", "pitch": -70.0, "yaw": -15.0, "exposure": 0.95, "sky": 0.12, "emission": 0.85, "glow": 0.65},
 "Overcast": {"ambient": 1.35, "ambient_color": "c1cddd", "sun": 0.4, "sun_color": "edf2ff", "pitch": -55.0, "yaw": -30.0, "exposure": 0.95, "sky": 0.65, "emission": 0.7, "glow": 0.4},
 "Neon night": {"ambient": 0.28, "ambient_color": "777ca8", "sun": 0.12, "sun_color": "a1c7ef", "pitch": -45.0, "yaw": -30.0, "exposure": 0.8, "sky": 0.08, "emission": 1.4, "glow": 1.1},
 "Neutral inspection": {"ambient": 1.1, "ambient_color": "ffffff", "sun": 0.85, "sun_color": "ffffff", "pitch": -50.0, "yaw": -30.0, "exposure": 1.0, "sky": 1.0, "emission": 1.0, "glow": 0.0},
}

static func create(title: String, authored: Dictionary) -> Dictionary:
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
 return result
