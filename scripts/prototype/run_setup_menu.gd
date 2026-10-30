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
var bake_errors := {}
var theme_fingerprints := {}
var theme_validity := {}
var generation := 0
var checking := false

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
 _label("RUN SETUP · 3 Acts per Zone")
 var row := HBoxContainer.new()
 add_child(row)
 var title := Label.new()
 title.text = "Zones: "
 row.add_child(title)
 zones = SpinBox.new()
 zones.min_value = 1
 zones.max_value = 7
 zones.step = 1
 zones.value = configuration.zone_count
 row.add_child(zones)
 zones.value_changed.connect(func(count: float): configuration.zone_count = int(count); _changed())
 _label("Themes")
 _selection_actions(theme_checks)
 var themes := GridContainer.new()
 themes.columns = 2
 add_child(themes)
 for i in Registry.IDS.size():
  var id: String = Registry.IDS[i]
  var check := CheckBox.new()
  check.text = Registry.NAMES[i]
  check.button_pressed = id in configuration.selected_theme_ids
  theme_checks[id] = check
  themes.add_child(check)
  check.toggled.connect(func(_selected: bool): _changed())
 _label("Acts · select at least 3")
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
  var document: Resource = Plan.Document.load_document(path).document
  check.text = "%s · %s" % [document.title, path.get_file()]
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
  for id: String in theme_checks: theme_checks[id].set_pressed_no_signal(id in Plan.THEMES)
  for path: String in act_checks: act_checks[path].set_pressed_no_signal(true)
  _changed())
 add_child(reset)
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
 reason.text = error if not error.is_empty() else "Checking existing baked data…"
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
  reason.text = "Checking existing baked data…"
  var selected_paths: Array = configuration.selected_act_paths.duplicate()
  var selected_themes: Array = configuration.selected_theme_ids.duplicate()
  for theme: String in selected_themes:
   for path: String in selected_paths:
    await validation_frame
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
 reason.text = error if not error.is_empty() else "%d Acts · targets 1,000–%s" % [configuration.zone_count * 3, Plan.target(configuration.zone_count * 3 - 1)]
 start_button.disabled = not error.is_empty()

func _bake_error(path: String, theme: String) -> String:
 var message := "Baked data missing or outdated for %s / %s. Run Bake Prototype.cmd." % [path.get_file(), theme.replace("_", " ")]
 if not ResourceLoader.exists(Bake.theme_path(theme)) or not ResourceLoader.exists(Bake.path_for(path, theme)): return message
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
