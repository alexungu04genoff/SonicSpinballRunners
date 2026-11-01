extends RefCounted
## Share private copies for editable emission/palette materials; restore every slot.
## Only explicit semantic bindings are editable; changes reuse prepared programs.
const SCALES := ["emission_scale", "neon_strength", "radiance"]
const Palette := preload("res://scripts/themes/theme_atmosphere.gd")
const ColorRanges := preload("res://scripts/atmosphere/color_ranges.gd")
var slots: Array[Dictionary] = []
var seen_nodes := {}
var materials := {}
var scenery_materials := {}
var parameters: Array[Dictionary] = []
var halo_parameters: Array[Dictionary] = []
var palette_parameters: Array[Dictionary] = []
var palette_originals := {}
var cloud_lights: Array[Dictionary] = []
var allowed_keys: Array[String] = []
var last_palette := {}
var hue_parameters: Array[Dictionary] = []
var range_materials: Array[ShaderMaterial] = []
const NEON_KEYS := ["industrial_cyan", "signal_pink","neon_pink", "neon_aqua", "neon_mint", "neon_amber", "purple_accent", "window_gold", "marquee", "warm_spill", "blue_spill"]
const BACKGROUND_KEYS := ["ocean_deep", "ocean_wave", "ocean_reflection", "ocean_sun", "cloud_shadow", "cloud_highlight", "shore_tint", "reservoir_deep", "reservoir_ripple", "canal_deep", "canal_reflection", "distant_haze", "architecture_tint", "skyline_tint", "sea_shadow", "sea_highlight", "bank_shadow", "bank_highlight", "ruin_haze", "lake_base", "lake_reflection", "cavern_tint", "cavern_deep", "lagoon_deep", "lagoon_wave", "water_reflection"]

func collect(root: Node, theme := "", sky: Material = null) -> void:
 restore()
 begin_theme(theme)
 append_root(root, sky)

func begin_theme(theme: String) -> void:
 allowed_keys.clear()
 for spec: Array in Palette.fields(theme): allowed_keys.append(spec[1])

func append_root(root: Node, sky: Material = null, scenery := false) -> void:
 for node: Node in root.find_children("*", "", true, false):
  if seen_nodes.has(node.get_instance_id()): continue
  seen_nodes[node.get_instance_id()] = true
  if node.has_meta("atmosphere_bindings"): _register_tags(node)
  if not node is GeometryInstance3D: continue
  var scenery_surface := scenery
  var ancestor: Node = node
  while not scenery_surface and ancestor != null:
   scenery_surface = ancestor.has_meta("atmosphere_scenery")
   if ancestor == root: break
   ancestor = ancestor.get_parent()
  if node.material_override != null:
   _slot(node, -1, node.material_override, scenery_surface)
  elif node is MeshInstance3D and node.mesh != null:
   for surface in node.mesh.get_surface_count(): _slot(node, surface, node.get_active_material(surface), scenery_surface)
  elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null and node.multimesh.mesh.get_surface_count() == 1:
   _slot(node, -1, node.multimesh.mesh.surface_get_material(0), scenery_surface)
 # Sky is already a private Lab copy; changing its uniforms invalidates radiance
 # only when a value actually changes. Its shader contains no TIME dependency.
 if sky != null: _register_palette(sky)

func _slot(node: GeometryInstance3D, surface: int, material: Material, scenery := false) -> void:
 if material == null: return
 var copy: Material = _copy(material, scenery)
 if copy == material: return
 var original: Material = node.material_override if surface < 0 else (node as MeshInstance3D).get_surface_override_material(surface)
 slots.append({"node": node, "surface": surface, "original": original})
 if surface < 0: node.material_override = copy
 else: (node as MeshInstance3D).set_surface_override_material(surface, copy)

func _copy(source: Material, scenery := false) -> Material:
 var copy: Material = source
 var trim_layer := source.has_meta("grass_shell_fraction")
 var semantic := source.has_meta("atmosphere_bindings") or source.has_meta("atmosphere_hue") or trim_layer
 if source is ShaderMaterial and source.shader != null:
  semantic = semantic or Palette.SHADERS.has(source.shader.resource_path.get_file().get_basename())
 # Scenery ownership is an explicit opt-in, but its untagged source may also
 # serve gameplay. Keep those copies separate instead of tagging the source.
 var cache: Dictionary = scenery_materials if scenery and not semantic else materials
 if cache.has(source): return cache[source]
 if semantic or scenery: copy = source.duplicate()
 if trim_layer:
  copy.set_meta("atmosphere_hue", "terrain_borders")
  copy.set_meta("atmosphere_trim_split", true)
 if scenery and not semantic:
  copy.set_meta("atmosphere_ranges_only", true)
  copy.set_meta("atmosphere_range_category", "background")
 if (semantic or scenery) and copy is BaseMaterial3D: copy = preload("res://scripts/atmosphere/standard_surface.gd").copy(copy)
 if source is BaseMaterial3D and source.emission_enabled:
  if copy == source: copy = source.duplicate()
  parameters.append({"material": copy, "property": "emission_energy" if copy is ShaderMaterial else "emission_energy_multiplier", "base": source.emission_energy_multiplier, "shader": copy is ShaderMaterial})
 elif source is ShaderMaterial and source.shader != null:
  for uniform: Dictionary in source.shader.get_shader_uniform_list():
   if (semantic or scenery) and str(uniform.name) in ["neon_spread", "floor_neon_spread"]:
    var width = source.get_shader_parameter(uniform.name)
    if width == null: width = RenderingServer.shader_get_parameter_default(source.shader.get_rid(), uniform.name)
    if typeof(width) == TYPE_FLOAT: halo_parameters.append({"material": copy, "property": uniform.name, "base": width})
   if str(uniform.name) not in SCALES: continue
   var value = source.get_shader_parameter(uniform.name)
   if value == null: value = RenderingServer.shader_get_parameter_default(source.shader.get_rid(), uniform.name)
   if typeof(value) != TYPE_FLOAT: continue
   if copy == source: copy = source.duplicate()
   parameters.append({"material": copy, "property": uniform.name, "base": value, "shader": true})
 cache[source] = copy
 if copy != source: _register_palette(copy)
 return copy

func _register_palette(material: Material) -> void:
 if material is ShaderMaterial and material.shader != null:
  var shader_id: String = material.get_meta("atmosphere_shader_id", material.shader.resource_path.get_file().get_basename())
  if material.has_meta("atmosphere_hue") or material.has_meta("atmosphere_ranges_only") or material.has_meta("atmosphere_bindings") or Palette.SHADERS.has(shader_id):
   preload("res://scripts/atmosphere/surface_controls.gd").prepare(material)
   if material.shader.code.contains("atmosphere_shift") or material.shader.code.contains("atmosphere_border_shift"): range_materials.append(material)
 _register_tags(material)
 if material.has_meta("atmosphere_hue") or material.has_meta("atmosphere_ranges_only"):
  var group: String = material.get_meta("atmosphere_hue", "")
  if material is BaseMaterial3D:
   hue_parameters.append({"material": material, "group": group, "base": material.albedo_color, "emission": material.emission, "bindings": material.get_meta("atmosphere_bindings", {})})
  elif material is ShaderMaterial and (material.shader.code.contains("atmosphere_shift") or material.shader.code.contains("atmosphere_border_shift")):
   hue_parameters.append({"material": material, "group": group})
 if not material is ShaderMaterial or material.shader == null: return
 var bindings: Dictionary = Palette.SHADERS.get(material.get_meta("atmosphere_shader_id", material.shader.resource_path.get_file().get_basename()), {})
 for property: String in bindings:
  var key: String = "palette/" + bindings[property]
  if key not in allowed_keys: continue
  var base = material.get_shader_parameter(property)
  if base == null: base = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), property)
  if base == null:
   # The dummy renderer cannot supply shader defaults. Rendered regression
   # checks own palette coverage; headless startup still validates scripts.
   if DisplayServer.get_name() != "headless": push_error("Missing atmosphere uniform: " + property)
   continue
  var entry := {"target": material, "property": property, "key": key, "base": base, "shader": true, "mode": "direct"}
  palette_parameters.append(entry)
  if not palette_originals.has(key): palette_originals[key] = _picker_value(base)
 for uniform: Dictionary in material.shader.get_shader_uniform_list():
  if str(uniform.name) == "fake_light_direction":
   var base = material.get_shader_parameter(uniform.name)
   if base == null: base = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), uniform.name)
   if base is Vector3: cloud_lights.append({"material": material, "base": base, "last": base})

func _register_tags(target: Object) -> void:
 var bindings: Dictionary = target.get_meta("atmosphere_bindings", {})
 for property: String in bindings:
  var entry: Dictionary = bindings[property].duplicate()
  entry.key = "palette/" + entry.key
  if entry.key not in allowed_keys: continue
  var shader_binding: bool = entry.get("shader", false)
  var base = target.get_shader_parameter(property) if shader_binding else target.get(property)
  entry.merge({"target": target, "property": property, "base": base, "shader": shader_binding})
  palette_parameters.append(entry)
  if not palette_originals.has(entry.key):
   palette_originals[entry.key] = Color.WHITE if entry.mode == "tint" else entry.get("authored", entry.base)

func _picker_value(value: Variant) -> Variant:
 if value is Vector3: return Color(value.x, value.y, value.z).linear_to_srgb()
 return value

func apply_palette(values: Dictionary, sun: DirectionalLight3D, use_sun_direction: bool) -> void:
 for entry: Dictionary in halo_parameters:
  entry.material.set_shader_parameter(entry.property, float(entry.base) * float(values.get("surface_halo_spread", 1.0)))
 var input_ranges := {}
 for entry: Dictionary in palette_parameters:
  if entry.target is ShaderMaterial and not _palette_stacks(values, entry.key): input_ranges[entry.target] = true
 for entry: Dictionary in palette_parameters:
  var key: String = entry.key
  var value = values.get(key, palette_originals[key])
  # Values are applied only on load/change, including hue changes.
  var actual = value
  if value == palette_originals[key]: actual = entry.base
  elif entry.mode == "tint": actual = entry.base * value
  elif entry.mode == "haze": actual = entry.unhazed.lerp(value, entry.amount)
  elif entry.base is Vector3:
   var linear: Color = value.srgb_to_linear()
   actual = Vector3(linear.r, linear.g, linear.b)
  var hue_group := _palette_group(key)
  # The final material operation owns selective ranges when present. Applying
  # ranges to its palette inputs as well would shift a Decor color twice.
  var ranges_here := _palette_stacks(values, key)
  if entry.target is Material:
   ranges_here = ranges_here and _material_stacks(entry.target, values)
   if entry.target is BaseMaterial3D and entry.target.has_meta("atmosphere_hue"): ranges_here = false
   if entry.target is ShaderMaterial and entry.target in range_materials: ranges_here = ranges_here and input_ranges.has(entry.target)
  if actual is Color: actual = shifted(actual, values, hue_group, ranges_here)
  elif actual is Vector3:
   var color := shifted(Color(actual.x, actual.y, actual.z), values, hue_group, ranges_here)
   actual = Vector3(color.r, color.g, color.b)
  if entry.shader: entry.target.set_shader_parameter(entry.property, actual)
  else: entry.target.set(entry.property, actual)
 for entry: Dictionary in hue_parameters:
  var group := resolved_group(values, entry.group)
  if entry.material is BaseMaterial3D:
   var base: Color = entry.material.albedo_color if entry.bindings.has("albedo_color") else entry.base
   entry.material.albedo_color = shifted(base, values, group, _property_stacks(entry, "albedo_color", values))
   if entry.material.emission_enabled:
    var glow: Color = entry.material.emission if entry.bindings.has("emission") else entry.emission
    entry.material.emission = shifted(glow, values, group, _property_stacks(entry, "emission", values))
  else:
   entry.material.set_shader_parameter("atmosphere_hue", float(values.get("hue/" + group, 0.0)))
   entry.material.set_shader_parameter("atmosphere_saturation", float(values.get("saturation/" + group, 1.0)))
   entry.material.set_shader_parameter("atmosphere_brightness", float(values.get("brightness/" + group, 1.0)))
 for material: ShaderMaterial in range_materials:
  var allow := _material_stacks(material, values) and not input_ranges.has(material)
  var trim := bool(material.get_meta("atmosphere_trim_split", false))
  var edge_allow := trim and ColorRanges.group_stacks(values, "terrain_edges") and not input_ranges.has(material)
  ColorRanges.apply_uniforms(material, values, allow or edge_allow)
  material.set_shader_parameter("atmosphere_ranges_enabled", allow and ColorRanges.active(values))
  if trim:
   var edge_group := resolved_group(values, "terrain_edges")
   material.set_shader_parameter("atmosphere_edge_adjustment", Vector3(float(values.get("hue/" + edge_group, 0.0)), float(values.get("saturation/" + edge_group, 1.0)), float(values.get("brightness/" + edge_group, 1.0))))
   material.set_shader_parameter("atmosphere_edge_ranges_enabled", edge_allow and ColorRanges.active(values))
  var raw_group: String = material.get_meta("atmosphere_hue", "")
  var emission_group := "neon" if raw_group.begins_with("terrain_") else resolved_group(values, raw_group)
  material.set_shader_parameter("atmosphere_emission_hue", float(values.get("hue/" + emission_group, 0.0)))
  material.set_shader_parameter("atmosphere_emission_saturation", float(values.get("saturation/" + emission_group, 1.0)))
  material.set_shader_parameter("atmosphere_emission_brightness", float(values.get("brightness/" + emission_group, 1.0)))
  material.set_shader_parameter("atmosphere_emission_ranges_enabled", ColorRanges.active(values) and (ColorRanges.group_stacks(values, "neon") if raw_group.begins_with("terrain_") else allow))
 for key: String in palette_originals: last_palette[key] = values.get(key, palette_originals[key])
 for entry: Dictionary in cloud_lights:
  var direction: Vector3 = sun.basis.z.normalized() if use_sun_direction else entry.base
  if not direction.is_equal_approx(entry.last):
   entry.material.set_shader_parameter("fake_light_direction", direction)
   entry.last = direction

func apply(multiplier: float) -> void:
 for entry: Dictionary in parameters:
  if entry.shader: entry.material.set_shader_parameter(entry.property, float(entry.base) * multiplier)
  else: entry.material.set(entry.property, float(entry.base) * multiplier)

func restore() -> void:
 # Node properties (existing lights/marquee) are not material slots.
 for entry: Dictionary in palette_parameters:
  if not entry.shader and is_instance_valid(entry.target): entry.target.set(entry.property, entry.base)
 for slot: Dictionary in slots:
  if not is_instance_valid(slot.node): continue
  if slot.surface < 0: slot.node.material_override = slot.original
  else: slot.node.set_surface_override_material(slot.surface, slot.original)
 slots.clear()
 seen_nodes.clear()
 parameters.clear()
 halo_parameters.clear()
 palette_parameters.clear()
 palette_originals.clear()
 cloud_lights.clear()
 last_palette.clear()
 materials.clear()
 scenery_materials.clear()
 hue_parameters.clear()
 range_materials.clear()

static func shifted(color: Color, values: Dictionary, group: String, ranges := true) -> Color:
 var hue := float(values.get("hue/" + group, 0.0))
 var saturation := float(values.get("saturation/" + group, 1.0))
 if not is_zero_approx(hue) or not is_equal_approx(saturation, 1.0):
  color = Color.from_hsv(fposmod(color.h + hue, 1.0), clampf(color.s * saturation, 0.0, 1.0), color.v, color.a)
 var brightness := float(values.get("brightness/" + group, 1.0))
 color = Color(color.r * brightness, color.g * brightness, color.b * brightness, color.a)
 return ColorRanges.apply(color, values) if ranges else color

static func resolved_group(values: Dictionary, group: String) -> String:
 group = ColorRanges.linked_group(values, group)
 return "terrain" if group.begins_with("terrain_") and not values.get("override/" + group, false) else group

static func _palette_group(key: String) -> String:
 var role := key.trim_prefix("palette/")
 return "neon" if role in NEON_KEYS else ("foliage" if role == "vegetation_tint" else ("background" if role in BACKGROUND_KEYS else ""))

static func _palette_stacks(values: Dictionary, key: String) -> bool:
 return values.get("stack/" + key, true) and ColorRanges.group_stacks(values, _palette_group(key))

static func _material_stacks(material: Material, values: Dictionary) -> bool:
 return ColorRanges.group_stacks(values, material.get_meta("atmosphere_hue", material.get_meta("atmosphere_range_category", "")))

static func _property_stacks(entry: Dictionary, property: String, values: Dictionary) -> bool:
 return _material_stacks(entry.material, values) and (not entry.bindings.has(property) or _palette_stacks(values, "palette/" + entry.bindings[property].key))
