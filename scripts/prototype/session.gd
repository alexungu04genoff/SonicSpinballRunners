extends Control
## Player-facing session flow; the run uses the shared authored streaming engine.
const Run = preload("res://scripts/prototype/zone_run.gd")
const Telemetry = preload("res://scripts/prototype/run_telemetry.gd")
const Archive = preload("res://scripts/prototype/telemetry_archive.gd")
const Sounds = preload("res://scripts/prototype/score_sounds.gd")
const Art = preload("res://scripts/prototype/menu_style.gd")
const SETTINGS_PATH := "user://prototype_settings.cfg"
const EXPORT_DEFAULTS_PATH := "res://data/prototype_export_defaults.cfg"
const CHALLENGE_RECORDS := "two_zone_challenge_records"
const PRACTICE_RECORDS := "two_zone_practice_records"
var game: Node
var overlay: CanvasLayer
var overlay_root: Control
var state := "menu"
var transitioning := false
var selected_character := "sonic"
var sound_enabled := true
var practice_mode := false
var best_score := 0
var best_seconds := 0.0
var practice_best_score := 0
var practice_best_seconds := 0.0
var settings_path := SETTINGS_PATH
var last_summary: Dictionary = {}
var last_run_configuration: RefCounted
var copy_status: Label
var available_act_paths: Array = []
var run_configuration: RefCounted
var setup_menu: VBoxContainer
var start_button: Button
var pause_camera_picker: OptionButton
var spin_lab: PanelContainer
var start_spin_lab := false
var archive_directory := Archive.DIRECTORY
var archive_attempted := false
var archive_result := {}
var last_export := {}
var last_json := ""
var archive_status: Label
var run_feel: TextEdit
var archived_json := ""
var note_timer: Timer

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
 get_tree().auto_accept_quit = false
 get_tree().root.close_requested.connect(_quit)
 note_timer = Timer.new()
 note_timer.one_shot = true
 note_timer.wait_time = 0.6
 note_timer.timeout.connect(_flush_run_feel)
 add_child(note_timer)
 available_act_paths = Run.RunPlan.source_paths()
 if run_configuration == null: run_configuration = Run.RunPlan.Configuration.new(available_act_paths)
 var settings := ConfigFile.new()
 var settings_loaded := settings.load(settings_path) == OK
 if not settings_loaded and FileAccess.file_exists(EXPORT_DEFAULTS_PATH):
  settings_loaded = settings.load(EXPORT_DEFAULTS_PATH) == OK
 if settings_loaded and not run_configuration.single_act_test:
  run_configuration.read_preferences(settings, available_act_paths)
  var saved := str(settings.get_value("player", "character", "sonic"))
  if saved in Run.RunPlan.Configuration.Profile.character_ids(): selected_character = saved
  sound_enabled = bool(settings.get_value("player", "sound", true))
  practice_mode = bool(settings.get_value("player", "practice", false))
  # Retain existing completion records across run setups and course versions.
  practice_best_score = maxi(0, int(settings.get_value(PRACTICE_RECORDS, "score", 0)))
  practice_best_seconds = maxf(0.0, float(settings.get_value(PRACTICE_RECORDS, "seconds", 0.0)))
  best_score = maxi(0, int(settings.get_value(CHALLENGE_RECORDS, "score", 0)))
  best_seconds = maxf(0.0, float(settings.get_value(CHALLENGE_RECORDS, "seconds", 0.0)))
 if selected_character not in Run.RunPlan.Configuration.Profile.character_ids():
  selected_character = Run.RunPlan.Configuration.Profile.character_ids()[0]
 overlay = CanvasLayer.new()
 overlay.layer = 40
 add_child(overlay)
 var arguments := OS.get_cmdline_user_args()
 start_spin_lab = "--spin-lab" in arguments
 if start_spin_lab:
  selected_character = "sonic"
  for id: String in CharacterSpecials.CHARACTER_IDS:
   if "--character=" + id in arguments: selected_character = id
  preload("res://scripts/diagnostics/shadow_review.gd").position_review_window(get_window())
 var act_argument := arguments.find("--act")
 if act_argument >= 0 and act_argument + 1 < arguments.size():
  var preview_path := ""
  for argument: String in arguments:
   if argument.begins_with("--atmosphere-preview="): preview_path = argument.trim_prefix("--atmosphere-preview=")
  configure_act_test(arguments[act_argument + 1], preview_path)
  for argument: String in arguments:
   if argument.begins_with("--theme="): run_configuration.selected_theme_ids = [argument.trim_prefix("--theme=")]
   if not start_spin_lab and argument.begins_with("--character="):
    var requested := argument.trim_prefix("--character=")
    if requested in Run.RunPlan.Configuration.Profile.character_ids(): selected_character = requested
  start_run.call_deferred()
  return
 _show_menu()

func configure_act_test(path: String, preview_path := "") -> void:
 run_configuration = Run.RunPlan.Configuration.new([path])
 run_configuration.single_act_test = true
 run_configuration.zone_count = 1
 if run_configuration.atmosphere_overrides.is_empty(): run_configuration.selected_theme_ids = ["green_hill"]
 if not preview_path.is_empty():
  var loaded := preload("res://scripts/atmosphere/playtest_snapshot.gd").read_preview(preview_path)
  run_configuration.atmosphere_preview_error = loaded.error
  if loaded.error.is_empty():
   run_configuration.atmosphere_preview = loaded.preview
   run_configuration.selected_theme_ids = [loaded.preview.theme]
   run_configuration.atmosphere_overrides.clear()
 practice_mode = true

func _save_settings() -> void:
 if run_configuration.single_act_test: return # Authoring tests do not overwrite normal run preferences or records.
 var settings := ConfigFile.new()
 settings.load(settings_path) # Preserve records from previous course versions.
 run_configuration.write_preferences(settings, available_act_paths)
 settings.set_value("player", "character", selected_character)
 settings.set_value("player", "sound", sound_enabled)
 settings.set_value("player", "practice", practice_mode)
 settings.set_value(PRACTICE_RECORDS, "score", practice_best_score)
 settings.set_value(PRACTICE_RECORDS, "seconds", practice_best_seconds)
 settings.set_value(CHALLENGE_RECORDS, "score", best_score)
 settings.set_value(CHALLENGE_RECORDS, "seconds", best_seconds)
 if settings.save(settings_path) != OK: push_warning("Could not save prototype preferences.")

func _camera_settings_path() -> String:
 # Editor playtests remember their view separately from normal player settings.
 return settings_path.get_basename() + "-act-camera.cfg" if run_configuration.single_act_test else settings_path

func _read_play_camera() -> int:
 var settings := ConfigFile.new()
 var fallback := TablePresentation.CameraPreset.DRAMATIC_PINBALL
 if settings.load(_camera_settings_path()) != OK: return fallback
 var saved: Variant = settings.get_value("player", "camera_preset", fallback)
 return saved if saved is int and saved in Run.PLAY_CAMERAS else fallback

func _save_play_camera(preset: int) -> void:
 var path := _camera_settings_path()
 var settings := ConfigFile.new()
 var error := settings.load(path)
 if error != OK and error != ERR_FILE_NOT_FOUND:
  push_warning("Could not read camera preferences: " + error_string(error))
  return
 settings.set_value("player", "camera_preset", preset)
 if settings.save(path) != OK: push_warning("Could not save camera preference.")

func _panel(title: String, subtitle: String) -> VBoxContainer:
 if is_instance_valid(overlay_root):
  # A button in this panel may still be emitting pressed. Retire it after dispatch.
  overlay_root.hide()
  overlay_root.process_mode = Node.PROCESS_MODE_DISABLED
  overlay_root.queue_free()
 overlay_root = Control.new()
 overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(overlay_root)
 var backdrop := Art.new()
 backdrop.screen = state
 overlay_root.add_child(backdrop)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.follow_focus = true
 if state == "menu":
  scroll.anchor_left = 0.50
  scroll.offset_right = -24
 overlay_root.add_child(scroll)
 var center := CenterContainer.new()
 center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 center.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.add_child(center)
 var card := PanelContainer.new()
 card.theme_type_variation = &"MenuCard"
 card.custom_minimum_size.x = 550 if state == "menu" else 600
 center.add_child(card)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 10)
 card.add_child(stack)
 var header := HBoxContainer.new()
 header.add_theme_constant_override("separation", 12)
 stack.add_child(header)
 var emblem: Texture2D = {"paused": Art.PAUSE, "results": Art.TROPHY, "draft": Art.GIFT}.get(state, Art.FLAG)
 header.add_child(Art.icon(emblem, Vector2(49, 49)))
 var title_label := _label(header, title, 32, Color.WHITE)
 title_label.theme_type_variation = &"RaceTitle"
 var rule := ColorRect.new()
 rule.custom_minimum_size.y = 3
 rule.color = Color("ffce36")
 rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
 stack.add_child(rule)
 if not subtitle.is_empty(): _label(stack, subtitle, 18)
 return stack

func _label(parent: Node, text: String, size := 18, color := Color("d2e6ed")) -> Label:
 var label := Label.new()
 label.text = text
 label.add_theme_font_size_override("font_size", size)
 label.add_theme_color_override("font_color", color)
 parent.add_child(label)
 return label

func _action(parent: Node, text: String, callback: Callable, focus := false) -> Button:
 var button := Button.new()
 button.text = text
 button.custom_minimum_size.y = 42
 button.pressed.connect(callback)
 parent.add_child(button)
 if focus: button.call_deferred("grab_focus")
 return button

func _show_menu() -> void:
 state = "menu"
 var testing: bool = run_configuration.single_act_test
 var stack := _panel("ACT TEST" if testing else "RUN SETUP", "")
 _label(stack, "CHARACTER", 14, Color("a8e4ff"))
 var characters := OptionButton.new()
 characters.custom_minimum_size.y = 52
 characters.add_theme_constant_override("icon_max_width", 40)
 for id: String in Run.RunPlan.Configuration.Profile.character_ids():
  var definition: CharacterDefinition = CharacterSpecials.CHARACTERS[id]
  characters.add_icon_item(Art.face(id), definition.selection_label)
  characters.get_popup().set_item_icon_max_width(characters.item_count - 1, 32)
  characters.get_popup().set_item_tooltip(characters.item_count - 1, definition.type_action.description)
  characters.set_item_metadata(characters.item_count - 1, id)
  if id == selected_character: characters.select(characters.item_count - 1)
 characters.item_selected.connect(func(index: int):
  selected_character = characters.get_item_metadata(index)
  _save_settings()
 )
 stack.add_child(characters)
 characters.call_deferred("grab_focus")
 _label(stack, "GAME MODE", 14, Color("a8e4ff"))
 var practice := OptionButton.new()
 practice.add_item("Challenge · 3 Balls per Act")
 practice.add_item("Practice · unlimited Balls")
 practice.select(1 if practice_mode else 0)
 practice.item_selected.connect(func(index: int): practice_mode = index == 1; _save_settings())
 stack.add_child(practice)
 _label(stack, "Reach the Act target, then shoot the gold Goal Ring.", 16)
 var sound := CheckButton.new()
 sound.text = "Scoring sounds"
 sound.button_pressed = sound_enabled
 sound.toggled.connect(func(value: bool): sound_enabled = value; _save_settings())
 if testing:
  _label(stack, run_configuration.selected_act_paths[0].get_file(), 18)
  if not run_configuration.atmosphere_preview.is_empty():
   _label(stack, "Lab atmosphere: " + str(run_configuration.atmosphere_preview.get("name", "Preview")), 16)
  var themes := OptionButton.new()
  for id: String in Run.RunPlan.Configuration.Profile.theme_ids():
   themes.add_item(Run.RunPlan.Configuration.Registry.NAMES[Run.RunPlan.Configuration.Registry.IDS.find(id)])
   themes.set_item_metadata(themes.item_count - 1, id)
   if id == run_configuration.selected_theme_ids[0]: themes.select(themes.item_count - 1)
  themes.tooltip_text = "Changing theme clears the current Lab atmosphere preview."
  themes.item_selected.connect(func(index: int):
   run_configuration.selected_theme_ids = [themes.get_item_metadata(index)]
   run_configuration.atmosphere_preview.clear()
  )
  stack.add_child(themes)
 start_button = _action(stack, "Play", start_run)
 start_button.theme_type_variation = "PrimaryButton"
 start_button.icon = Art.PLAY
 start_button.add_theme_constant_override("icon_max_width", 28)
 start_button.add_theme_font_size_override("font_size", 24)
 start_button.custom_minimum_size.y = 54
 if not testing:
  setup_menu = preload("res://scripts/prototype/run_setup_menu.gd").new()
  stack.add_child(setup_menu)
  stack.move_child(setup_menu, start_button.get_index())
  setup_menu.changed.connect(_save_settings)
  setup_menu.configure(run_configuration, available_act_paths, start_button)
  setup_menu.advanced.add_child(sound)
 else: stack.add_child(sound)
 var graphics_parent: Node = stack if testing else setup_menu.advanced
 graphics_parent.add_child(preload("res://scripts/rendering/graphics_profile_picker.gd").new())
 var footer := HBoxContainer.new()
 stack.add_child(footer)
 _add_controls(footer, stack)
 var quit_button := _action(footer, "Quit", _quit)
 quit_button.theme_type_variation = &"QuietButton"
 quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _add_controls(button_row: Container, panel: Container) -> void:
 var help := Label.new()
 help.text = "Q / E or LB / RB   ·   Flippers\nLeft / Right or left stick   ·   Steer\nX   ·   Launch (hold and release at a plunger)\nSpace or A   ·   Use charged Special\nR or Back   ·   Retry (spends a Ball in Challenge)\nEnter / Esc or Menu   ·   Pause\nC / Shift+C   ·   Next / previous camera\nF11   ·   Fullscreen"
 var button := _action(button_row, "Controls", func(): help.visible = not help.visible)
 button.theme_type_variation = &"QuietButton"
 button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 help.add_theme_font_size_override("font_size", 16)
 help.hide()
 panel.add_child(help)

func start_run() -> void:
 if state == "menu" and is_instance_valid(start_button) and start_button.disabled: return
 await _start_configured_run(run_configuration, selected_character, practice_mode)

func _start_configured_run(configuration: RefCounted, character_id: String, practice: bool, replay_seed: Variant = null) -> void:
 if transitioning: return
 var configuration_error: String = configuration.validation_error()
 if not configuration_error.is_empty():
  var stack := _panel("RUN COULD NOT START", configuration_error)
  _action(stack, "Quit", _quit, true)
  return
 transitioning = true
 state = "loading"
 _panel("PREPARING RUN", "Loading the authored Acts…")
 await _close_run("restarted")
 archive_attempted = false
 archive_result = {}
 last_summary = {}
 last_run_configuration = null
 last_export = {}
 last_json = ""
 archived_json = ""
 game = Run.new()
 game.initial_play_camera = _read_play_camera()
 game.play_camera_changed.connect(_save_play_camera)
 game.run_configuration = Run.RunPlan.Configuration.new(configuration.selected_act_paths)
 game.run_configuration.atmosphere_overrides = configuration.atmosphere_overrides.duplicate(true)
 game.run_configuration.zone_count = configuration.zone_count
 game.run_configuration.selected_theme_ids = configuration.selected_theme_ids.duplicate()
 game.run_configuration.single_act_test = configuration.single_act_test
 game.run_configuration.single_act_use_bakes = configuration.single_act_use_bakes
 game.run_configuration.atmosphere_preview = configuration.atmosphere_preview.duplicate(true)
 game.replay_seed = replay_seed
 game.character_id = character_id
 game.practice_mode = practice
 game.completed.connect(_on_completed)
 game.draft_started.connect(_on_draft_started)
 add_child(game)
 var sounds := Sounds.new()
 sounds.enabled = sound_enabled
 sounds.game = game
 game.add_child(sounds)
 overlay_root.hide()
 state = "playing"
 transitioning = false

func _close_run(reason := "returned_to_menu") -> void:
 _close_spin_lab()
 _flush_run_feel()
 if is_instance_valid(game):
  if not archive_attempted: _archive_run(game.run_summary(false, reason))
  await game.prepare_to_close()
  game.free()
  game = null
 get_tree().paused = false

func return_to_menu() -> void:
 if transitioning: return
 var abandoned := is_instance_valid(game) and not archive_attempted
 if state == "error" and abandoned and not game.started: abandoned = false
 transitioning = true
 state = "loading"
 _panel("RETURNING TO MENU", "Finishing the current session…")
 await _close_run()
 if abandoned: _on_completed(last_summary)
 else: _show_menu()
 transitioning = false

func _show_pause() -> void:
 state = "paused"
 var stack := _panel("PAUSED", "%s · %d points" % [game.act_title(game.active), game.score])
 _action(stack, "Resume", func(): game.toggle_pause(), true).theme_type_variation = &"PrimaryButton"
 pause_camera_picker = OptionButton.new()
 for preset: int in Run.PLAY_CAMERAS:
  pause_camera_picker.add_item("Camera · " + TablePresentation.CAMERA_NAMES[preset], preset)
 pause_camera_picker.select(pause_camera_picker.get_item_index(game.presentation.camera_preset))
 pause_camera_picker.item_selected.connect(func(index: int):
  game.select_play_camera(pause_camera_picker.get_item_id(index)))
 stack.add_child(pause_camera_picker)
 _add_controls(stack, stack)
 if _can_inspect_character(): _action(stack, "%s spin preview   [F8]" % game.character_id.capitalize(), _open_spin_lab)
 _action(stack, "Restart run", start_run)
 _action(stack, "Return to menu", return_to_menu)
 _action(stack, "Quit", _quit)

func _can_inspect_character() -> bool:
 if not is_instance_valid(game) or not game.started: return false
 if game.finished or game.closing or game.drafting or game.loading_boundary or is_instance_valid(game.transfer): return false
 var pose = game.combo_celebration.character_pose
 return is_instance_valid(pose.runners_roll) or is_instance_valid(pose.sage)

func _open_spin_lab() -> void:
 if not _can_inspect_character() or is_instance_valid(spin_lab): return
 if not get_tree().paused: game.toggle_pause()
 if not get_tree().paused: return
 state = "spin_lab"
 overlay_root.hide()
 spin_lab = preload("res://experiments/visual_lab/sonic_spin_lab.gd").new()
 spin_lab.game = game
 spin_lab.resume_requested.connect(_resume_spin_lab)
 overlay.add_child(spin_lab)

func _close_spin_lab() -> void:
 if not is_instance_valid(spin_lab): return
 spin_lab.finish()
 spin_lab.hide()
 spin_lab.process_mode = Node.PROCESS_MODE_DISABLED
 spin_lab.queue_free()
 spin_lab = null

func _resume_spin_lab() -> void:
 _close_spin_lab()
 state = "playing"
 if get_tree().paused: game.toggle_pause()

func _on_draft_started(act_result: Dictionary, offers: Array[Dictionary]) -> void:
 state = "draft"
 var next: Dictionary = game.pending_act.plan
 var next_theme: String = game.library.themes[next.theme].display_name
 var stack := _panel("CHOOSE A BUDDY", "Next: %s · Act %d" % [next_theme, next.act + 1])
 var cards := HBoxContainer.new()
 cards.add_theme_constant_override("separation", 12)
 stack.add_child(cards)
 for i in offers.size():
  var offer: Dictionary = offers[i]
  var button := _action(cards, "", _choose_buddy.bind(str(offer.id)), i == 0)
  button.theme_type_variation = &"QuietButton"
  button.name = "Buddy_" + str(offer.id)
  button.tooltip_text = "%s · %s" % [offer.name, "Upgrade acquired Buddy" if offer.acquired else "Acquire Buddy"]
  button.custom_minimum_size = Vector2(264, 320)
  var row := VBoxContainer.new()
  row.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  row.offset_left = 14
  row.offset_right = -14
  row.offset_top = 12
  row.offset_bottom = -12
  row.add_theme_constant_override("separation", 6)
  button.add_child(row)
  var mat := PanelContainer.new()
  mat.theme_type_variation = &"PortraitPanel"
  mat.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.add_child(mat)
  var portrait := TextureRect.new()
  portrait.custom_minimum_size = Vector2(120, 110)
  portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
  if ResourceLoader.exists(offer.art_path): portrait.texture = load(offer.art_path)
  mat.add_child(portrait)
  var copy := VBoxContainer.new()
  copy.alignment = BoxContainer.ALIGNMENT_CENTER
  copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.add_child(copy)
  var name_label := _label(copy, offer.name, 21, Color("ffe07a"))
  name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  var level := _label(copy, "ONE-SHOT" if offer.consumable else "LEVEL %d" % offer.level, 14, Color("a8e4ff"))
  level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  var description := _label(copy, str(offer.description).replace("\n", " "), 16)
  description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  var slot := _label(row, "Upgrade Buddy" if offer.acquired else ("No slot needed" if offer.consumable else "Uses 1 Buddy slot"), 14, Color("8fe9b1"))
  slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
  slot.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
  slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 if offers.is_empty(): _action(stack, "All available Buddies maxed · Continue", _choose_buddy.bind(""), true)
 _action(stack, "Return to menu", return_to_menu)

func _choose_buddy(id: String) -> void:
 if transitioning or not is_instance_valid(game) or not game.choose_buddy(id): return
 state = "playing"
 overlay_root.hide()

func _on_completed(summary: Dictionary) -> void:
 _archive_run(summary)
 if summary.won and not run_configuration.single_act_test:
  if summary.practice:
   practice_best_score = maxi(practice_best_score, int(summary.score))
   if practice_best_seconds <= 0.0 or float(summary.seconds) < practice_best_seconds: practice_best_seconds = float(summary.seconds)
  else:
   best_score = maxi(best_score, int(summary.score))
   if best_seconds <= 0.0 or float(summary.seconds) < best_seconds: best_seconds = float(summary.seconds)
 _save_settings()
 state = "results"
 var stack := _panel("RUN COMPLETE" if summary.won else ("OUT OF BALLS" if last_export.termination_reason == "out_of_balls" else "RUN ABANDONED"), "")
 stack.add_theme_constant_override("separation", 7)
 var score_row := HBoxContainer.new()
 score_row.add_theme_constant_override("separation", 12)
 stack.add_child(score_row)
 var face := Art.face(summary.character)
 if face: score_row.add_child(Art.icon(face, Vector2(65, 65)))
 var score_label := _label(score_row, "%d PTS" % summary.score, 43, Color("ffdf47"))
 score_label.theme_type_variation = &"RaceTitle"
 _label(stack, "%s   ·   %s   ·   %d BALLS LOST" % ["PRACTICE" if summary.practice else "CHALLENGE", _time_text(summary.seconds), summary.drains], 17)
 var details := VBoxContainer.new()
 details.add_theme_constant_override("separation", 7)
 var details_button := _action(stack, "Run details & feedback", func(): details.visible = not details.visible)
 details_button.theme_type_variation = &"QuietButton"
 stack.add_child(details)
 details.hide()
 _label(details, "Run seed: %d" % summary.seed, 16)
 var scroll := ScrollContainer.new()
 scroll.custom_minimum_size = Vector2(600, minf(180.0, get_viewport_rect().size.y * 0.21))
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 details.add_child(scroll)
 var act_rows := VBoxContainer.new()
 act_rows.add_theme_constant_override("separation", 12)
 act_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(act_rows)
 for act: Dictionary in summary.acts:
  var data: Dictionary = act.telemetry
  var target_time := "not reached" if data.time_to_target_seconds == null else _time_text(data.time_to_target_seconds)
  var goal_time := "not reached" if data.time_target_to_goal_seconds == null else "+" + _time_text(data.time_target_to_goal_seconds)
  _label(act_rows, "ZONE %d · ACT %d · %s%s\n%d / %d · target %s · goal %s · total %s · Buddies +%d" % [act.zone, act.zone_act, act.title, " · NOT CLEARED" if not act.cleared else "", act.score, act.target, target_time, goal_time, _time_text(data.total_time_seconds), data.final_buddy_score], 16)
 _label(details, "Scoring: %d base / combo / special + %d from Buddies" % [summary.normal_score, Run.Buddies.total(summary.buddy_contributions)], 17)
 for id: String in summary.buddies:
  var level := " · One-shot" if not Run.Buddies.CATALOG[id].persistent else " Lv.%d" % summary.buddies[id]
  _label(act_rows, "%s%s: +%d points" % [Run.Buddies.CATALOG[id].name, level, int(summary.buddy_contributions.get(id, 0))], 17, Color("8fe9b1"))
 if summary.has("buddy_state"):
  var state_label := _label(details, summary.buddy_state.summary, 15)
  state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  state_label.custom_minimum_size.x = 610
  _label(details, "Buddy virtual Rings: %d · Emergency rescues: %d" % [summary.buddy_state.run.get("virtual_rings", 0), summary.buddy_state.run.get("rescues", 0)], 16)
 if not run_configuration.single_act_test: _label(stack, "%s best (all setups): %d" % ["Practice" if summary.practice else "Challenge", practice_best_score if summary.practice else best_score], 18, Color("8fe9b1"))
 _label(details, "Run feel (optional)", 16)
 run_feel = TextEdit.new()
 run_feel.name = "RunFeel"
 run_feel.placeholder_text = "How did this run feel? What felt fun, frustrating, too easy or confusing?"
 run_feel.custom_minimum_size = Vector2(560, 100)
 run_feel.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 run_feel.text = str(last_export.get("run_feel", ""))
 run_feel.text_changed.connect(func(): _set_run_feel(run_feel.text))
 details.add_child(run_feel)
 archive_status = _label(details, "Telemetry saved: " + str(archive_result.path).get_file() if archive_result.get("error", "").is_empty() else str(archive_result.error), 14)
 if not archive_result.get("error", "").is_empty(): details.show()
 archive_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 archive_status.custom_minimum_size.x = 560
 _action(details, "Open telemetry folder", _open_telemetry_folder)
 _action(details, "Copy run data", _copy_run_data)
 copy_status = _label(details, "", 14, Color("8fe9b1"))
 copy_status.hide()
 var run_actions := HBoxContainer.new()
 stack.add_child(run_actions)
 if summary.started:
  var replay := _action(run_actions, "Replay same course", _start_configured_run.bind(last_run_configuration, summary.character, summary.practice, summary.seed), true)
  replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var new_run := _action(run_actions, "New run", start_run, not summary.started)
 new_run.theme_type_variation = &"PrimaryButton"
 new_run.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 _action(stack, "Return to menu", return_to_menu)
 _action(stack, "Quit", _quit)

func _archive_run(summary: Dictionary) -> void:
 if archive_attempted: return
 archive_attempted = true
 last_run_configuration = game.run_configuration
 last_summary = summary.duplicate(true)
 last_summary["ended_at_local"] = Time.get_datetime_string_from_system(false)
 last_export = Telemetry.export_run(last_summary)
 last_json = JSON.stringify(last_export, "  ", false, true)
 archive_result = Archive.save(last_json, last_export, archive_directory)
 if archive_result.error.is_empty(): archived_json = last_json
 if not archive_result.error.is_empty(): push_warning(archive_result.error)

func _set_run_feel(text: String) -> void:
 last_export["run_feel"] = text
 last_summary["run_feel"] = text
 last_json = JSON.stringify(last_export, "  ", false, true)
 note_timer.start()

func _flush_run_feel() -> void:
 if is_instance_valid(note_timer): note_timer.stop()
 if last_json == archived_json or archive_result.get("path", "").is_empty(): return
 var result := Archive.update_notes(archive_result.path, archived_json, last_json)
 if result.error.is_empty():
  archived_json = last_json
  if is_instance_valid(archive_status): archive_status.text = "Telemetry saved (including run feel)"
 else:
  if is_instance_valid(archive_status): archive_status.text = result.error
  push_warning(result.error)

func run_data_json() -> String:
 return last_json if not last_json.is_empty() else JSON.stringify(Telemetry.export_run(last_summary), "  ", false, true)

func _open_telemetry_folder() -> void:
 var error := DirAccess.make_dir_recursive_absolute(archive_directory)
 if error == OK: error = OS.shell_open(ProjectSettings.globalize_path(archive_directory))
 if error != OK:
  archive_status.text = "Could not open telemetry folder: " + ProjectSettings.globalize_path(archive_directory)
  push_warning(archive_status.text)

func _copy_run_data() -> void:
 if state != "results" or last_summary.is_empty(): return
 _flush_run_feel()
 DisplayServer.clipboard_set(run_data_json())
 copy_status.text = "Run data copied"
 copy_status.show()

static func _time_text(seconds: float) -> String:
 return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _process(_delta: float) -> void:
 if transitioning or not is_instance_valid(game): return
 var error: String = game.last_source_error
 if error.is_empty() and is_instance_valid(game.library): error = game.library.error
 if not error.is_empty() and state != "error":
  state = "error"
  var stack := _panel("RUN INTERRUPTED" if game.started else "RUN COULD NOT START", "")
  var explanation := _label(stack, error)
  explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  _action(stack, "Return to menu", return_to_menu, true)
  _action(stack, "Quit", _quit)
  return
 if not game.started or game.finished or game.loading_boundary: return
 if start_spin_lab and state == "playing":
  start_spin_lab = false
  _open_spin_lab()
  return
 if state == "spin_lab" and not get_tree().paused:
  _resume_spin_lab()
  return
 if get_tree().paused and state == "playing": _show_pause()
 elif not get_tree().paused and state == "paused":
  state = "playing"
  overlay_root.hide()

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if state == "spin_lab" and event.keycode in [KEY_F8, KEY_ESCAPE]:
   get_viewport().set_input_as_handled()
   _resume_spin_lab()
   return
  if state in ["playing", "paused"] and event.keycode == KEY_F8 and _can_inspect_character():
   get_viewport().set_input_as_handled()
   _open_spin_lab()
   return
 if not event is InputEventKey or state not in ["playing", "paused"] or not is_instance_valid(game) or not game.started: return
 if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
  var focus := get_viewport().gui_get_focus_owner()
  if state == "paused" and focus != null and overlay_root.is_ancestor_of(focus): return
  # Consume Enter before UI accept or the shared launch binding can also fire.
  get_viewport().set_input_as_handled()
  if event.pressed and not event.echo: game.toggle_pause()
 elif event.keycode == KEY_X and event.pressed and not event.echo and state == "playing":
  get_viewport().set_input_as_handled()
  game.launch_ball()

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
  get_viewport().set_input_as_handled()

func _quit() -> void:
 if transitioning: return
 transitioning = true
 await _close_run("quit")
 get_tree().quit()
