class_name ZonePanel
extends Control
## Shared gameplay HUD and mandatory rewards, independent of the table presentation.
var game: Node
var hud: PanelContainer
var heading: Label
var layout_label: Label
var score_label: Label
var exit_label: Label
var build_label: Label
var modal: Control
var draft: VBoxContainer
var draft_heading: Label
var draft_summary: Label
var draft_footer: Label
var cards: Dictionary = {}
var completion: VBoxContainer
var result_label: Label
var replay_button: Button
var free_play_button: Button
var _last_state := -1

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 hud = PanelContainer.new()
 hud.position = Vector2(235, 150)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 hud.add_theme_stylebox_override("panel", _style(Color("102b36"), 12))
 add_child(hud)
 var status := VBoxContainer.new()
 status.mouse_filter = Control.MOUSE_FILTER_IGNORE
 status.add_theme_constant_override("separation", 3)
 hud.add_child(status)
 heading = _label(status, "GREEN HILL ZONE", 19)
 heading.modulate = Color("9de583")
 layout_label = _label(status, "", 13)
 layout_label.modulate = Color("9bb7c9")
 score_label = _label(status, "", 17)
 exit_label = _label(status, "", 14)
 build_label = _label(status, "", 14)
 var overlay := CanvasLayer.new()
 overlay.layer = 40
 add_child(overlay)
 modal = Control.new()
 modal.mouse_filter = Control.MOUSE_FILTER_STOP
 overlay.add_child(modal)
 var shade := ColorRect.new()
 shade.color = Color(0.015, 0.025, 0.04, 0.88)
 shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
 modal.add_child(shade)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var center := CenterContainer.new()
 center.mouse_filter = Control.MOUSE_FILTER_IGNORE
 modal.add_child(center)
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var panel := PanelContainer.new()
 panel.custom_minimum_size.x = 850
 panel.add_theme_stylebox_override("panel", _style(Color("102b36"), 24))
 center.add_child(panel)
 var contents := VBoxContainer.new()
 panel.add_child(contents)
 _create_draft(contents)
 _create_completion(contents)
 game.zone.changed.connect(refresh)
 game.tuning.changed.connect(refresh)
 refresh()

func _create_draft(parent: Node) -> void:
 draft = VBoxContainer.new()
 draft.add_theme_constant_override("separation", 15)
 parent.add_child(draft)
 draft_heading = _label(draft, "ACT CLEAR — CHOOSE A CHAO", 27)
 draft_heading.modulate = Color("ffe27a")
 draft_summary = _label(draft, "", 16)
 var row := HBoxContainer.new()
 row.add_theme_constant_override("separation", 14)
 draft.add_child(row)
 for id: String in PhysicsTuning.DRAFT_CHAO_IDS:
  var data: Dictionary = PhysicsTuning.CHAO[id]
  var card := VBoxContainer.new()
  card.custom_minimum_size.x = 250
  card.add_theme_constant_override("separation", 10)
  row.add_child(card)
  var title := _label(card, "●  %s — %s" % [data.name, data.role], 19)
  title.modulate = data.color
  _label(card, data.description, 14)
  var stats := _label(card, "", 14)
  stats.custom_minimum_size.y = 114
  var button := _button(card, "Choose " + data.name, func(): choose(id))
  cards[id] = {"stats": stats, "button": button}
 _label(draft, "Effective stats: current build → after this choice. Profile tuning and safety limits still apply.\nMaximum two copies of each Chao; five slots. This Zone awards three choices.", 14)
 draft_footer = _label(draft, "", 15)

func _create_completion(parent: Node) -> void:
 completion = VBoxContainer.new()
 completion.add_theme_constant_override("separation", 20)
 parent.add_child(completion)
 var title := _label(completion, "GREEN HILL ZONE COMPLETE!", 32)
 title.modulate = Color("ffe27a")
 title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 result_label = _label(completion, "", 20)
 result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 var actions := HBoxContainer.new()
 actions.alignment = BoxContainer.ALIGNMENT_CENTER
 actions.add_theme_constant_override("separation", 14)
 completion.add_child(actions)
 replay_button = _button(actions, "Replay Zone — same seed", func():
  game.request_generation(game.generation_seed, -1, -1, {"zone": true})
 )
 free_play_button = _button(actions, "Return to Free Play", func():
  game.request_generation(game.generation_seed, -1, -1, {"zone": false, "enabled": false})
 )
 _limit_focus([replay_button, free_play_button])
 var footer := _label(completion, "Three Acts cleared. Final Chao included in your completed build.\nA replay starts a fresh Zone with no acquired Chao.", 15)
 footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _style(color: Color, padding: int) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = color
 style.border_color = Color("658e7c")
 style.set_border_width_all(1)
 style.set_corner_radius_all(12)
 style.content_margin_left = padding
 style.content_margin_right = padding
 style.content_margin_top = padding
 style.content_margin_bottom = padding
 return style

func _label(parent: Node, text: String, font_size: int) -> Label:
 var label := Label.new()
 label.text = text
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size", font_size)
 parent.add_child(label)
 return label

func _button(parent: Node, text: String, action: Callable) -> Button:
 var button := Button.new()
 button.text = text
 button.add_theme_font_size_override("font_size", 15)
 button.pressed.connect(func():
  action.call()
  button.release_focus()
 )
 parent.add_child(button)
 return button

func choose(id: String) -> void:
 if game.generation_pending or game.zone.state != ZoneRun.State.DRAFT:
  return
 game.choose_zone_chao(id)

func _build_text() -> String:
 var names: PackedStringArray = []
 for id: String in PhysicsTuning.DRAFT_CHAO_IDS:
  var count: int = game.zone.acquired.count(id)
  if count > 0:
   names.append("%s ×%d" % [PhysicsTuning.CHAO[id].name.trim_suffix(" Chao"), count])
 return "None yet" if names.is_empty() else " · ".join(names)

func _refresh_hud() -> void:
 visible = game.zone.enabled
 if not visible:
  return
 var act: int = game.zone.active_act
 heading.text = "GREEN HILL ZONE  ·  ACT %d / 3  ·  %s" % [act + 1, _difficulty_label()]
 var layout_name: String = game.zone.acts[act].get("layout_name", "")
 layout_label.text = "Route: " + layout_name
 layout_label.visible = not layout_name.is_empty()
 score_label.text = "Act score %d / %d   |   Total %d" % [game.zone.act_score, game.zone.targets[act], game.score]
 var destination := "Portal" if act == 2 else "Exit"
 exit_label.text = "%s %s  ·  Checkpoint: Act %d" % [destination, "UNLOCKED — reach it!" if game.zone.exit_unlocked else "LOCKED", act + 1]
 exit_label.modulate = Color("9de583") if game.zone.exit_unlocked else Color("ffe27a")
 build_label.text = "Chao: " + _build_text()

func _difficulty_label() -> String:
 return "EASY" if game.zone_difficulty_override < 0 else "DEV " + TableGenerator.DIFFICULTY_NAMES[game.generation_difficulty].to_upper()

func refresh() -> void:
 if not is_node_ready():
  return
 _refresh_hud()
 draft.visible = game.zone.state == ZoneRun.State.DRAFT
 completion.visible = game.zone.state == ZoneRun.State.COMPLETE
 modal.visible = game.zone.enabled and (draft.visible or completion.visible)
 if draft.visible:
  _refresh_draft()
 if completion.visible:
  result_label.text = "Total Run Score: %d\nActs completed: %d / 3  ·  Seed: %d  ·  %s\nCollected Chao: %s" % [game.score, game.zone.completed_acts, game.generation_seed, _difficulty_label(), _build_text()]
 if _last_state != game.zone.state:
  if draft.visible:
   for id: String in cards:
    if not cards[id].button.disabled:
     cards[id].button.grab_focus()
     break
  elif completion.visible:
   replay_button.grab_focus()
 _last_state = game.zone.state

func _refresh_draft() -> void:
 var act: int = game.zone.completed_acts
 draft_heading.text = "ACT %d CLEAR — %s" % [act, "FINAL CHAO REWARD" if act == 3 else "CHOOSE A CHAO"]
 draft_summary.text = "Act score: %d / %d  ·  Total: %d\nCurrent build: %s" % [game.zone.act_score, game.zone.targets[clampi(act - 1, 0, 2)], game.score, _build_text()]
 draft_footer.text = "Choose one reward to complete Green Hill Zone. No second Zone in this prototype." if act == 3 else "Choose one reward to enter Act %d. Gameplay resumes from this position and velocity." % (act + 1)
 var current: Dictionary = game.tuning.preview_build(game.tuning.build_ids)
 var available: Array[Button] = []
 for id: String in cards:
  var count: int = game.zone.acquired.count(id)
  var ids: Array[String] = []
  for acquired_id: String in game.zone.acquired:
   ids.append(acquired_id)
  ids.append(id)
  var next: Dictionary = game.tuning.preview_build(ids)
  var limited: bool = count >= PhysicsTuning.MAX_CHAO_COPIES or ids.size() > PhysicsTuning.MAX_BUILD_SLOTS
  cards[id].button.disabled = limited or game.generation_pending
  cards[id].button.text = "Two copies already equipped" if limited else "Choose %s (%d → %d)" % [PhysicsTuning.CHAO[id].name, count, count + 1]
  cards[id].stats.text = "Copy limit reached.\nChoose another companion." if next.is_empty() else _stats_text(current, next)
  if not cards[id].button.disabled:
   available.append(cards[id].button)
 _limit_focus(available)

func _limit_focus(buttons: Array[Button]) -> void:
 # Keep keyboard/controller focus inside the mandatory reward or completion UI.
 for index in buttons.size():
  var button := buttons[index]
  var before := button.get_path_to(buttons[(index - 1 + buttons.size()) % buttons.size()])
  var after := button.get_path_to(buttons[(index + 1) % buttons.size()])
  button.focus_previous = before
  button.focus_next = after
  button.focus_neighbor_left = before
  button.focus_neighbor_right = after
  button.focus_neighbor_top = button.get_path_to(button)
  button.focus_neighbor_bottom = button.get_path_to(button)

func _stats_text(current: Dictionary, next: Dictionary) -> String:
 var lines: PackedStringArray = []
 var names := {"steering_acceleration": "Steer", "counter_steering_deceleration": "Brake", "max_steering_speed": "Steer cap", "flipper_launch_strength": "Flip", "ring_magnet_radius": "Ring radius"}
 for key: String in names:
  var before: float = current[key]
  var after: float = next[key]
  if key in ["steering_acceleration", "counter_steering_deceleration"]:
   before *= current.steering_strength
   after *= next.steering_strength
  lines.append("%s: %s → %s %s" % [names[key], str(snappedf(before, 0.1)), str(snappedf(after, 0.1)), PhysicsProfile.FIELDS[key][4]])
 return "\n".join(lines)

func _process(_delta: float) -> void:
 modal.size = get_viewport_rect().size
 _refresh_hud()
 for button: Button in [replay_button, free_play_button]:
  button.disabled = game.generation_pending
