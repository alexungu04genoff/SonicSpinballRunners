extends SceneTree
const Registry := preload("res://scripts/atmosphere/variants.gd")
const EXPECTED := {
 "green_hill": ["local_sand", "rock_tint"],
 "chemical_plant": ["industrial_body", "industrial_metal", "industrial_trim"],
 "rooftop_run": ["architecture_tint", "roof_tint"],
 "casino_night": ["skyline_tint", "metal_tint"],
 "sky_sanctuary": ["ruin_stone", "ruin_haze"],
 "ice_cap": ["snow_tint", "ice_tint", "ridge_tint"],
 "lava_reef": ["rock_tint", "metal_tint"],
 "aquarium_park": ["architecture_tint", "roof_tint"],
}
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func run() -> void:
 var palette := preload("res://scripts/themes/theme_atmosphere.gd")
 var source := StandardMaterial3D.new()
 palette.color(source, "ruin_stone", "tint")
 var copy: Material = source.duplicate()
 palette.tag(copy, "albedo_color", "ruin_haze", "haze")
 check(source.get_meta("atmosphere_bindings").albedo_color.key == "ruin_stone", "Retagging a copy preserves source palette ownership")
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(game)
 paused = true
 var registry := Registry.new()
 registry.directory = "user://local-palette-regression"
 for theme: String in EXPECTED:
  game.set_theme(theme)
  var panel = game.lighting_controls
  var bindings = panel.emission
  var values := {}
  for role: String in EXPECTED[theme]:
   var key := "palette/" + role
   check(panel.widgets.has(key), theme + " exposes " + role)
   values[key] = Color(0.25, 0.65, 0.9)
   values["stack/" + key] = false
  bindings.apply_palette(values, game.presentation._key_light, false)
  for entry: Dictionary in bindings.palette_parameters:
   var expected: Variant = entry.base
   if values.has(entry.key):
    if entry.mode == "tint": expected = entry.base * values[entry.key]
    elif entry.mode == "haze": expected = entry.unhazed.lerp(values[entry.key], entry.amount)
    else: expected = values[entry.key]
   if entry.has("tint_key"):
    expected = (entry.unhazed * values.get(entry.tint_key, Color.WHITE)).lerp(values.get(entry.key, bindings.palette_originals[entry.key]), entry.amount)
   var actual: Variant = entry.target.get_shader_parameter(entry.property) if entry.shader else entry.target.get(entry.property)
   if actual is Color and expected is Color:
    check(actual.is_equal_approx(expected), theme + " responds without changing unrelated colors: " + entry.key)
  var record := Registry.baseline()
  record.values = values
  var records: Array[Dictionary] = [record]
  check(registry.save(theme, records, registry.revision(theme)) and registry.read(theme) == records, theme + " saved palette round trip")
  bindings.apply_palette({}, game.presentation._key_light, false)
  for entry: Dictionary in bindings.palette_parameters:
   var actual: Variant = entry.target.get_shader_parameter(entry.property) if entry.shader else entry.target.get(entry.property)
   if actual is Color and entry.base is Color: check(actual.is_equal_approx(entry.base), theme + " neutral restores source")
  print("LOCAL_PALETTE_THEME | ", theme)
 for i in 6: await process_frame
 game.free()
 print("LOCAL_PALETTE | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
