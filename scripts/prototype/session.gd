extends Control
## Player-facing session flow; the run uses the shared authored streaming engine.
const Run = preload("res://scripts/prototype/zone_run.gd")
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

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 get_tree().auto_accept_quit = false
 get_tree().root.close_requested.connect(_quit)
 var settings := ConfigFile.new()
 if settings.load(settings_path) == OK:
  var saved := str(settings.get_value("player", "character", "sonic"))
  if CharacterSpecials.CHARACTERS.has(saved): selected_character = saved
  sound_enabled = bool(settings.get_value("player", "sound", true))
  practice_mode = bool(settings.get_value("player", "practice", false))
  # The shuffled six-Act course has separate records from the earlier prototype.
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
 settings.set_value("player", "character", selected_character)
 settings.set_value("player", "sound", sound_enabled)
 settings.set_value("player", "practice", practice_mode)
 settings.set_value(PRACTICE_RECORDS, "score", practice_best_score)
 settings.set_value(PRACTICE_RECORDS, "seconds", practice_best_seconds)
 settings.set_value(CHALLENGE_RECORDS, "score", best_score)
 settings.set_value(CHALLENGE_RECORDS, "seconds", best_seconds)
 if settings.save(settings_path) != OK: push_warning("Could not save prototype preferences.")

func _panel(title: String, subtitle: String) -> VBoxContainer:
 if is_instance_valid(overlay_root): overlay_root.free()
 overlay_root = ColorRect.new()
 overlay_root.color = Color(0.025, 0.045, 0.075, 0.96)
 overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.add_child(overlay_root)
 var center := CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay_root.add_child(center)
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
 var stack := _panel("SONIC SPINBALL RUNNERS", "TWO ZONES · SIX SHUFFLED ACTS")
 _label(stack, "Green Hill, then Chemical Plant. Three balls per Act.\nEarn the target, reach the exit, then choose a Buddy.\nEach run shuffles the authored Acts without repeats.")
 _label(stack, "Green Hill: 1,000 / 1,500 / 2,000\nChemical Plant: 2,500 / 3,000 / 3,500", 19, Color("8fe9b1"))
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
 if best_score > 0: _label(stack, "Challenge best: %d · Fastest clear: %s" % [best_score, _time_text(best_seconds)])
 if practice_best_score > 0: _label(stack, "Practice best: %d" % practice_best_score, 16)
 _action(stack, "Start run", start_run, true)
 _label(stack, "Q / E or LB / RB: flippers     Arrows or stick: steer\nEnter / X: launch     Space / A: special     Esc / Menu: pause\nR / Back: retry (uses a ball in Challenge)     F11: fullscreen", 16)
 _action(stack, "Quit", _quit)

func start_run() -> void:
 if transitioning: return
 transitioning = true
 state = "loading"
 _panel("PREPARING RUN", "Loading the authored Acts…")
 await _close_run()
 game = Run.new()
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

func _close_run() -> void:
 if is_instance_valid(game):
  await game.prepare_to_close()
  game.free()
  game = null
 get_tree().paused = false

func return_to_menu() -> void:
 if transitioning: return
 transitioning = true
 state = "loading"
 _panel("RETURNING TO MENU", "Finishing the current session…")
 await _close_run()
 _show_menu()
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
 var stack := _panel("CHOOSE A BUDDY", "Zone %d · Act %d cleared · %s\n%d / %d points · %d balls lost\nNext: %s · Act %d · %s" % [act_result.zone, act_result.zone_act, act_result.title, act_result.score, act_result.target, act_result.drains, next_theme, next.act + 1, "unlimited retries" if game.practice_mode else "three balls"])
 _label(stack, "Buddies last for this run. Pick the same Buddy to upgrade it.", 16)
 _label(stack, game.buddies.summary(), 17, Color("8fe9b1"))
 for i in offers.size():
  var offer: Dictionary = offers[i]
  var button := _action(stack, "%s · Level %d\n%s" % [offer.name, offer.level, offer.description], _choose_buddy.bind(str(offer.id)), i == 0)
  button.custom_minimum_size.y = 110
 _action(stack, "Return to menu", return_to_menu)

func _choose_buddy(id: String) -> void:
 if transitioning or not is_instance_valid(game) or not game.choose_buddy(id): return
 state = "playing"
 overlay_root.hide()

func _on_completed(summary: Dictionary) -> void:
 last_summary = summary.duplicate(true)
 if summary.won:
  if summary.practice:
   practice_best_score = maxi(practice_best_score, int(summary.score))
   if practice_best_seconds <= 0.0 or float(summary.seconds) < practice_best_seconds: practice_best_seconds = float(summary.seconds)
  else:
   best_score = maxi(best_score, int(summary.score))
   if best_seconds <= 0.0 or float(summary.seconds) < best_seconds: best_seconds = float(summary.seconds)
 _save_settings()
 state = "results"
 var stack := _panel("TWO ZONES COMPLETE" if summary.won else "RUN ENDED · OUT OF BALLS", "%s · %d POINTS · %s · %d BALLS LOST\nRun seed: %d" % ["PRACTICE" if summary.practice else "CHALLENGE", summary.score, _time_text(summary.seconds), summary.drains, summary.seed])
 var scroll := ScrollContainer.new()
 scroll.custom_minimum_size = Vector2(600, 220)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 stack.add_child(scroll)
 var act_rows := VBoxContainer.new()
 act_rows.add_theme_constant_override("separation", 12)
 act_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 scroll.add_child(act_rows)
 for act: Dictionary in summary.acts:
  _label(act_rows, "ZONE %d · ACT %d · %s%s\n%d / %d points · %s · %d balls lost · Buddies +%d" % [act.zone, act.zone_act, act.title, " · NOT CLEARED" if not act.cleared else "", act.score, act.target, _time_text(act.seconds), act.drains, Run.Buddies.total(act.buddy_contributions)], 16)
 _label(stack, "Scoring: %d base / combo / special + %d from Buddies" % [summary.normal_score, Run.Buddies.total(summary.buddy_contributions)], 17)
 for id: String in summary.buddies:
  _label(stack, "%s Lv.%d: +%d points" % [Run.Buddies.CATALOG[id].name, summary.buddies[id], int(summary.buddy_contributions.get(id, 0))], 17, Color("8fe9b1"))
 _label(stack, "%s best: %d" % ["Practice" if summary.practice else "Challenge", practice_best_score if summary.practice else best_score], 18, Color("8fe9b1"))
 _action(stack, "Play again", start_run, true)
 _action(stack, "Return to menu", return_to_menu)
 _action(stack, "Quit", _quit)

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

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
  get_viewport().set_input_as_handled()

func _quit() -> void:
 if transitioning: return
 transitioning = true
 await _close_run()
 get_tree().quit()
