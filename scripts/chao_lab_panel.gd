class_name ChaoLabPanel
extends PopupPanel
## One session slot, previewed through the same resolver as the live physics.
var game: Node
var start_run: Callable
var selected_id := "none"
var cards: Dictionary = {}
var heading: Label
var selection: Label
var apply_button: Button
var _was_paused := false
var _restore_pause := false
var _applying := false

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 var background := StyleBoxFlat.new()
 background.bg_color = Color("102b36")
 background.set_corner_radius_all(12)
 add_theme_stylebox_override("panel", background)
 var margin := MarginContainer.new()
 for side: String in ["left", "right", "top", "bottom"]:
  margin.add_theme_constant_override("margin_" + side, 20)
 add_child(margin)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 16)
 margin.add_child(stack)
 heading = _label(stack, "CHAO LAB v0", 24)
 _label(stack, "Choose one companion. Equip starts a fresh run on this seed; score and rings reset.", 15)
 var row := HBoxContainer.new()
 row.add_theme_constant_override("separation", 12)
 stack.add_child(row)
 for id: String in ["ice", "spring", "magnet"]:
  var card := VBoxContainer.new()
  card.custom_minimum_size.x = 250
  card.add_theme_constant_override("separation", 10)
  row.add_child(card)
  var data: Dictionary = PhysicsTuning.CHAO[id]
  var title := _label(card, "●  %s — %s" % [data.name, data.role], 19)
  title.modulate = data.color
  _label(card, data.description, 14)
  var stats := _label(card, "", 14)
  var button := _button(card, "Choose " + data.name, func(): choose(id))
  cards[id] = {"stats": stats, "button": button}
 _label(stack, "Effective stats: baseline → with Chao (current profile, tuning and limits).\nSteer and brake include the steering-strength setting.", 14)
 selection = _label(stack, "", 15)
 var actions := HBoxContainer.new()
 actions.add_theme_constant_override("separation", 12)
 stack.add_child(actions)
 _button(actions, "No Chao / baseline", func(): choose("none"))
 apply_button = _button(actions, "Equip + replay same seed", apply_choice)
 _button(actions, "Close", hide)
 popup_hide.connect(func(): _restore_pause = true)
 game.tuning.changed.connect(refresh)

func _label(parent: Node, text: String, font_size: int) -> Label:
 var label := Label.new()
 label.text = text
 label.add_theme_font_size_override("font_size", font_size)
 parent.add_child(label)
 return label

func _button(parent: Node, text: String, action: Callable) -> Button:
 var button := Button.new()
 button.text = text
 button.pressed.connect(action)
 parent.add_child(button)
 return button

func open_lab() -> void:
 if not game.can_regenerate():
  return
 _was_paused = get_tree().paused
 _restore_pause = false
 selected_id = game.tuning.chao_id
 get_tree().paused = true
 refresh()
 popup_centered(Vector2i(850, 430))
 cards.ice.button.grab_focus()

func choose(id: String) -> void:
 if game.generation_pending:
  return
 selected_id = id
 refresh()

func refresh() -> void:
 var tuning: PhysicsTuning = game.tuning
 var baseline := tuning.preview_chao("none")
 heading.text = "CHAO LAB v0  ·  %s  ·  Seed %d" % [tuning.base.display_name, game.generation_seed]
 for id: String in cards:
  var stats := tuning.preview_chao(id)
  var text := ""
  for key: String in ["steering_acceleration", "counter_steering_deceleration", "max_steering_speed", "flipper_launch_strength", "ring_magnet_radius"]:
   var label: String = {"steering_acceleration": "Steer", "counter_steering_deceleration": "Brake", "max_steering_speed": "Steer cap", "flipper_launch_strength": "Flip", "ring_magnet_radius": "Ring radius"}[key]
   var original: float = baseline[key]
   var modified: float = stats[key]
   if key in ["steering_acceleration", "counter_steering_deceleration"]:
    original *= baseline.steering_strength
    modified *= stats.steering_strength
   text += "%s: %s → %s %s\n" % [label, str(snappedf(original, 0.1)), str(snappedf(modified, 0.1)), PhysicsProfile.FIELDS[key][4]]
  cards[id].stats.text = text.trim_suffix("\n")
  cards[id].button.text = ("Selected: " if selected_id == id else "Choose ") + PhysicsTuning.CHAO[id].name
 selection.text = "Equipped: %s  |  Choice: %s\nUses the mode and target selected above." % [PhysicsTuning.CHAO[tuning.chao_id].name, PhysicsTuning.CHAO[selected_id].name]

func apply_choice() -> void:
 if game.generation_pending:
  return
 _applying = start_run.call(selected_id)

func _process(_delta: float) -> void:
 apply_button.disabled = game.generation_pending
 if _applying and not game.generation_pending:
  _applying = false
  if game.tuning.chao_id == selected_id:
   # A victory replay resumes at serve, matching the existing replay controls.
   if not get_tree().paused:
    _was_paused = false
   hide()
  else:
   selection.text = game.status_message
 if _restore_pause and not game.generation_pending:
  _restore_pause = false
  get_tree().paused = _was_paused or game.score_attack.state == ScoreAttack.State.COMPLETE
