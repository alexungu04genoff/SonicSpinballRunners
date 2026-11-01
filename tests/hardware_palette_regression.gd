extends SceneTree
const Gimmicks := preload("res://scripts/authored_act/gimmick_models.gd")
const Objects := preload("res://scripts/act_editor/gameplay_objects.gd")
const Bindings := preload("res://scripts/atmosphere/material_bindings.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func run() -> void:
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(game)
 paused = true
 for theme: String in game.ThemeRegistry.IDS:
  game.set_theme(theme)
  var fixture := Node3D.new()
  root.add_child(fixture)
  var pinball: Dictionary = preload("res://scripts/pinball_models.gd").materials(theme)
  for slot: String in pinball:
   var mesh := MeshInstance3D.new()
   mesh.mesh = BoxMesh.new()
   mesh.material_override = pinball[slot]
   fixture.add_child(mesh)
  var entries := []
  for type: String in ["one_way_gate", "switch_target", "wall_switch", "spring", "lane_barrier", "diverter", "dash_panel"]:
   var item := {"type": type, "object_id": type, "position": Vector2.ZERO, "rotation_degrees": 0.0, "properties": Objects.defaults(type), "pulse": 0.0, "active": false, "open": false, "state": "a", "pending_state": "", "complete": false, "lanes": [{"lit": false}]}
   entries.append(Gimmicks.build(game.presentation, fixture, item))
  var mechanics := preload("res://scripts/authored_act/mechanics_presentation.gd").new()
  fixture.add_child(mechanics)
  mechanics.table = game.presentation
  var rail_properties := Objects.defaults("elevated_rail")
  await mechanics._rail({"object_id": "palette_test", "properties": rail_properties, "path": preload("res://scripts/authored_act/rail_path.gd").build(rail_properties.points)})
  mechanics._spinner({"position": Vector2.ZERO, "rotation_degrees": 0.0, "properties": Objects.defaults("spinner"), "angle": 0.0})
  for mode: String in ["attract", "repel"]:
   mechanics._field({"position": Vector2.ZERO, "properties": {"mode": mode, "radius": 100.0}})
  for field: Dictionary in mechanics.fields:
   for mesh: Node in field.arcs.get_parent().find_children("*", "GeometryInstance3D", true, false):
    check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and is_equal_approx(mesh.material_override.albedo_color.a, 0.2), "Magnetic visuals are 20% opaque and shadowless")
  var bindings := Bindings.new()
  bindings.collect(fixture, theme)
  var values := {}
  for key: String in bindings.palette_originals: values[key] = Color("c98e30")
  bindings.apply_palette(values, game.presentation._key_light, false)
  for entry: Dictionary in bindings.palette_parameters:
   var actual: Variant = entry.target.get_shader_parameter(entry.property) if entry.shader else entry.target.get(entry.property)
   check(actual.is_equal_approx(Color("c98e30")), theme + " cosmetic slot responds: " + entry.key)
  values["ranges/enabled"] = true
  values["ranges/yellow/hue"] = 0.3
  for key: String in bindings.palette_originals: values["stack/" + key] = false
  bindings.apply_palette(values, game.presentation._key_light, false)
  for material: ShaderMaterial in bindings.range_materials:
   if not str(material.get_meta("atmosphere_hue", "")).is_empty(): continue
   check(not material.get_shader_parameter("atmosphere_ranges_enabled"), "Cosmetic palette can opt out of selective Hue")
  values.merge({"hue/ramps": 0.4, "saturation/ramps": 0.5, "brightness/ramps": 1.5, "stack/ramps": false})
  bindings.apply_palette(values, game.presentation._key_light, false)
  var ramp_count := 0
  for entry: Dictionary in bindings.hue_parameters:
   if entry.group != "ramps": continue
   ramp_count += 1
   if entry.material is ShaderMaterial:
    check(is_equal_approx(entry.material.get_shader_parameter("atmosphere_hue"), 0.4) and is_equal_approx(entry.material.get_shader_parameter("atmosphere_saturation"), 0.5) and is_equal_approx(entry.material.get_shader_parameter("atmosphere_brightness"), 1.5), theme + " ramp adjustments reach deck")
    check(not entry.material.get_shader_parameter("atmosphere_ranges_enabled"), theme + " ramp can opt out of selective Hue")
  check(ramp_count > 0, theme + " has a ramp surface binding")
  var registry := preload("res://scripts/atmosphere/variants.gd").new()
  registry.directory = "user://hardware-palette-regression"
  var record: Dictionary = registry.baseline()
  record.values = values
  var records: Array[Dictionary] = [record]
  check(registry.save(theme, records, registry.revision(theme)) and registry.read(theme) == records, theme + " cosmetic palette saves and reloads")
  for entry: Dictionary in entries:
   Gimmicks.update(entry)
   if entry.kind == "switch": check(entry.material.albedo_color == Color(entry.color).darkened(0.3), "Authored switch identity survives")
   if entry.kind == "diverter":
    check(entry.indicator.albedo_color == Color("5af1cb"), "Normal diverter identity")
    entry.item.pending_state = "b"
    Gimmicks.update(entry)
    check(entry.indicator.albedo_color == Color("ffc84c"), "Pending diverter identity")
   if entry.kind == "lanes":
    entry.item.complete = true
    Gimmicks.update(entry)
    check(entry.lights[0].albedo_color == Color("b6fff1"), "Completed lane identity")
   if entry.kind == "dash_panel":
    entry.item.pulse = 0.1
    Gimmicks.update(entry)
    check(is_equal_approx(entry.emitters[0].get_active_material(0).emission_energy_multiplier, 3.5), "Edited dash chevrons still pulse")
  bindings.restore()
  fixture.free()
 for i in 6: await process_frame
 game.free()
 print("HARDWARE_PALETTE | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
