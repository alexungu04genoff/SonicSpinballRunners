extends RefCounted
## Selective color adjustments shared by the Lab, saved variants and CPU colors.
## Adjacent ranges blend smoothly; low-saturation neutrals remain unchanged.
const IDS := ["red", "orange", "yellow", "green", "aqua", "blue", "purple", "magenta"]
const CENTERS := [0.0, 1.0 / 12.0, 1.0 / 6.0, 1.0 / 3.0, 0.5, 2.0 / 3.0, 0.75, 5.0 / 6.0, 1.0]

static func fields() -> Array:
 var result: Array = [["Enable color ranges", "ranges/enabled", "bool"]]
 for id: String in IDS:
  var label := id.capitalize()
  result.append([label + " hue", "ranges/" + id + "/hue", "number", -0.7, 0.7, 0.005])
  result.append([label + " saturation", "ranges/" + id + "/saturation", "number", 0.0, 2.0, 0.01])
  result.append([label + " brightness", "ranges/" + id + "/brightness", "number", 0.0, 3.0, 0.01])
 return result

static func neutral(key: String) -> Variant:
 if key.begins_with("stack/"): return true
 if key == "ranges/enabled": return false
 return 0.0 if key.ends_with("/hue") else 1.0

static func adjustment(values: Dictionary, id: String) -> Vector3:
 var prefix := "ranges/" + id + "/"
 return Vector3(float(values.get(prefix + "hue", 0.0)), float(values.get(prefix + "saturation", 1.0)), float(values.get(prefix + "brightness", 1.0)))

static func active(values: Dictionary) -> bool:
 if not values.get("ranges/enabled", false): return false
 for id: String in IDS:
  if adjustment(values, id) != Vector3(0.0, 1.0, 1.0): return true
 return false

static func apply(color: Color, values: Dictionary) -> Color:
 if not active(values) or color.s <= 0.03: return color
 var hue := color.h
 var index := 0
 while index < 7 and hue >= CENTERS[index + 1]: index += 1
 var blend := smoothstep(CENTERS[index], CENTERS[index + 1], hue)
 var settings := adjustment(values, IDS[index]).lerp(adjustment(values, IDS[(index + 1) % 8]), blend)
 settings = Vector3(0.0, 1.0, 1.0).lerp(settings, smoothstep(0.03, 0.12, color.s))
 if settings == Vector3(0.0, 1.0, 1.0): return color
 return Color.from_hsv(fposmod(hue + settings.x, 1.0), clampf(color.s * settings.y, 0.0, 1.0), color.v * settings.z, color.a)

static func stack_fields(theme: String) -> Array:
 var result: Array = []
 for id: String in ["ramps", "decor", "terrain", "terrain_ground", "terrain_upper", "terrain_walls", "terrain_borders", "terrain_edges", "terrain_ledges", "neon", "background", "foliage"]:
  result.append(["Stack with Hue", "stack/" + id, "bool"])
 for spec: Array in preload("res://scripts/themes/theme_atmosphere.gd").fields(theme):
  if spec[2] == "color": result.append(["Stack with Hue", "stack/" + spec[1], "bool"])
 return result

static func group_stacks(values: Dictionary, group: String) -> bool:
 group = linked_group(values, group)
 if group.begins_with("terrain_") and not values.get("stack/terrain", true): return false
 return values.get("stack/" + group, true)

static func linked_group(values: Dictionary, group: String) -> String:
 if group in ["terrain_edges", "terrain_ledges"] and values.get("link/terrain_trim", true): return "terrain_borders"
 return group

static func apply_uniforms(material: ShaderMaterial, values: Dictionary, allow := true) -> void:
 var enabled := allow and active(values)
 material.set_shader_parameter("atmosphere_ranges_enabled", enabled)
 if enabled:
  for id: String in IDS: material.set_shader_parameter("atmosphere_range_" + id, adjustment(values, id))
