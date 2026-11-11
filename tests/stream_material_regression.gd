extends SceneTree
## Cached inspection and frame-separated attachment preserve baked material state.
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Runtime = preload("res://scripts/atmosphere/runtime.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
const ACT := "res://data/acts/Authored/RampMania.tres"
var checks := 0
var failures := 0

class ObservedBindings extends "res://scripts/atmosphere/material_bindings.gd":
 var inspections := 0
 func _control_uniforms(shader: Shader) -> Array:
  if not _cache_uniforms or not _uniform_cache.has(shader): inspections += 1
  return super._control_uniforms(shader)

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func normalized(value: Variant) -> Variant:
 if value is Shader: return ["shader", value.code]
 if value is Material: return material_state(value)
 if value is Resource: return [value.get_class(), value.resource_path if not value.resource_path.is_empty() else str(value.get_instance_id())]
 if value is Array:
  var result: Array = []
  for item: Variant in value: result.append(normalized(item))
  return result
 if value is Dictionary:
  var result := {}
  for key: Variant in value: result[key] = normalized(value[key])
  return result
 return value

func material_state(material: Material) -> Dictionary:
 if material == null: return {}
 var result := {"class": material.get_class()}
 for property: Dictionary in material.get_property_list():
  var key: String = property.name
  if int(property.usage) & PROPERTY_USAGE_STORAGE == 0 or key in ["resource_name", "resource_path", "resource_scene_unique_id", "script"]: continue
  result[key] = normalized(material.get(key))
 return result

func snapshot(nodes: Array[Node]) -> Array:
 var result: Array = []
 for node: Node in nodes:
  if not node is GeometryInstance3D: continue
  var state := [material_state(node.material_override), material_state(node.material_overlay)]
  if node is MeshInstance3D and node.mesh != null:
   for surface in node.mesh.get_surface_count(): state.append(material_state(node.get_active_material(surface)))
  result.append(state)
 return result

func instantiate(recipe: Resource) -> Dictionary:
 var foreground := Node3D.new()
 var scenery := Node3D.new()
 foreground.process_mode = Node.PROCESS_MODE_DISABLED
 scenery.process_mode = Node.PROCESS_MODE_DISABLED
 root.add_child(foreground)
 root.add_child(scenery)
 var nodes: Array[Node] = []
 for index in recipe.records.size():
  recipe.instantiate_one(index, nodes, scenery if recipe.records[index].get("background", false) else foreground)
 return {"foreground": foreground, "scenery": scenery, "nodes": nodes}

func configured(theme: String, environment: Environment, sun: DirectionalLight3D, cached := true) -> RefCounted:
 var runtime := Runtime.new()
 runtime.bindings = ObservedBindings.new()
 runtime.bindings._cache_uniforms = cached
 runtime.configure(theme, {"values": {"emission": 0.73, "hue/decor": 0.13, "brightness/foliage": 1.1,
  "hue/terrain": -0.08, "ranges/enabled": true, "ranges/yellow/hue": 0.03}}, environment, sun)
 return runtime

func run() -> void:
 for theme: String in Registry.IDS:
  var baked: Resource = load(Bake.path_for(ACT, theme))
  check(baked != null, "Production bake exists: " + theme)
  if baked == null: continue
  var theme_bake: Resource = load(Bake.theme_path(theme))
  check(theme_bake != null and theme_bake.environment != null, "Production theme environment exists: " + theme)
  if theme_bake == null or theme_bake.environment == null: continue
  var a := instantiate(baked.visual_recipe)
  var b := instantiate(baked.visual_recipe)
  var original := snapshot(a.nodes)
  var sun := DirectionalLight3D.new()
  root.add_child(sun)
  var sync := configured(theme, theme_bake.environment, sun, false)
  var incremental := configured(theme, theme_bake.environment, sun)
  sync.attach(a.foreground)
  sync.attach(a.scenery, false, true)
  for pair: Array in [[b.foreground, false], [b.scenery, true]]:
   incremental.attach(pair[0], false, pair[1])
   await process_frame
  check(snapshot(a.nodes) == snapshot(b.nodes), "Full material properties, program source and uniforms match: " + theme)
  check(sync.bindings.slots.size() == incremental.bindings.slots.size() and sync.bindings.seen_nodes.size() == incremental.bindings.seen_nodes.size(), "Slot and node coverage match: " + theme)
  check(sync.bindings.palette_originals == incremental.bindings.palette_originals, "Palette bases match: " + theme)
  check(sync.bindings.materials.keys() == incremental.bindings.materials.keys(), "Both paths bind the same immutable foreground sources: " + theme)
  check(["parameters", "halo_parameters", "palette_parameters", "hue_parameters", "range_materials", "cloud_lights"].all(func(key: String): return sync.bindings.get(key).size() == incremental.bindings.get(key).size()), "Emission, halo, palette, hue, range and light control coverage match: " + theme)
  check(incremental.bindings.inspections < sync.bindings.inspections, "Shared shader inspection reduces native queries: " + theme)
  check(incremental.bindings._uniform_cache.is_empty(), "Attachment releases the inspection cache: " + theme)
  print("MATERIAL_INSPECTIONS | %s | uncached=%d cached=%d" % [theme, sync.bindings.inspections, incremental.bindings.inspections])
  var edited: Dictionary = sync.values.duplicate(true)
  edited.merge({"emission": 1.41, "hue/terrain": 0.17, "hue/decor": -0.11, "surface_halo_spread": 0.65}, true)
  sun.rotation_degrees = Vector3(-35, 23, 0)
  for runtime: RefCounted in [sync, incremental]:
   runtime.bindings.apply(edited.emission)
   runtime.bindings.apply_palette(edited, sun, true)
  check(snapshot(a.nodes) == snapshot(b.nodes), "Live color, emission, halo and sun edits still match: " + theme)
  sync.bindings.restore()
  incremental.bindings.restore()
  check(snapshot(a.nodes) == original and snapshot(b.nodes) == original, "Restoring both paths recovers original material slots: " + theme)
  a.foreground.free()
  a.scenery.free()
  b.foreground.free()
  b.scenery.free()
  sun.free()
 shader_edit_checks()
 print("RESULT | Stream material staging | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func shader_edit_checks() -> void:
 var bindings := ObservedBindings.new()
 var shader := Shader.new()
 shader.code = "shader_type spatial; uniform float emission_scale = 1.0; void fragment() { ALBEDO = vec3(1.0); }"
 var first := MeshInstance3D.new()
 first.material_override = ShaderMaterial.new()
 first.material_override.shader = shader
 first.material_override.set_shader_parameter("emission_scale", 0.75)
 var second := MeshInstance3D.new()
 var holder := Node3D.new()
 holder.add_child(first)
 bindings.append_root(holder)
 check(bindings.parameters.size() == 1 and bindings._uniform_cache.is_empty(), "First attachment inspects and releases its shader")
 # A shared Shader can change between attachments, including through includes.
 # No code hash or persistent descriptor may hide its newly exposed uniforms.
 shader.code = shader.code.replace("void fragment()", "uniform float radiance = 1.0; void fragment()")
 second.material_override = ShaderMaterial.new()
 second.material_override.shader = shader
 second.material_override.set_shader_parameter("emission_scale", 0.5)
 second.material_override.set_shader_parameter("radiance", 2.0)
 holder.add_child(second)
 bindings.append_root(holder)
 bindings.apply(2.0)
 check(bindings.parameters.size() == 3 and second.material_override.get_shader_parameter("radiance") == 4.0, "Next attachment sees live shared-shader edits and its new emission uniform")
 bindings.restore()
 check(bindings._uniform_cache.is_empty() and first.material_override.get_shader_parameter("emission_scale") == 0.75 and second.material_override.get_shader_parameter("radiance") == 2.0, "Restoration releases inspection data and preserves source parameters")
 holder.free()
