extends SceneTree
const Bindings := preload("res://scripts/atmosphere/material_bindings.gd")
const Registry := preload("res://scripts/atmosphere/variants.gd")
const OUTPUT := "res://test-results/foliage"
const SUPPORTED := ["green_hill", "rooftop_run", "sky_sanctuary", "ice_cap", "aquarium_park"]
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func frames() -> void:
 for i in 6: await process_frame
func capture(game: Node, name: String) -> void:
 await frames()
 await RenderingServer.frame_post_draw
 game.view.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png"))
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(game)
 paused = true
 var panel = game.lighting_controls
 var registry := Registry.new()
 registry.directory = "user://foliage-regression"
 for theme: String in Registry.THEMES:
  game.set_theme(theme)
  panel.variants.context.selected = "draft"
  panel.reset_values()
  check(panel.widgets.has("hue/foliage") == panel.emission.has_foliage(), theme + " UI follows actual bindings")
  if theme not in SUPPORTED: check(not panel.widgets.has("stack/foliage"), theme + " has no inert Foliage controls")
  await capture(game, theme + "-neutral")
  panel.set_value("hue/foliage", 0.3)
  panel.set_value("saturation/foliage", 0.6)
  panel.set_value("brightness/foliage", 0.7)
  await capture(game, theme + "-shifted")
  # Exercise every prop, including variants not selected by this Act's seed.
  var skin = game.presentation.theme_definition.create_decor(game.presentation)
  var fixture := Node3D.new()
  root.add_child(fixture)
  fixture.hide()
  var variants := {}
  for size: Dictionary in skin.pools.values():
   for pool: Array in size.values():
    for variant: String in pool: variants[variant] = true
  for variant: String in variants:
   var prop: Node3D = skin.factory.call(variant)
   fixture.add_child(prop)
   skin._bind_atmosphere(prop)
  var bindings := Bindings.new()
  bindings.collect(fixture, theme)
  check(bindings.has_foliage() == (theme in SUPPORTED), theme + " audited all prop variants")
  var values := {"hue/foliage": 0.3, "saturation/foliage": 0.6, "brightness/foliage": 0.7, "ranges/enabled": true, "ranges/green/hue": 0.2}
  bindings.apply_palette({}, game.presentation._key_light, false)
  var inputs := []
  for entry: Dictionary in bindings.palette_parameters:
   if entry.key == "palette/vegetation_tint": inputs.append([entry, (entry.target.get_shader_parameter(entry.property) if entry.shader else entry.target.get(entry.property))])
  bindings.apply_palette(values, game.presentation._key_light, false)
  for entry: Dictionary in bindings.hue_parameters:
   if entry.material is BaseMaterial3D:
    check(entry.material.albedo_color.is_equal_approx(Bindings.shifted(entry.base, values, entry.group)), theme + " standard surface shifts once")
    continue
   check(is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_hue")), 0.3 if entry.group == "foliage" else 0.0), theme + " only plant tissue changes")
   check(is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_brightness")), 0.7 if entry.group == "foliage" else 1.0), theme + " independent brightness")
  for item: Array in inputs:
   var entry: Dictionary = item[0]
   if entry.shader:
    check(entry.target.get_shader_parameter(entry.property) == item[1], "Textured vegetation tint is not shifted before the final surface")
   else:
    check(entry.target.get(entry.property).is_equal_approx(Bindings.shifted(item[1], values, "foliage")), "Standard vegetation palette shifts exactly once")
  values["stack/foliage"] = false
  bindings.apply_palette(values, game.presentation._key_light, false)
  for entry: Dictionary in bindings.hue_parameters:
   if entry.group == "foliage":
    if entry.material is ShaderMaterial: check(not entry.material.get_shader_parameter("atmosphere_ranges_enabled"), "Foliage can opt out of selective ranges")
    else: check(entry.material.albedo_color.is_equal_approx(Bindings.shifted(entry.base, values, "foliage", false)), "Standard foliage opts out of ranges")
  var records: Array[Dictionary] = [Registry.baseline(), {"id": "plants", "name": "Plants", "enabled": true, "weight": 1.0, "values": values}]
  check(registry.save(theme, records, registry.revision(theme)) and registry.read(theme) == records, theme + " named variant round trip")
  bindings.apply_palette({}, game.presentation._key_light, false)
  for entry: Dictionary in bindings.hue_parameters:
   if entry.material is BaseMaterial3D:
    check(entry.material.albedo_color.is_equal_approx(entry.base), "Neutral standard surface restores source")
    continue
   check(is_zero_approx(float(entry.material.get_shader_parameter("atmosphere_hue"))) and is_equal_approx(float(entry.material.get_shader_parameter("atmosphere_brightness")), 1.0), "Neutral restores the source transform")
  bindings.restore()
  fixture.free()
  print("FOLIAGE_THEME | ", theme)
 await frames()
 game.free()
 print("FOLIAGE_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
