extends SceneTree
## Rendered functional checks against the currently loaded theme implementations.
var checks := 0
var failures := 0
var game: Node
const OUTPUT := "res://test-results/atmosphere-controls"

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)

func frames(count: int) -> void:
 for i in count: await process_frame

func _initialize() -> void: call_deferred("run")

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Surface coverage requires a real renderer.")
  quit(1)
  return
 if "--baked-only" in OS.get_cmdline_user_args():
  check_baked_bindings()
  print("ATMOSPHERE_BAKED_SURFACES_RESULT | checks=%d failures=%d" % [checks, failures])
  quit(1 if failures else 0)
  return
 root.size = Vector2i(1280, 900)
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 game.authored_act_path = "res://data/acts/Authored/First Try Smooth Decor.tres"
 root.add_child(game)
 paused = true
 root.gui_disable_input = true
 await frames(4)
 var panel = game.lighting_controls
 panel.saved = ConfigFile.new()
 panel.drafts.clear()
 for theme: String in game.ThemeRegistry.IDS:
  game.set_theme(theme)
  panel.variants.context.selected = "draft"
  panel.reset_values()
  var before: int = game.presentation.find_children("*", "", true, false).size()
  var ball: int = game.ball.get_instance_id()
  var programs := {}
  var groups := {}
  for entry: Dictionary in panel.emission.hue_parameters:
   groups[entry.group] = int(groups.get(entry.group, 0)) + 1
   if entry.material is ShaderMaterial: programs[entry.material] = entry.material.shader
  for group: String in ["terrain_ground", "terrain_upper", "terrain_walls", "terrain_borders", "terrain_ledges", "decor"]:
   check(groups.get(group, 0) > 0, theme + " has live " + group + " bindings")
  await frames(5)
  await capture(theme + "-default")
  await check_trim_controls(panel, theme)
  var changed: Dictionary = panel.originals.duplicate(true)
  changed["hue/terrain"] = 0.31
  changed["brightness/terrain"] = 0.6
  panel.values = changed
  panel.apply_values()
  for entry: Dictionary in panel.emission.hue_parameters:
   if not entry.group.begins_with("terrain_") or not entry.material is ShaderMaterial: continue
   check(is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_hue")), 0.31), theme + " Terrain reaches " + entry.group)
   check(is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_brightness")), 0.6), theme + " Terrain brightness reaches " + entry.group)
  changed["override/terrain_ground"] = true
  changed["hue/terrain_ground"] = -0.3
  changed["saturation/terrain_ground"] = 0.7
  changed["brightness/terrain_ground"] = 0.8
  changed["override/terrain_upper"] = true
  changed["hue/terrain_upper"] = 0.15
  changed["brightness/terrain_upper"] = 1.5
  panel.apply_values()
  for entry: Dictionary in panel.emission.hue_parameters:
   if not entry.material is ShaderMaterial: continue
   if entry.group == "terrain_ground": check(is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_hue")), -0.3), theme + " independent ground override")
   if entry.group == "terrain_upper": check(is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_brightness")), 1.5), theme + " independent raised-top brightness")
  await frames(5)
  await capture(theme + "-terrain")
  panel.reset_values()
  panel.set_value("hue/decor", -0.33)
  panel.set_value("saturation/decor", 1.5)
  panel.set_value("brightness/decor", 0.65)
  for entry: Dictionary in panel.emission.hue_parameters:
   if entry.material is ShaderMaterial:
    check(entry.material.shader == programs[entry.material], "Editing never recreates a shader")
    check(is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_brightness")), 0.65 if entry.group == "decor" else 1.0), theme + " Decor stays isolated from terrain")
   elif entry.group == "decor":
    check(entry.material.albedo_color != entry.base or entry.base == Color.BLACK, theme + " StandardMaterial decor responds")
  check(game.presentation.find_children("*", "", true, false).size() == before and game.ball.get_instance_id() == ball, "Controls preserve geometry and gameplay identity")
  await frames(5)
  await capture(theme + "-decor")
  var colors := {}
  for entry: Dictionary in panel.emission.hue_parameters:
   if entry.material is BaseMaterial3D: colors[entry.material] = [entry.material.albedo_color, entry.material.emission]
  panel.apply_values()
  for material: BaseMaterial3D in colors:
   check(colors[material] == [material.albedo_color, material.emission], theme + " repeat application does not accumulate Decor tint")
  panel.reset_values()
  for entry: Dictionary in panel.emission.hue_parameters:
   if entry.material is BaseMaterial3D:
    check(entry.material.albedo_color == entry.base and entry.material.emission == entry.emission, theme + " exact Decor reset")
  panel.set_value("ranges/enabled", true)
  panel.set_value("ranges/green/hue", 0.23)
  panel.set_value("ranges/green/saturation", 0.4)
  panel.set_value("ranges/green/brightness", 1.6)
  for material: ShaderMaterial in panel.emission.range_materials:
   check(material.get_shader_parameter("atmosphere_ranges_enabled") == true, theme + " enables color ranges on opted-in programs")
   check(material.get_shader_parameter("atmosphere_range_green").is_equal_approx(Vector3(0.23, 0.4, 1.6)), theme + " forwards all three green controls")
  await frames(5)
  await capture(theme + "-green-range")
  panel.reset_values()
  panel.set_value("hue/neon", 0.3)
  panel.set_value("brightness/neon", 0.7)
  for entry: Dictionary in panel.emission.hue_parameters:
   if entry.group.begins_with("terrain_") and entry.material is ShaderMaterial:
    check(is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_emission_hue")), 0.3), theme + " terrain emission follows Neon")
    check(is_zero_approx(float(entry.material.get_shader_parameter("atmosphere_hue"))), theme + " Neon preserves terrain albedo")
  await frames(4)
  await capture(theme + "-neon")
  panel.reset_values()
  print("ATMOSPHERE_SURFACES | ", theme, " | ", groups)
 panel.tabs.current_tab = 4
 game.toggle_fullscreen()
 panel._process(0.0)
 check(is_equal_approx(panel.panel.offset_bottom, -10.0) and is_equal_approx(panel.panel.offset_top, 10.0), "Fullscreen inspector fills height")
 check(not game.development_footer.visible, "Fullscreen restores footer space to the inspector")
 await frames(3)
 await capture("fullscreen-panel")
 game.toggle_fullscreen()
 panel._process(0.0)
 check(is_equal_approx(panel.panel.offset_bottom, -215.0) and is_equal_approx(panel.panel.offset_top, 30.0) and game.development_footer.visible, "Windowed footer space restored")
 game.free()
 print("ATMOSPHERE_SURFACES_RESULT | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func capture(label: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png"))

func check_baked_bindings() -> void:
 const Bake := preload("res://scripts/endless/geometry_bake.gd")
 var paths: Array = preload("res://scripts/prototype/run_plan.gd").source_paths()
 for path: String in preload("res://scripts/endless/endless_plan.gd").PATHS:
  if path not in paths: paths.append(path)
 var cases := 0
 for theme: String in preload("res://scripts/themes/theme_registry.gd").IDS:
  var fingerprint: String = Bake.pipeline_hash(theme)
  for path: String in paths:
   var document: Resource = preload("res://scripts/act_editor/act_geometry.gd").load_document(path).document
   check_baked_act(Bake.path_for(path, theme), document, theme, fingerprint)
   cases += 1
  print("ATMOSPHERE_BAKED_THEME | ", theme, " | Acts=", paths.size())
 print("ATMOSPHERE_BAKED_ACTS | cases=", cases)

func check_trim_controls(panel: Node, theme: String) -> void:
 var bindings = panel.emission
 var values: Dictionary = panel.originals.duplicate(true)
 values.erase("link/terrain_trim") # Older saved looks did not have a link setting.
 values.merge({"override/terrain_borders": true, "hue/terrain_borders": 0.21, "saturation/terrain_borders": 0.62, "brightness/terrain_borders": 0.83}, true)
 panel.values = values
 panel.apply_values()
 var split_count := 0
 for entry: Dictionary in bindings.hue_parameters:
  if entry.group not in ["terrain_borders", "terrain_ledges"]: continue
  check(is_equal_approx(entry.material.get_shader_parameter("atmosphere_hue"), 0.21), theme + " preserves legacy combined trim hue")
  if entry.material.get_meta("atmosphere_trim_split", false):
   split_count += 1
   check(entry.material.get_shader_parameter("atmosphere_edge_adjustment").is_equal_approx(Vector3(0.21, 0.62, 0.83)), theme + " legacy edge matches combined controls")
 check(split_count > 0, theme + " has separately adjustable outer edges")
 values.merge({"link/terrain_trim": false, "override/terrain_edges": true, "hue/terrain_edges": -0.25, "saturation/terrain_edges": 0.8, "brightness/terrain_edges": 1.4, "override/terrain_ledges": true, "hue/terrain_ledges": 0.55, "brightness/terrain_ledges": 0.6}, true)
 panel.apply_values()
 for entry: Dictionary in bindings.hue_parameters:
  if entry.group == "terrain_ledges": check(is_equal_approx(entry.material.get_shader_parameter("atmosphere_hue"), 0.55), theme + " independent ledges hue")
  if entry.material.get_meta("atmosphere_trim_split", false):
   check(is_equal_approx(entry.material.get_shader_parameter("atmosphere_hue"), 0.21), theme + " independent interior border hue")
   check(entry.material.get_shader_parameter("atmosphere_edge_adjustment").is_equal_approx(Vector3(-0.25, 0.8, 1.4)), theme + " independent outer edge controls")
 await frames(4)
 await capture(theme + "-trim-unlinked")
 values.merge({"ranges/enabled": true, "ranges/green/hue": 0.2, "stack/terrain_borders": false, "stack/terrain_edges": true, "stack/terrain_ledges": false}, true)
 panel.apply_values()
 for entry: Dictionary in bindings.hue_parameters:
  if entry.group in ["terrain_borders", "terrain_ledges"]: check(not entry.material.get_shader_parameter("atmosphere_ranges_enabled"), theme + " trim can opt out of selective Hue")
  if entry.material.get_meta("atmosphere_trim_split", false): check(entry.material.get_shader_parameter("atmosphere_edge_ranges_enabled"), theme + " edges can stack with Hue independently")
 panel.set_value("link/terrain_trim", true)
 check(not panel.widgets["hue/terrain_edges"].editable and not panel.widgets["hue/terrain_ledges"].editable, theme + " linked UI uses Borders as the master")
 panel.set_value("link/terrain_trim", false)
 check(panel.widgets["hue/terrain_edges"].editable and is_equal_approx(values["hue/terrain_edges"], -0.25), theme + " unlink restores independent values")
 var registry := preload("res://scripts/atmosphere/variants.gd").new()
 registry.directory = "user://trim-regression"
 var record: Dictionary = registry.baseline()
 for key: String in values:
  if key == "link/terrain_trim" or key.ends_with("/terrain_edges") or key.ends_with("/terrain_ledges") or key.ends_with("/terrain_borders"):
   record.values[key] = values[key]
 var records: Array[Dictionary] = [record]
 check(registry.save(theme, records, registry.revision(theme)) and registry.read(theme) == records, theme + " separate and linked trim controls save/reload: " + registry.error)
 panel.reset_values()

func check_baked_act(path: String, document: Resource, theme: String, fingerprint: String) -> void:
  const Bake := preload("res://scripts/endless/geometry_bake.gd")
  var baked: Resource = load(path)
  check(baked is Bake and baked.matches(document, theme, fingerprint), theme + " has a fresh disk recipe")
  if not baked is Bake: return
  var container := Node3D.new()
  var scenery := Node3D.new()
  scenery.set_meta("atmosphere_scenery", "local")
  container.add_child(scenery)
  var nodes: Array[Node] = []
  for index in baked.visual_recipe.records.size():
   baked.visual_recipe.instantiate_one(index, nodes, scenery if baked.visual_recipe.records[index].get("background", false) else container)
  for node: Node in nodes:
   var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D else null)
   if mesh == null: continue
   for surface in mesh.get_surface_count():
    var material: Material = node.material_override if node.material_override != null else mesh.surface_get_material(surface)
    if material == null or not material.get_meta("atmosphere_trim_split", false): continue
    var arrays: Array = mesh.surface_get_arrays(surface)
    check(arrays[Mesh.ARRAY_TEX_UV2] != null and arrays[Mesh.ARRAY_TEX_UV2].size() == arrays[Mesh.ARRAY_VERTEX].size(), theme + " disk recipe retains outer/interior trim roles")
  var bindings := preload("res://scripts/atmosphere/material_bindings.gd").new()
  bindings.collect(container, theme)
  var light := DirectionalLight3D.new()
  bindings.apply_palette({"hue/terrain": 0.25, "brightness/terrain": 0.4, "hue/decor": -0.3, "brightness/decor": 0.7, "ranges/enabled": true, "ranges/green/hue": 0.2}, light, false)
  var groups := {}
  for entry: Dictionary in bindings.hue_parameters:
   groups[entry.group] = true
   if entry.material is ShaderMaterial:
    check(is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_hue")), -0.3 if entry.group == "decor" else (0.25 if entry.group.begins_with("terrain_") else 0.0)), theme + " baked hue reaches " + entry.group)
    check(is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_brightness")), 0.7 if entry.group == "decor" else (0.4 if entry.group.begins_with("terrain_") else 1.0)), theme + " baked brightness reaches " + entry.group)
   elif not entry.group.is_empty():
    check(entry.material.albedo_color != entry.base or entry.base == Color.BLACK, theme + " baked standard surface responds")
  for group: String in (["terrain_ground", "terrain_upper", "terrain_walls", "terrain_borders", "decor"] if "First Try Smooth Decor" in path else ["terrain_ground", "terrain_walls"]):
   check(groups.has(group), theme + " baked recipe retains " + group)
  for material: ShaderMaterial in bindings.range_materials:
   check(material.get_shader_parameter("atmosphere_ranges_enabled") == true, theme + " baked surface participates in color ranges")
   if material.get_meta("atmosphere_trim_split", false):
    check(material.get_shader_parameter("atmosphere_edge_adjustment").is_equal_approx(Vector3(0.25, 1.0, 0.4)), theme + " baked edge trim inherits Terrain")
  for source: Material in bindings.materials:
   if source is ShaderMaterial and source.has_meta("atmosphere_hue"):
    var brightness = source.get_shader_parameter("atmosphere_brightness")
    check(brightness == null or is_equal_approx(float(brightness), 1.0), theme + " cached recipe stays neutral")
  bindings.restore()
  light.free()
  container.free()
