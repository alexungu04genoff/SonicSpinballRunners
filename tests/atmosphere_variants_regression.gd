extends SceneTree
const Variants := preload("res://scripts/atmosphere/variants.gd")
const Plan := preload("res://scripts/prototype/run_plan.gd")
const Bake := preload("res://scripts/endless/geometry_bake.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
 var registry := Variants.new()
 registry.directory = "user://variant-regression"
 var records: Array[Dictionary] = [Variants.baseline(), {"id": "pink", "name": "Pink", "enabled": true, "weight": 3.0, "values": {"hue/terrain": 0.7, "hue/neon": -0.7, "hue/decor": 0.1, "brightness/decor": 3.0, "brightness/terrain_ground": 1.3}}]
 var hash_before := Bake.pipeline_hash("ice_cap")
 records[0].values = {"brightness/decor": 1.2}
 records[1].values.merge({"ranges/enabled": true, "ranges/green/hue": -0.7, "ranges/green/saturation": 0.5, "ranges/green/brightness": 3.0})
 check(registry.save("ice_cap", records, registry.revision("ice_cap")), "Save project-shaped variant fixture")
 check(registry.read("ice_cap") == records, "Inspectable values round trip")
 check(is_equal_approx(Variants.chance(records, "pink"), 0.75), "Weights derive probabilities")
 var stale := registry.revision("ice_cap")
 records[1].name = "Pink Dusk"
 check(registry.save("ice_cap", records, stale), "Rename preserves ID")
 check(not registry.save("ice_cap", records, stale), "Reject concurrent write")
 for items: Array in [[records[1]], [Variants.baseline(), records[1], records[1]]]:
  var bad: Array[Dictionary] = []
  bad.assign(items)
  check(not Variants.validate("ice_cap", bad).is_empty(), "Protect baseline and unique IDs")
 var invalid := records.duplicate(true)
 invalid[0].weight = 0
 invalid[1].enabled = false
 check(not Variants.validate("ice_cap", invalid).is_empty(), "Reject empty weighted pool")
 invalid = records.duplicate(true)
 invalid[1].weight = -1
 check(not Variants.validate("ice_cap", invalid).is_empty(), "Reject negative weights")
 invalid = records.duplicate(true)
 invalid[0].name = "Renamed Default"
 check(not Variants.validate("ice_cap", invalid).is_empty(), "Default identity is protected")
 check(registry.choose("ice_cap", 1, 0, "default").values == records[0].values, "Runtime selection uses edited Default values")
 check(Bake.pipeline_hash("ice_cap") == hash_before, "Atmosphere content does not change topology receipt")
 if "--production-fixture" in OS.get_cmdline_user_args():
  # Exercise the real production location, restoring exact bytes before any run.
  var production := Variants.new()
  var original_file := FileAccess.get_file_as_string(production.path("ice_cap"))
  var production_records := production.read("ice_cap")
  var fixture := records[1].duplicate(true)
  fixture.id = "regression_fixture"
  fixture.name = "Regression fixture"
  fixture.enabled = false
  production_records.append(fixture)
  check(production.save("ice_cap", production_records, production.revision("ice_cap")), "Add a named production-location asset")
  check(Bake.pipeline_hash("ice_cap") == hash_before, "Adding production content leaves bake receipt unchanged")
  production_records[-1].values["hue/terrain"] = -0.35
  check(production.save("ice_cap", production_records, production.revision("ice_cap")), "Edit production-location colors")
  check(Bake.pipeline_hash("ice_cap") == hash_before, "Editing production content leaves bake receipt unchanged")
  FileAccess.open(production.path("ice_cap"), FileAccess.WRITE).store_string(original_file)
  check(FileAccess.get_file_as_string(production.path("ice_cap")) == original_file, "Production fixture restores exact source")
 seed(123)
 var expected := [randi(), randi()]
 seed(123)
 check(randi() == expected[0], "Seed fixture")
 var pink := 0
 for index in 400:
  var chosen := registry.choose("ice_cap", index, 2)
  check(chosen == registry.choose("ice_cap", index, 2), "Same seed reproduces selection")
  if chosen.id == "pink": pink += 1
 check(pink > 260 and pink < 340, "Weighted distribution roughly matches 3:1")
 check(randi() == expected[1], "Atmosphere selection isolates global RNG")
 records[1].enabled = false
 records[1].weight = 0.0
 check(registry.save("ice_cap", records, registry.revision("ice_cap")), "Disabled experiments remain stored")
 check(registry.choose("ice_cap", 18, 0).id == "default", "Disabled excluded")
 check(registry.choose("ice_cap", 18, 0, "pink").id == "pink", "Explicit playtest bypasses weights")
 var paths := Plan.source_paths()
 var documents: Array = []
 for path: String in paths: documents.append(Plan.Document.load_document(path).document)
 var configuration := Plan.Configuration.new(paths)
 configuration.zone_count = 7
 var course := Plan.build(documents, 18, configuration)
 check(course == Plan.build(documents, 18, configuration), "Full course determinism")
 for index in course.size():
  check(course[index].atmosphere == course[(index / 3) * 3].atmosphere, "One atmosphere per Zone")
 if DisplayServer.get_name() != "headless":
  material_ownership()
  await lab(registry)
 print("ATMOSPHERE_VARIANTS | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func material_ownership() -> void:
 var container := Node3D.new()
 root.add_child(container)
 var neon := StandardMaterial3D.new()
 neon.albedo_color = Color("ff2288")
 neon.emission_enabled = true
 neon.emission = neon.albedo_color
 preload("res://scripts/themes/theme_atmosphere.gd").color(neon, "neon_pink")
 var hazard := StandardMaterial3D.new()
 hazard.albedo_color = Color.YELLOW
 for index in 3:
  var node := MeshInstance3D.new()
  node.mesh = BoxMesh.new()
  node.material_override = neon if index < 2 else hazard
  container.add_child(node)
 var bindings := preload("res://scripts/atmosphere/material_bindings.gd").new()
 bindings.collect(container, "casino_night")
 var light := DirectionalLight3D.new()
 bindings.apply_palette({"hue/neon": 0.3}, light, false)
 var copies := bindings.materials.size()
 bindings.append_root(container)
 check(bindings.materials.size() == copies, "Incremental attachment never copies an already-bound node twice")
 check(container.get_child(0).material_override == container.get_child(1).material_override, "Decor instances share one edited material")
 check(container.get_child(0).material_override.albedo_color != neon.albedo_color, "Decorative neon hue changes")
 check(container.get_child(0).material_override.emission != neon.emission, "Neon emission hue follows albedo")
 check(neon.albedo_color == Color("ff2288"), "Source material remains authored")
 bindings.apply_palette({"brightness/neon": 0.5}, light, false)
 check(container.get_child(0).material_override.albedo_color.is_equal_approx(Color(neon.albedo_color.r * 0.5, neon.albedo_color.g * 0.5, neon.albedo_color.b * 0.5, neon.albedo_color.a)), "Neon brightness scales color while retaining alpha")
 for group: String in ["background", "foliage"]:
  check(bindings.shifted(Color(0.8, 0.4, 0.2, 0.7), {"brightness/" + group: 0.5}, group).is_equal_approx(Color(0.4, 0.2, 0.1, 0.7)), group + " brightness retains alpha")
 check(container.get_child(2).material_override == hazard and hazard.albedo_color == Color.YELLOW, "Untagged hazard/readability materials excluded")
 var choices := {"hue/terrain": 0.1, "override/terrain_walls": true, "hue/terrain_walls": -0.3}
 check(bindings.resolved_group(choices, "terrain_ground") == "terrain", "Disabled category inherits Terrain")
 check(bindings.resolved_group(choices, "terrain_walls") == "terrain_walls", "Enabled wall override is independent")
 bindings.restore()
 light.free()
 container.free()

func lab(registry: RefCounted) -> void:
 root.size = Vector2i(1280, 900)
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(game)
 await process_frame
 var panel = game.lighting_controls
 var variants = panel.variants
 variants.registry = registry
 variants.contexts.clear()
 game.set_theme("ice_cap")
 var identity := [game.ball.get_instance_id(), game.presentation.get_instance_id(), game.presentation.camera.transform, game.presentation.scenery_root.get_instance_id()]
 variants.context.selected = "default"
 variants.load_selected()
 panel._select_look(2)
 check(panel.values != panel.originals and not panel.look_selector.disabled, "Default accepts atmosphere presets")
 panel.set_value("hue/terrain", 0.7)
 variants.save_variant()
 check(registry.error.is_empty() and registry.read("ice_cap")[0].values["hue/terrain"] == 0.7, "Save edited Default")
 panel.set_value("hue/terrain", -0.7)
 variants.revert()
 check(is_equal_approx(panel.values["hue/terrain"], 0.7), "Default Revert restores saved appearance")
 panel.reset_values()
 check(panel.values == panel.originals, "Default Reset restores authored appearance in draft")
 variants.revert()
 variants.create(true)
 variants.title.text = "Probe " + str(Time.get_ticks_usec())
 panel.set_value("hue/terrain", 0.3)
 panel.set_value("hue/neon", 0.2)
 variants.save_variant()
 check(registry.error.is_empty(), "Lab Save Variant")
 var selected: String = variants.context.selected
 panel.set_value("hue/terrain", -0.2)
 variants.revert()
 check(is_equal_approx(panel.values["hue/terrain"], 0.3), "Revert unsaved edits")
 check(identity == [game.ball.get_instance_id(), game.presentation.get_instance_id(), game.presentation.camera.transform, game.presentation.scenery_root.get_instance_id()], "Variant switch preserves gameplay/camera/scenery identities")
 panel.restore_original()
 panel.bind_theme()
 check(variants.context.selected == selected and is_equal_approx(panel.values["hue/terrain"], 0.3), "Act rebind preserves Theme variant")
 game._begin_source_switch()
 await game._load_selected_act("res://data/acts/Authored/Reverse C Spring.tres")
 check(game.theme_id == "ice_cap" and variants.context.selected == selected and is_equal_approx(panel.values["hue/terrain"], 0.3), "Loading a different Act retains Theme and variant")
 for i in 4: await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://test-results/atmosphere-variants")
 root.get_texture().get_image().save_png("res://test-results/atmosphere-variants/lab-ui.png")
 variants.remove_selected()
 check(variants.context.selected == "default", "Delete non-default")
 game.free()
