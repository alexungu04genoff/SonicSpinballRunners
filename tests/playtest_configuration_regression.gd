extends SceneTree
const Plan = preload("res://scripts/prototype/run_plan.gd")
const Profile = preload("res://scripts/prototype/build_profile.gd")
const Menu = preload("res://scripts/prototype/run_setup_menu.gd")
const Variants = preload("res://scripts/atmosphere/variants.gd")
const Palette = preload("res://scripts/themes/theme_atmosphere.gd")
const THEMES := ["casino_night", "rooftop_run", "green_hill", "aquarium_park", "ice_cap", "chemical_plant"]
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
 var old_themes: Variant = ProjectSettings.get_setting("playtest/themes")
 var old_characters: Variant = ProjectSettings.get_setting("playtest/characters")
 ProjectSettings.set_setting("playtest/themes", THEMES)
 ProjectSettings.set_setting("playtest/characters", ["sonic", "tails"])
 check(Profile.theme_ids() == THEMES and Profile.character_ids() == ["sonic", "tails"], "Export content limits are authoritative")
 check(Profile.default_themes() == THEMES, "Playtest defaults include every allowed theme")
 var paths := Plan.source_paths()
 var config := Plan.Configuration.new(paths)
 config.atmosphere_overrides = {"casino_night": "variant_1410883925", "green_hill": "variant_176918146"}
 config.selected_theme_ids = THEMES.duplicate()
 var settings := ConfigFile.new()
 config.write_preferences(settings, paths)
 var restored := Plan.Configuration.new(paths)
 restored.read_preferences(settings, paths)
 check(restored.snapshot() == config.snapshot(), "Named atmosphere choices survive preferences")
 settings.set_value("run_setup", "atmosphere_overrides", {"casino_night": "removed_variant", "lava_reef": "default"})
 restored.read_preferences(settings, paths)
 check(restored.atmosphere_overrides.is_empty(), "Removed variants and excluded themes do not poison saved setup")
 config.selected_theme_ids.append("lava_reef")
 check(not config.validation_error().is_empty(), "Unavailable theme is rejected")
 config.selected_theme_ids.erase("lava_reef")
 var documents: Array = []
 for path: String in paths: documents.append(Plan.Document.load_document(path).document)
 for count in [1, 7]:
  config.zone_count = count
  var course := Plan.build(documents, 18, config)
  check(course.size() == count * 3, "Run length remains three Acts per Zone")
  for entry: Dictionary in course:
   check(entry.theme in THEMES, "Course excludes unavailable themes")
   if config.atmosphere_overrides.has(entry.theme):
    check(entry.atmosphere.id == config.atmosphere_overrides[entry.theme], "Course uses the player's named atmosphere")
 var registry := Variants.new()
 for theme: String in Variants.THEMES:
  var records := registry.read(theme)
  check(registry.error.is_empty(), "Imported atmospheres validate: " + theme)
  var defaults: Dictionary = records[0].values
  for record: Dictionary in records:
   if record.id == "default": continue
   for field: Array in Palette.HARDWARE_FIELDS:
    var key: String = "palette/" + field[1]
    check(record.values.get(key) == defaults.get(key), "Variant retains Default hardware: " + theme + "/" + record.name + "/" + key)
    check(record.values.get("stack/" + key) == false, "Variant hue ranges exclude hardware: " + key)
 check(registry.read("rooftop_run").any(func(record): return record.name == "Apotos"), "Import retains the local Apotos atmosphere")
 for name: String in ["GateDash", "DropTarget-SW-SP-DT"]:
  var path: String = Plan.SOURCE_DIRECTORY.path_join(name + ".tres")
  var loaded := Plan.Document.load_document(path)
  check(path in paths and loaded.document != null and loaded.document.validation_errors().is_empty(), "Imported Act remains valid and discoverable: " + name)
 var menu := Menu.new()
 var button := Button.new()
 root.add_child(menu)
 root.add_child(button)
 # Empty source selection makes validation synchronous; this test needs no bakes.
 config.selected_act_paths = []
 menu.configure(config, [], button)
 check(not menu.advanced.visible, "Customization starts collapsed")
 check(menu.theme_checks.size() == 6 and menu.atmosphere_choices.size() == 6, "Menu only shows the six allowed themes and their atmosphere pickers")
 var picker: OptionButton = menu.atmosphere_choices.casino_night
 picker.select(1)
 picker.item_selected.emit(1)
 check(config.atmosphere_overrides.casino_night == "default", "UI selects Default explicitly")
 picker.select(0)
 picker.item_selected.emit(0)
 check(not config.atmosphere_overrides.has("casino_night"), "Random restores weighted selection")
 menu.zones.value = 1
 check("3 Acts" in menu.run_length.text, "Run length updates immediately")
 menu.theme_checks.casino_night.button_pressed = false
 check(picker.disabled, "Atmosphere picker follows theme selection")
 menu.free()
 button.free()
 ProjectSettings.set_setting("playtest/themes", old_themes)
 ProjectSettings.set_setting("playtest/characters", old_characters)
 print("RESULT | Playtest configuration | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
