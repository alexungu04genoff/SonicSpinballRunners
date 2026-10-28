extends Control
## Player-facing session flow; the run uses the shared authored streaming engine.
const Run = preload("res://scripts/prototype/zone_run.gd")
const Sounds = preload("res://scripts/prototype/score_sounds.gd")
const SETTINGS_PATH := "user://prototype_settings.cfg"
var game: Node
var overlay: CanvasLayer
var overlay_root: Control
var state := "menu"
var transitioning := false
var selected_character := "sonic"
var sound_enabled := true
var best_score := 0
var best_seconds := 0.0
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
  best_score = maxi(0, int(settings.get_value("records", "score", 0)))
  best_seconds = maxf(0.0, float(settings.get_value("records", "seconds", 0.0)))
 overlay = CanvasLayer.new()
 overlay.layer = 40
 add_child(overlay)
 _show_menu()

func _save_settings() -> void:
 var settings := ConfigFile.new()
 settings.set_value("player", "character", selected_character)
 settings.set_value("player", "sound", sound_enabled)
 settings.set_value("records", "score", best_score)
 settings.set_value("records", "seconds", best_seconds)
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
 var stack := _panel("SONIC SPINBALL RUNNERS", "ONE ZONE · THREE ACTS")
 _label(stack, "Earn each Act's target. Reach its exit. Keep your run score.\nCheckpoint retries preserve your points.")
 _label(stack, "Act 1: 1,000     Act 2: 1,500     Act 3: 2,000", 19, Color("8fe9b1"))
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
 var sound := CheckButton.new()
 sound.text = "Scoring sounds"
 sound.button_pressed = sound_enabled
 sound.toggled.connect(func(value: bool): sound_enabled = value; _save_settings())
 stack.add_child(sound)
 if best_score > 0: _label(stack, "Personal best: %d · Fastest clear: %s" % [best_score, _time_text(best_seconds)])
 _action(stack, "Start run", start_run, true)
 _label(stack, "Q / E or LB / RB: flippers     Arrows or stick: steer\nEnter / X: launch     Space / A: special     Esc / Menu: pause\nR / Back: checkpoint retry     F11: fullscreen", 16)
 _action(stack, "Quit", _quit)

func start_run() -> void:
 if transitioning: return
 transitioning = true
 state = "loading"
 _panel("PREPARING RUN", "Loading the authored Acts…")
 await _close_run()
 game = Run.new()
 game.character_id = selected_character
 game.completed.connect(_on_completed)
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
 var stack := _panel("PAUSED", "Act %d / 3 · %s\nTotal score: %d" % [game.active_sequence + 1, game.act_score_text(), game.score])
 _action(stack, "Resume", func(): game.toggle_pause(), true)
 _action(stack, "Restart run", start_run)
 _action(stack, "Return to menu", return_to_menu)
 _action(stack, "Quit", _quit)

func _on_completed(summary: Dictionary) -> void:
 last_summary = summary.duplicate(true)
 best_score = maxi(best_score, int(summary.score))
 if best_seconds <= 0.0 or float(summary.seconds) < best_seconds: best_seconds = float(summary.seconds)
 _save_settings()
 state = "results"
 var stack := _panel("ZONE COMPLETE", "%d POINTS · %s · %d DRAINS" % [summary.score, _time_text(summary.seconds), summary.drains])
 for act: Dictionary in summary.acts:
  _label(stack, "ACT %d · %s\n%d / %d points · %s · %d drains" % [act.act, act.title, act.score, act.target, _time_text(act.seconds), act.drains])
 _label(stack, "Personal best: %d" % best_score, 20, Color("8fe9b1"))
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
