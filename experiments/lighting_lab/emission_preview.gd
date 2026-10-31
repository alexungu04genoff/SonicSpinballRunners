extends RefCounted
## Share private copies for editable emission/palette materials; restore every slot.
## Only explicit semantic bindings are editable. No runtime shader rewriting.
const SCALES := ["emission_scale", "neon_strength", "radiance"]
const Palette := preload("res://scripts/themes/theme_atmosphere.gd")
var slots: Array[Dictionary] = []
var materials := {}
var parameters: Array[Dictionary] = []
var palette_parameters: Array[Dictionary] = []
var palette_originals := {}
var cloud_lights: Array[Dictionary] = []
var allowed_keys: Array[String] = []
var last_palette := {}

func collect(root: Node, theme := "", sky: Material = null) -> void:
 restore()
 allowed_keys.clear()
 for spec: Array in Palette.fields(theme): allowed_keys.append(spec[1])
 for node: Node in root.find_children("*", "", true, false):
  if node.has_meta("atmosphere_bindings"): _register_tags(node)
  if not node is GeometryInstance3D: continue
  if node.material_override != null:
   _slot(node, -1, node.material_override)
  elif node is MeshInstance3D and node.mesh != null:
   for surface in node.mesh.get_surface_count(): _slot(node, surface, node.get_active_material(surface))
  elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null and node.multimesh.mesh.get_surface_count() == 1:
   _slot(node, -1, node.multimesh.mesh.surface_get_material(0))
 # Sky is already a private Lab copy; changing its uniforms invalidates radiance
 # only when a value actually changes. Its shader contains no TIME dependency.
 if sky != null: _register_palette(sky)

func _slot(node: GeometryInstance3D, surface: int, material: Material) -> void:
 if material == null: return
 var copy: Material = _copy(material)
 if copy == material: return
 var original: Material = node.material_override if surface < 0 else (node as MeshInstance3D).get_surface_override_material(surface)
 slots.append({"node": node, "surface": surface, "original": original})
 if surface < 0: node.material_override = copy
 else: (node as MeshInstance3D).set_surface_override_material(surface, copy)

func _copy(source: Material) -> Material:
 if materials.has(source): return materials[source]
 var copy: Material = source
 var semantic := source.has_meta("atmosphere_bindings")
 if source is ShaderMaterial and source.shader != null:
  semantic = semantic or Palette.SHADERS.has(source.shader.resource_path.get_file().get_basename())
 if semantic: copy = source.duplicate()
 if source is BaseMaterial3D and source.emission_enabled:
  if copy == source: copy = source.duplicate()
  parameters.append({"material": copy, "property": "emission_energy_multiplier", "base": source.emission_energy_multiplier, "shader": false})
 elif source is ShaderMaterial and source.shader != null:
  for uniform: Dictionary in source.shader.get_shader_uniform_list():
   if str(uniform.name) not in SCALES: continue
   var value = source.get_shader_parameter(uniform.name)
   if value == null: value = RenderingServer.shader_get_parameter_default(source.shader.get_rid(), uniform.name)
   if typeof(value) != TYPE_FLOAT: continue
   if copy == source: copy = source.duplicate()
   parameters.append({"material": copy, "property": uniform.name, "base": value, "shader": true})
 materials[source] = copy
 if copy != source: _register_palette(copy)
 return copy

func _register_palette(material: Material) -> void:
 _register_tags(material)
 if not material is ShaderMaterial or material.shader == null: return
 var bindings: Dictionary = Palette.SHADERS.get(material.shader.resource_path.get_file().get_basename(), {})
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
  entry.merge({"target": target, "property": property, "base": target.get(property), "shader": false})
  palette_parameters.append(entry)
  if not palette_originals.has(entry.key):
   palette_originals[entry.key] = Color.WHITE if entry.mode == "tint" else entry.get("authored", entry.base)

func _picker_value(value: Variant) -> Variant:
 if value is Vector3: return Color(value.x, value.y, value.z).linear_to_srgb()
 return value

func apply_palette(values: Dictionary, sun: DirectionalLight3D, use_sun_direction: bool) -> void:
 for entry: Dictionary in palette_parameters:
  var key: String = entry.key
  var value = values.get(key, palette_originals[key])
  if last_palette.has(key) and last_palette[key] == value: continue
  var actual = value
  if value == palette_originals[key]: actual = entry.base
  elif entry.mode == "tint": actual = entry.base * value
  elif entry.mode == "haze": actual = entry.unhazed.lerp(value, entry.amount)
  elif entry.base is Vector3:
   var linear: Color = value.srgb_to_linear()
   actual = Vector3(linear.r, linear.g, linear.b)
  if entry.shader: entry.target.set_shader_parameter(entry.property, actual)
  else: entry.target.set(entry.property, actual)
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
 parameters.clear()
 palette_parameters.clear()
 palette_originals.clear()
 cloud_lights.clear()
 last_palette.clear()
 materials.clear()
