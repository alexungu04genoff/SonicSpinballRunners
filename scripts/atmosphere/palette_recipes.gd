extends RefCounted
## Tint large environmental surfaces in the same light as the procedural sky.
## Palette roles target scenery and scenery lights. Character materials keep their authored colors.

static func apply(theme: String, top: Color, horizon: Color, key: Color, night: bool, values: Dictionary) -> void:
 match theme:
  "green_hill":
   values["palette/ocean_deep"] = Color("12687a").lerp(top, 0.40)
   values["palette/ocean_wave"] = Color("31aeab").lerp(horizon, 0.34)
   values["palette/ocean_reflection"] = horizon.lerp(Color("b6e6de"), 0.24)
   values["palette/ocean_sun"] = key
   values["palette/cloud_shadow"] = top.lerp(horizon, 0.43)
   values["palette/cloud_highlight"] = key.lerp(horizon, 0.25)
   if night:
    # Moonlit turf and surf carry the time of day even in the overhead camera.
    for surface: String in ["terrain_ground", "terrain_upper"]:
     values["override/" + surface] = true
     values["hue/" + surface] = 0.075
     values["saturation/" + surface] = 0.84
    values["hue/foliage"] = 0.055
    values["palette/ocean_deep"] = Color("173552").lerp(top, 0.35)
    values["palette/ocean_wave"] = Color("32638a").lerp(horizon, 0.24)
    values["palette/ocean_reflection"] = Color("a1c6eb").lerp(horizon, 0.4)
    values["palette/local_sand"] = Color("c0b9ad").lerp(key, 0.12)
    values["palette/shore_tint"] = Color("b5bfd2")
  "casino_night":
   # A lighter, less saturated deck separates dark quills and purple fur from the blue tiles.
   if night:
    values["override/terrain_ground"] = true
    values["brightness/terrain_ground"] = 1.22
    values["saturation/terrain_ground"] = 0.78
   values["palette/skyline_tint"] = Color.WHITE.lerp(top, 0.27)
   values["palette/marquee"] = Color("ffe4aa").lerp(key, 0.38)
   values["palette/warm_spill"] = Color("ffaaa0").lerp(horizon, 0.26)
   values["palette/blue_spill"] = Color("8aaafa").lerp(top, 0.27)
   values["palette/neon_pink"] = Color("ff519f").lerp(horizon, 0.18)
   values["palette/neon_aqua"] = Color("4ce4f6").lerp(top, 0.15)
  "ice_cap":
   values["palette/ice_upper"] = top
   values["palette/ice_horizon"] = horizon
   values["palette/ice_sky_glow"] = Color("5dada8").lerp(horizon, 0.22)
   values["palette/lake_base"] = Color("326a88").lerp(top, 0.40)
   values["palette/lake_reflection"] = Color("91dcd5").lerp(horizon, 0.38)
   values["palette/aurora_strength"] = 1.12 if night else 0.62
   values["palette/star_intensity"] = 1.16 if night else 0.25
  "rooftop_run":
   values["palette/distant_haze"] = horizon
   values["palette/canal_deep"] = Color("376d81").lerp(top, 0.38)
   values["palette/canal_reflection"] = Color("b5dada").lerp(horizon, 0.58)
   values["palette/architecture_tint"] = Color.WHITE.lerp(key, 0.18)
   values["palette/roof_tint"] = Color.WHITE.lerp(horizon, 0.18)
  "aquarium_park":
   values["palette/lagoon_deep"] = Color("105669").lerp(top, 0.35)
   values["palette/lagoon_wave"] = Color("258e99").lerp(horizon, 0.28)
   values["palette/water_reflection"] = horizon.lerp(Color("8ed5d6"), 0.40)
   values["palette/caustic"] = Color("79ddc5").lerp(horizon, 0.25)
   values["palette/lantern_reflection"] = Color("ffba83").lerp(key, 0.22)
   values["palette/lantern_emission"] = Color("ffb279").lerp(key, 0.20)
