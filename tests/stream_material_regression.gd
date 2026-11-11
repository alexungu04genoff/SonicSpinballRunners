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
 var direct_conversions := 0
 func _private_material(source: Material) -> Material:
  var result := super._private_material(source)
  if source is BaseMaterial3D and result is ShaderMaterial: direct_conversions += 1
  return result
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
 runtime.bindings._legacy_material_copies = not cached
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
   var pending := {}
   var steps := 0
   # A zero time budget deterministically stops after one node. Cross real
   # frames too, while keeping this state comparison quick in headless runs.
   while not incremental.attach_step(pair[0], pending, pair[1], 0) and steps < 20000:
    steps += 1
    if steps % 32 == 0: await process_frame
   check(steps >= 1 and pending.is_empty(), "Chunked attachment completes and releases its traversal: " + theme)
  check(snapshot(a.nodes) == snapshot(b.nodes), "Full material properties, program source and uniforms match: " + theme)
  check(sync.bindings.slots.size() == incremental.bindings.slots.size() and sync.bindings.seen_nodes.size() == incremental.bindings.seen_nodes.size(), "Slot and node coverage match: " + theme)
  check(sync.bindings.palette_originals == incremental.bindings.palette_originals, "Palette bases match: " + theme)
  check(sync.bindings.materials.keys() == incremental.bindings.materials.keys(), "Both paths bind the same immutable foreground sources: " + theme)
  check(["parameters", "halo_parameters", "palette_parameters", "hue_parameters", "range_materials", "cloud_lights"].all(func(key: String): return sync.bindings.get(key).size() == incremental.bindings.get(key).size()), "Emission, halo, palette, hue, range and light control coverage match: " + theme)
  check(incremental.bindings.inspections < sync.bindings.inspections, "Shared shader inspection reduces native queries: " + theme)
  check(incremental.bindings._uniform_cache.is_empty(), "Attachment releases the inspection cache: " + theme)
  print("MATERIAL_INSPECTIONS | %s | uncached=%d cached=%d" % [theme, sync.bindings.inspections, incremental.bindings.inspections])
  print("MATERIAL_DIRECT_CONVERSIONS | %s | avoided_copies=%d" % [theme, incremental.bindings.direct_conversions])
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
 pending_edit_checks()
 conversion_checks()
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

func pending_edit_checks() -> void:
 var source := StandardMaterial3D.new()
 source.albedo_color = Color(0.2,0.6,0.3)
 source.emission_enabled = true
 source.emission = Color(0.3,0.1,0.2)
 source.emission_energy_multiplier = 1.2
 source.set_meta("atmosphere_hue","decor")
 var holders: Array[Node3D] = []
 var visuals: Array = []
 for i in 2:
  var holder := Node3D.new()
  root.add_child(holder)
  holders.append(holder)
  var nodes: Array[Node] = []
  for j in 3:
   var node := MeshInstance3D.new()
   node.material_override = source
   holder.add_child(node)
   nodes.append(node)
  visuals.append(nodes)
 var sun := DirectionalLight3D.new()
 root.add_child(sun)
 var whole := configured("green_hill",Environment.new(),sun)
 var sliced := configured("green_hill",Environment.new(),sun)
 var pending := {}
 check(not sliced.attach_step(holders[1],pending,false,0),"A partial attachment returns before application")
 var changed := {"emission":1.8,"hue/decor":0.23,"brightness/decor":0.8}
 whole.values.merge(changed,true)
 sliced.values.merge(changed,true)
 whole.attach(holders[0])
 for step in 10:
  if sliced.attach_step(holders[1],pending,false,0): break
 check(pending.is_empty() and snapshot(visuals[0]) == snapshot(visuals[1]),"Completion applies the latest values after an edit during collection")
 check(visuals[1][0].material_override == visuals[1][2].material_override and visuals[1][0].material_override != source,"Shared source keeps one private copy across slices")
 whole.bindings.restore()
 sliced.bindings.restore()
 check(visuals[1].all(func(node): return node.material_override == source),"Restoration recovers every slot after chunked attachment")
 for holder: Node3D in holders: holder.free()
 sun.free()

func conversion_checks() -> void:
 var texture := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
 for kind in 7:
  var source := StandardMaterial3D.new()
  source.albedo_color = Color(0.3, 0.6, 0.2, 0.7)
  source.roughness = 0.43
  source.metallic = 0.17
  source.uv1_scale = Vector3(2, 3, 1)
  source.render_priority = 2
  source.next_pass = StandardMaterial3D.new()
  source.set_meta("custom_data", {"nested": [Vector3.ONE], "resource": texture})
  if kind != 0 and kind != 2: source.albedo_texture = texture
  if kind == 2: source.vertex_color_use_as_albedo = true
  if kind < 3: source.set_meta("atmosphere_hue", "decor")
  if kind == 1:
   source.set_meta("grass_shell_fraction", 0.5)
   source.set_meta("atmosphere_bindings", {"albedo_color": {"key": "vegetation_tint", "mode": "tint"}})
   source.uv1_triplanar = true
   source.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
  if kind in [1, 6]:
   source.emission_enabled = true
   source.emission = Color(0.7, 0.2, 0.1)
   source.emission_energy_multiplier = 1.3
  if kind == 4: source.set_meta("atmosphere_protected", true)
  var before := material_state(source)
  var legacy := ObservedBindings.new()
  legacy._legacy_material_copies = true
  var direct := ObservedBindings.new()
  legacy.begin_theme("green_hill")
  direct.begin_theme("green_hill")
  var expected: Material = legacy._copy(source, kind == 3)
  var actual: Material = direct._copy(source, kind == 3)
  check(material_state(actual) == material_state(expected), "Conversion, flat/emissive fallback and protected/shared state match: %d" % kind)
  check(material_state(source) == before and (actual == source) == (expected == source), "Source properties and sharing policy survive conversion: %d" % kind)
  check(is_same(actual.get_meta("custom_data"), expected.get_meta("custom_data")) and actual.next_pass == expected.next_pass and direct.parameters.size() == legacy.parameters.size(), "Metadata, next pass and emission ownership match: %d" % kind)
  legacy.restore()
  direct.restore()
