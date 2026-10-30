extends Control
## Player-facing session flow; the run uses the shared authored streaming engine.
const Run = preload("res://scripts/prototype/zone_run.gd")
const Telemetry = preload("res://scripts/prototype/run_telemetry.gd")
const Archive = preload("res://scripts/prototype/telemetry_archive.gd")
const Sounds = preload("res://scripts/prototype/score_sounds.gd")
const SETTINGS_PATH := "user://prototype_settings.cfg"
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
var copy_status: Label
var available_act_paths: Array = []
var run_configuration: RefCounted
var setup_menu: VBoxContainer
var start_button: Button
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
 run_configuration = Run.RunPlan.Configuration.new(available_act_paths)
 var settings := ConfigFile.new()
 if settings.load(settings_path) == OK:
  run_configuration.read_preferences(settings, available_act_paths)
  var saved := str(settings.get_value("player", "character", "sonic"))
  if CharacterSpecials.CHARACTERS.has(saved): selected_character = saved
  sound_enabled = bool(settings.get_value("player", "sound", true))
  practice_mode = bool(settings.get_value("player", "practice", false))
  # Retain existing completion records across run setups and course versions.
  practice_best_score = maxi(0, int(settings.get_value(PRACTICE_RECORDS, "score", 0)))
  practice_best_seconds = maxf(0.0, float(settings.get_value(PRACTICE_RECORDS, "seconds", 0.0)))
  best_score = maxi(0, int(settings.get_value(CHALLENGE_RECORDS, "score", 0)))
  best_seconds = maxf(0.0, float(settings.get_value(CHALLENGE_RECORDS, "seconds", 0.0)))
 overlay = CanvasLayer.new()
 overlay.layer = 40
 add_child(overlay)
 _show_menu()

func _save_settings() -> void:
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

func _panel(title: String, subtitle: String) -> VBoxContainer:
 if is_instance_valid(overlay_root):
  # A button in this panel may still be emitting pressed. Retire it after dispatch.
  overlay_root.hide()
  overlay_root.process_mode = Node.PROCESS_MODE_DISABLED
  overlay_root.queue_free()
 overlay_root = ColorRect.new()
 overlay_root.color = Color(0.025, 0.045, 0.075, 0.96)
 overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(overlay_root)
 var scroll := ScrollContainer.new()
 scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 overlay_root.add_child(scroll)
 var center := CenterContainer.new()
 center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 center.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.add_child(center)
 var card := PanelContainer.new()
 card.custom_minimum_size.x = 600
 var style := StyleBoxFlat.new()
 style.bg_color = Color("102d3b")
 style.set_content_margin_all(28)
 style.set_corner_radius_all(12)
 card.add_theme_stylebox_override("panel", style)
 center.add_child(card)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 14)
 card.add_child(stack)
 _label(stack, title, 30, Color("ffe07a"))
 _label(stack, subtitle, 18)
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
 var stack := _panel("SONIC SPINBALL RUNNERS", "PLAY PROTOTYPE")
 _label(stack, "Earn each Act's target, touch its Goal Ring, then choose a Buddy.\nThree balls per Act in Challenge; unlimited retries in Practice.", 16)
 var characters := OptionButton.new()
 for id: String in CharacterSpecials.CHARACTERS:
  characters.add_item(id.capitalize())
  characters.set_item_metadata(characters.item_count - 1, id)
  if id == selected_character: characters.select(characters.item_count - 1)
 characters.item_selected.connect(func(index: int):
  selected_character = characters.get_item_metadata(index)
  _save_settings()
 )
 stack.add_child(characters)
 characters.call_deferred("grab_focus")
 var practice := CheckButton.new()
 practice.text = "Practice · Unlimited retries · Separate records"
 practice.button_pressed = practice_mode
 practice.toggled.connect(func(value: bool): practice_mode = value; _save_settings())
 stack.add_child(practice)
 var sound := CheckButton.new()
 sound.text = "Scoring sounds"
 sound.button_pressed = sound_enabled
 sound.toggled.connect(func(value: bool): sound_enabled = value; _save_settings())
 stack.add_child(sound)
 if best_score > 0: _label(stack, "Challenge best (all setups): %d · Fastest clear: %s" % [best_score, _time_text(best_seconds)])
 if practice_best_score > 0: _label(stack, "Practice best (all setups): %d" % practice_best_score, 16)
 start_button = _action(stack, "Start run", start_run)
 setup_menu = preload("res://scripts/prototype/run_setup_menu.gd").new()
 stack.add_child(setup_menu)
 stack.move_child(setup_menu, start_button.get_index())
 setup_menu.changed.connect(_save_settings)
 setup_menu.configure(run_configuration, available_act_paths, start_button)
 _label(stack, "Q / E or LB / RB: flippers     Arrows or stick: steer\nX: launch     Space / A: special     Enter / Esc / Menu: pause\nR / Back: retry (uses a ball in Challenge)     F11: fullscreen", 16)
 _action(stack, "Quit", _quit)

func start_run() -> void:
 if transitioning: return
 if state == "menu" and is_instance_valid(start_button) and start_button.disabled: return
 if not run_configuration.validation_error().is_empty(): return
 transitioning = true
 state = "loading"
 _panel("PREPARING RUN", "Loading the authored Acts…")
 await _close_run("restarted")
 archive_attempted = false
 archive_result = {}
 last_summary = {}
 last_export = {}
 last_json = ""
 archived_json = ""
 game = Run.new()
 game.run_configuration = Run.RunPlan.Configuration.new(run_configuration.selected_act_paths)
 game.run_configuration.zone_count = run_configuration.zone_count
 game.run_configuration.selected_theme_ids = run_configuration.selected_theme_ids.duplicate()
 game.character_id = selected_character
 game.practice_mode = practice_mode
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
 transitioning = true
 state = "loading"
 _panel("RETURNING TO MENU", "Finishing the current session…")
 await _close_run()
 if abandoned: _on_completed(last_summary)
 else: _show_menu()
 transitioning = false

func _show_pause() -> void:
 state = "paused"
 var stack := _panel("PAUSED", "%s\n%s · Total score: %d · Seed: %d" % [game.progress_text(), game.act_score_text(), game.score, game.run_seed])
 _action(stack, "Resume", func(): game.toggle_pause(), true)
 _action(stack, "Restart run", start_run)
 _action(stack, "Return to menu", return_to_menu)
 _action(stack, "Quit", _quit)

func _on_draft_started(act_result: Dictionary, offers: Array[Dictionary]) -> void:
 state = "draft"
 var next: Dictionary = game.pending_act.plan
 var next_theme: String = game.library.themes[next.theme].display_name
 var stack := _panel("CHOOSE A BUDDY", "Zone %d · Act %d cleared · %s\n%d / %d points · %d balls lost\nNext: %s · Act %d · %s" % [act_result.zone, act_result.zone_act, act_result.title, act_result.score, act_result.target, act_result.drains, next_theme, next.act + 1, "unlimited retries" if game.practice_mode else "base 3 balls + Buddy effects"])
 _label(stack, "Adventure Buddies · %d / 5 persistent slots · Effects adapted for pinball" % game.buddies.persistent_slots(), 16)
 var owned := _label(stack, game.buddies.summary(), 16, Color("8fe9b1"))
 owned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 owned.custom_minimum_size.x = 610
 for i in offers.size():
  var offer: Dictionary = offers[i]
  var button := _action(stack, "", _choose_buddy.bind(str(offer.id)), i == 0)
  button.name = "Buddy_" + str(offer.id)
  button.tooltip_text = "%s · %s" % [offer.name, "Upgrade acquired Buddy" if offer.acquired else "Acquire Buddy"]
  button.custom_minimum_size = Vector2(640, 116)
  var row := HBoxContainer.new()
  row.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  row.offset_left = 14
  row.offset_right = -14
  row.add_theme_constant_override("separation", 18)
  button.add_child(row)
  var portrait := TextureRect.new()
  portrait.custom_minimum_size = Vector2(92, 104)
  portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
  portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
  if ResourceLoader.exists(offer.art_path): portrait.texture = load(offer.art_path)
  row.add_child(portrait)
  var copy := VBoxContainer.new()
  copy.alignment = BoxContainer.ALIGNMENT_CENTER
  copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
  row.add_child(copy)
  _label(copy, "%s · %s" % [offer.name, "One-shot" if offer.consumable else "Level %d" % offer.level], 21, Color("ffe07a")).mouse_filter = Control.MOUSE_FILTER_IGNORE
  _label(copy, offer.description, 16).mouse_filter = Control.MOUSE_FILTER_IGNORE
  _label(copy, "ACQUIRED · Upgrade" if offer.acquired else ("ACQUIRE · No slot needed" if offer.consumable else "ACQUIRE · 1 persistent slot"), 13, Color("8fe9b1")).mouse_filter = Control.MOUSE_FILTER_IGNORE
 if offers.is_empty(): _action(stack, "All available Buddies maxed · Continue", _choose_buddy.bind(""), true)
 _action(stack, "Return to menu", return_to_menu)

func _choose_buddy(id: String) -> void:
 if transitioning or not is_instance_valid(game) or not game.choose_buddy(id): return
 state = "playing"
 overlay_root.hide()

func _on_completed(summary: Dictionary) -> void:
 _archive_run(summary)
 if summary.won:
  if summary.practice:
   practice_best_score = maxi(practice_best_score, int(summary.score))
   if practice_best_seconds <= 0.0 or float(summary.seconds) < practice_best_seconds: practice_best_seconds = float(summary.seconds)
  else:
   best_score = maxi(best_score, int(summary.score))
   if best_seconds <= 0.0 or float(summary.seconds) < best_seconds: best_seconds = float(summary.seconds)
 _save_settings()
 state = "results"
 var stack := _panel("RUN COMPLETE" if summary.won else ("RUN ENDED · OUT OF BALLS" if last_export.termination_reason == "out_of_balls" else "RUN ABANDONED"), "%s · %d POINTS · %s · %d BALLS LOST\nRun seed: %d" % ["PRACTICE" if summary.practice else "CHALLENGE", summary.score, _time_text(summary.seconds), summary.drains, summary.seed])
 stack.add_theme_constant_override("separation", 7)
 var scroll := ScrollContainer.new()
 scroll.custom_minimum_size = Vector2(600, minf(180.0, get_viewport_rect().size.y * 0.21))
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 stack.add_child(scroll)
 var act_rows := VBoxContainer.new()
 act_rows.add_theme_constant_override("separation", 12)
 act_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(act_rows)
 for act: Dictionary in summary.acts:
  var data: Dictionary = act.telemetry
  var target_time := "not reached" if data.time_to_target_seconds == null else _time_text(data.time_to_target_seconds)
  var goal_time := "not reached" if data.time_target_to_goal_seconds == null else "+" + _time_text(data.time_target_to_goal_seconds)
  _label(act_rows, "ZONE %d · ACT %d · %s%s\n%d / %d · target %s · goal %s · total %s · Buddies +%d" % [act.zone, act.zone_act, act.title, " · NOT CLEARED" if not act.cleared else "", act.score, act.target, target_time, goal_time, _time_text(data.total_time_seconds), data.final_buddy_score], 16)
 _label(stack, "Scoring: %d base / combo / special + %d from Buddies" % [summary.normal_score, Run.Buddies.total(summary.buddy_contributions)], 17)
 for id: String in summary.buddies:
  var level := " · One-shot" if not Run.Buddies.CATALOG[id].persistent else " Lv.%d" % summary.buddies[id]
  _label(act_rows, "%s%s: +%d points" % [Run.Buddies.CATALOG[id].name, level, int(summary.buddy_contributions.get(id, 0))], 17, Color("8fe9b1"))
 if summary.has("buddy_state"):
  var state_label := _label(stack, summary.buddy_state.summary, 15)
  state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  state_label.custom_minimum_size.x = 610
  _label(stack, "Buddy virtual Rings: %d · Emergency rescues: %d" % [summary.buddy_state.run.get("virtual_rings", 0), summary.buddy_state.run.get("rescues", 0)], 16)
 _label(stack, "%s best (all setups): %d" % ["Practice" if summary.practice else "Challenge", practice_best_score if summary.practice else best_score], 18, Color("8fe9b1"))
 _label(stack, "Run feel (optional)", 16)
 run_feel = TextEdit.new()
 run_feel.name = "RunFeel"
 run_feel.placeholder_text = "How did this run feel? What felt fun, frustrating, too easy or confusing?"
 run_feel.custom_minimum_size = Vector2(560, 100)
 run_feel.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
 run_feel.text = str(last_export.get("run_feel", ""))
 run_feel.text_changed.connect(func(): _set_run_feel(run_feel.text))
 stack.add_child(run_feel)
 archive_status = _label(stack, "Telemetry saved: " + str(archive_result.path).get_file() if archive_result.get("error", "").is_empty() else str(archive_result.error), 14)
 archive_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 archive_status.custom_minimum_size.x = 560
 _action(stack, "Open telemetry folder", _open_telemetry_folder)
 _action(stack, "Copy run data", _copy_run_data)
 copy_status = _label(stack, "", 14, Color("8fe9b1"))
 copy_status.hide()
 _action(stack, "Play again", start_run, true)
 _action(stack, "Return to menu", return_to_menu)
 _action(stack, "Quit", _quit)

func _archive_run(summary: Dictionary) -> void:
 if archive_attempted: return
 archive_attempted = true
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
 var failed: bool = not game.last_source_error.is_empty() or (is_instance_valid(game.library) and not game.library.error.is_empty())
 if failed and state != "error":
  state = "error"
  var stack := _panel("RUN COULD NOT START", "Required game data is missing or out of date.\nReturn to the menu or use a complete prototype build.")
  _action(stack, "Return to menu", return_to_menu, true)
  _action(stack, "Quit", _quit)
  return
 if not game.started or game.finished or game.loading_boundary: return
 if get_tree().paused and state == "playing": _show_pause()
 elif not get_tree().paused and state == "paused":
  state = "playing"
  overlay_root.hide()

func _input(event: InputEvent) -> void:
 if not event is InputEventKey or state not in ["playing", "paused"] or not is_instance_valid(game) or not game.started: return
 if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
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
