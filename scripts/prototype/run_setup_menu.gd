extends VBoxContainer
## Run setup lives inside the session's existing scroll panel.
signal changed
signal validation_frame
signal validation_draw
const Plan = preload("res://scripts/prototype/run_plan.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
const Bake = preload("res://scripts/endless/geometry_bake.gd")
var configuration: RefCounted
var paths: Array
var start_button: Button
var reason: Label
var zones: SpinBox
var theme_checks := {}
var act_checks := {}
var atmosphere_choices := {}
var run_length: Label
var advanced: VBoxContainer
var bake_errors := {}
var theme_fingerprints := {}
var theme_validity := {}
var generation := 0
var checking := false
var inspect_bakes := OS.has_feature("editor")

func _ready() -> void:
 RenderingServer.frame_post_draw.connect(_after_draw)

func _process(_delta: float) -> void:
 validation_frame.emit()

func _after_draw() -> void:
 validation_draw.emit()

func configure(value: RefCounted, available: Array, start: Button) -> void:
 configuration = value
 paths = available
 start_button = start
 add_theme_constant_override("separation", 8)
 var row := HBoxContainer.new()
 add_child(row)
 var title := Label.new()
 title.text = "Run length "
 row.add_child(title)
 zones = SpinBox.new()
 zones.min_value = 1
 zones.max_value = 7
 zones.step = 1
 zones.suffix = "Zones"
 zones.value = configuration.zone_count
 row.add_child(zones)
 run_length = Label.new()
 row.add_child(run_length)
 zones.value_changed.connect(func(count: float): configuration.zone_count = int(count); _changed())
 var extras_start := get_child_count()
 _label("Themes and atmospheres")
 _selection_actions(theme_checks)
 var themes := GridContainer.new()
 themes.columns = 2
 add_child(themes)
 for id: String in Plan.Configuration.Profile.theme_ids():
  var check := CheckBox.new()
  check.text = Registry.NAMES[Registry.IDS.find(id)]
  check.button_pressed = id in configuration.selected_theme_ids
  theme_checks[id] = check
  themes.add_child(check)
  check.toggled.connect(func(_selected: bool): _changed())
  var choice := OptionButton.new()
  choice.add_item("Random atmosphere")
  choice.set_item_metadata(0, "")
  for record: Dictionary in preload("res://scripts/atmosphere/variants.gd").new().read(id):
   choice.add_item(record.name)
   choice.set_item_metadata(choice.item_count - 1, record.id)
   if configuration.atmosphere_overrides.get(id, "") == record.id: choice.select(choice.item_count - 1)
  choice.tooltip_text = "Random uses saved variant weights. A named atmosphere stays fixed for this theme."
  atmosphere_choices[id] = choice
  themes.add_child(choice)
  choice.item_selected.connect(func(index: int):
   var variant_id: String = choice.get_item_metadata(index)
   if variant_id.is_empty(): configuration.atmosphere_overrides.erase(id)
   else: configuration.atmosphere_overrides[id] = variant_id
   _changed())
 _label("Levels · choose at least 3")
 _selection_actions(act_checks)
 var scroll := ScrollContainer.new()
 scroll.custom_minimum_size.y = 170
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 add_child(scroll)
 var acts := VBoxContainer.new()
 acts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(acts)
 for path: String in paths:
  var check := CheckBox.new()
  check.text = path.get_file().get_basename()
  check.tooltip_text = path
  check.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  check.button_pressed = path in configuration.selected_act_paths
  act_checks[path] = check
  acts.add_child(check)
  check.toggled.connect(func(_selected: bool): _changed())
 var reset := Button.new()
 reset.text = "Reset run setup"
 reset.pressed.connect(func():
  zones.set_value_no_signal(2)
  configuration.zone_count = 2
  for id: String in theme_checks: theme_checks[id].set_pressed_no_signal(id in Plan.Configuration.Profile.default_themes())
  configuration.atmosphere_overrides.clear()
  for choice: OptionButton in atmosphere_choices.values(): choice.select(0)
  for path: String in act_checks: act_checks[path].set_pressed_no_signal(true)
  _changed())
 add_child(reset)
 advanced = VBoxContainer.new()
 advanced.add_theme_constant_override("separation", 8)
 for child: Node in get_children().slice(extras_start):
  remove_child(child)
  advanced.add_child(child)
 var customize := Button.new()
 customize.text = "Customize"
 customize.custom_minimum_size.y = 36
 customize.pressed.connect(func():
  advanced.visible = not advanced.visible
  customize.text = "Done" if advanced.visible else "Customize")
 add_child(customize)
 add_child(advanced)
 advanced.hide()
 reason = _label("")
 reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 reason.custom_minimum_size.x = 480
 _changed()

func _label(text: String) -> Label:
 var label := Label.new()
 label.text = text
 add_child(label)
 return label

func _selection_actions(checks: Dictionary) -> void:
 var row := HBoxContainer.new()
 add_child(row)
 for selected: bool in [true, false]:
  var button := Button.new()
  button.text = "Select all" if selected else "Select none"
  button.pressed.connect(func():
   for check: CheckBox in checks.values(): check.set_pressed_no_signal(selected)
   _changed())
  row.add_child(button)

func _changed() -> void:
 run_length.text = " · %d Acts" % (configuration.zone_count * Plan.ACTS_PER_ZONE)
 for id: String in atmosphere_choices: atmosphere_choices[id].disabled = not theme_checks[id].button_pressed
 configuration.selected_theme_ids = []
 configuration.selected_act_paths = []
 for id: String in Registry.IDS:
  if theme_checks.has(id) and theme_checks[id].button_pressed: configuration.selected_theme_ids.append(id)
 for path: String in paths:
  if act_checks.has(path) and act_checks[path].button_pressed: configuration.selected_act_paths.append(path)
 changed.emit()
 generation += 1
 start_button.disabled = true
 var error: String = configuration.validation_error()
 reason.text = error if not error.is_empty() else "Loading…"
 if not checking: _validate(generation)

func _validate(ticket: int) -> void:
 start_button.disabled = true
 checking = true
 var error: String = configuration.validation_error()
 if error.is_empty():
  var documents: Array = []
  for path: String in configuration.selected_act_paths:
   var loaded: Dictionary = Plan.Document.load_document(path)
   if loaded.document == null:
    error = loaded.error
    break
   documents.append(loaded.document)
  if error.is_empty(): error = Plan.pool_error(documents)
 if error.is_empty():
  reason.text = "Loading…"
  var selected_paths: Array = configuration.selected_act_paths.duplicate()
  var selected_themes: Array = configuration.selected_theme_ids.duplicate()
  for theme: String in selected_themes:
   for path: String in selected_paths:
    if inspect_bakes: await validation_frame
    if is_queued_for_deletion(): return
    if ticket != generation:
     _validate(generation)
     return
    var key := theme + ":" + path
    if not bake_errors.has(key):
     bake_errors[key] = await _bake_error(path, theme)
     if is_queued_for_deletion(): return
     if ticket != generation:
      _validate(generation)
      return
    if not bake_errors[key].is_empty():
     error = bake_errors[key]
     break
   if not error.is_empty(): break
 checking = false
 reason.text = error if not error.is_empty() else "%d Acts" % (configuration.zone_count * 3)
 reason.visible = not error.is_empty()
 start_button.disabled = not error.is_empty()

func _bake_error(path: String, theme: String) -> String:
 var message := "Baked data missing or outdated for %s / %s. Run Bake Prototype.cmd." % [path.get_file(), theme.replace("_", " ")]
 if ProjectSettings.has_setting("playtest/themes"): message = "Level data is missing. Please use a fresh copy of the game."
 if not ResourceLoader.exists(Bake.theme_path(theme)) or not ResourceLoader.exists(Bake.path_for(path, theme)): return message
 # Export verifies every bake in the immutable package. Loading all their meshes
 # and textures again here delays Play and discards them before the run starts.
 # The runtime loader still validates each requested bake before using it.
 # Editable projects retain the full inspection to catch stale authoring data.
 if not inspect_bakes: return ""
 if not theme_fingerprints.has(theme):
  theme_fingerprints[theme] = Bake.pipeline_hash(theme)
 var fingerprint: String = theme_fingerprints[theme]
 if not theme_validity.has(theme):
  var background: Resource = await _read_bake(Bake.theme_path(theme))
  theme_validity[theme] = background is Bake and background.kind == "theme" and background.matches_pipeline(theme, fingerprint) and background.visual_recipe != null and background.visual_recipe.has_warm_manifest() and background.preload_recipe != null and background.preload_recipe.has_warm_manifest()
 if not theme_validity[theme]: return message
 var document: Resource = Plan.Document.load_document(path).document
 var baked: Resource = await _read_bake(Bake.path_for(path, theme))
 if document == null or not baked is Bake or not baked.matches(document, theme, fingerprint) or not baked.has_validated_collisions(document) or baked.visual_recipe == null or not baked.visual_recipe.has_warm_manifest(): return message
 return ""

func _read_bake(path: String) -> Resource:
 var result: Resource = ResourceLoader.load(path)
 # Let queued texture uploads complete before an inspection can release them.
 # Validation yields between combinations; no bake resources are retained by the menu.
 if DisplayServer.get_name() != "headless": await validation_draw
 return result
