extends RefCounted
## Shared image layouts for the six converted themes. Distances are world units.
const SETS := {
 "chemical_plant": {"source": "chemical", "emission_scale": 1.0, "floor": Vector2(3, 3), "wall": 1.5, "ramp": Vector2(1, 0.68), "normalized_ramp": true, "width": Vector2(6, 4)},
 "casino_night": {"source": "casino", "emission_scale": 4.0, "floor": Vector2(10.0 / 3.0, 10.0 / 3.0), "wall": 10.0 / 7.0, "ramp": Vector2(1, 2.2), "normalized_ramp": true, "width": Vector2(6, 4)},
 "sky_sanctuary": {"source": "sanctuary", "emission_scale": 1.0, "floor": Vector2(7, 5), "wall": 3.4, "ramp": Vector2(0.48, 0.44), "width": Vector2(7, 5)},
 "ice_cap": {"source": "ice", "emission_scale": 0.125, "floor": Vector2(8, 8), "wall": 4.0, "ramp": Vector2(8, 8), "width": Vector2(6, 4)},
 "lava_reef": {"source": "lava", "emission_scale": 0.5, "floor": Vector2(8.0 / 2.1, 8.0 / 2.1), "wall": 3.2, "ramp": Vector2(8.0 / 2.1, 8.0 / 2.1), "width": Vector2(7, 5)},
 "aquarium_park": {"source": "aquarium", "emission_scale": 0.25, "floor": Vector2(6.0 / 1.15, 7.5), "wall": 20.0 / 11.0, "ramp": Vector2(6.0 / 1.15, 7.5), "width": Vector2(4, 2)},
}
const DEPTH := 1.6

static func material(theme: String, surface: String) -> ShaderMaterial:
 var layout: Dictionary = SETS[theme]
 var result := ShaderMaterial.new()
 result.shader = preload("res://scripts/themes/terrain_texture.gdshader")
 var folder := "res://assets/textures/" + theme + "/" + surface
 for map: String in ["albedo", "emission", "surface"]:
  var suffix := "" if map == "albedo" else "-" + map
  result.set_shader_parameter(map + "_texture", load(folder + suffix + ".png"))
 var mode := 0
 var repeat_size: Vector2 = layout.floor
 if surface in ["wall", "facade"]:
  mode = 1
  repeat_size = Vector2(layout.wall, DEPTH)
  result.set_shader_parameter("top_height", 0.0 if surface == "facade" else 0.325)
 elif surface.ends_with("border"):
  mode = 2
  repeat_size = Vector2.ONE
 elif surface == "ramp":
  mode = 4 if layout.get("normalized_ramp", false) else 3
  repeat_size = layout.ramp
 result.set_shader_parameter("emission_scale", layout.emission_scale)
 result.set_shader_parameter("mapping", mode)
 result.set_shader_parameter("repeat_size", repeat_size)
 result.set_shader_parameter("ice_fresnel", theme == "ice_cap" and surface in ["floor", "top", "ramp"])
 result.set_shader_parameter("normal_power", 6.0 if theme in ["ice_cap", "lava_reef"] else 8.0)
 return result
