extends RefCounted
## Duplicate only editable emission materials; restore every original node slot.
## Fixed shader expressions stay authored. No shader source rewriting is needed.
const SCALES := ["emission_scale", "neon_strength", "radiance"]
var slots: Array[Dictionary] = []
var materials := {}
var parameters: Array[Dictionary] = []

func collect(root: Node) -> void:
 restore()
 for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
  if node.material_override != null:
   _slot(node, -1, node.material_override)
  elif node is MeshInstance3D and node.mesh != null:
   for surface in node.mesh.get_surface_count(): _slot(node, surface, node.get_active_material(surface))
  elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null and node.multimesh.mesh.get_surface_count() == 1:
   _slot(node, -1, node.multimesh.mesh.surface_get_material(0))

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
 if source is BaseMaterial3D and source.emission_enabled:
  copy = source.duplicate()
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
 return copy

func apply(multiplier: float) -> void:
 for entry: Dictionary in parameters:
  if entry.shader: entry.material.set_shader_parameter(entry.property, float(entry.base) * multiplier)
  else: entry.material.set(entry.property, float(entry.base) * multiplier)

func restore() -> void:
 for slot: Dictionary in slots:
  if not is_instance_valid(slot.node): continue
  if slot.surface < 0: slot.node.material_override = slot.original
  else: slot.node.set_surface_override_material(slot.surface, slot.original)
 slots.clear()
 parameters.clear()
 materials.clear()
