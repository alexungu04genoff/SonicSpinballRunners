class_name ScoreAttackPanel
extends Control
## Mode controls stay visible when the physics lab is hidden.
var game: Node
var mode_selector: OptionButton
var target_field: SpinBox
var target_caption: Label
var start_button: Button
var hint: Label
var victory: PanelContainer
var result_label: Label
var replay_button: Button
var next_button: Button
var free_play_button: Button
var _showing_victory := false
var _celebration: Tween
var chao_button: Button
var chao_lab: ChaoLabPanel
var zone_panel: ZonePanel
var character_selector: OptionButton
var character_panel: CharacterPanel

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var row := HBoxContainer.new()
 row.position = Vector2(25, 108)
 row.add_theme_constant_override("separation", 8)
 add_child(row)
 mode_selector = OptionButton.new()
 mode_selector.add_item("Free Play")
 mode_selector.add_item("Score Attack")
 mode_selector.add_item("Green Hill Zone")
 mode_selector.custom_minimum_size.x = 145
 mode_selector.item_selected.connect(func(_index: int): mode_selector.release_focus())
 row.add_child(mode_selector)
 character_selector = OptionButton.new()
 character_selector.add_item("Sonic · Homing")
 character_selector.add_item("Tails · Flight")
 character_selector.item_selected.connect(func(_index: int): character_selector.release_focus())
 row.add_child(character_selector)
 target_caption = _label(row, "Target", 14)
 target_field = SpinBox.new()
 target_field.min_value = 25
 target_field.max_value = 1000000
 target_field.step = 25
 target_field.custom_minimum_size.x = 105
 target_field.get_line_edit().text_submitted.connect(func(_text: String): target_field.get_line_edit().release_focus())
 row.add_child(target_field)
 start_button = _button(row, "Start / replay", func():
  start_run()
 )
 start_button.tooltip_text = "Apply mode and target to a fresh run on this seed. Score and rings reset; physics tuning stays."
 chao_lab = ChaoLabPanel.new()
 chao_lab.game = game
 chao_lab.start_run = start_run
 chao_lab.next_character = func(): return "sonic" if character_selector.selected == 0 else "tails"
 add_child(chao_lab)
 chao_button = _button(row, "Chao: None", chao_lab.open_lab)
 chao_button.tooltip_text = "Chao Lab: compare three upgrades. Choose at serve or pause; equipping restarts this seed."
 hint = _label(row, "", 12)
 victory = PanelContainer.new()
 victory.position = Vector2(295, 310)
 victory.custom_minimum_size = Vector2(505, 240)
 victory.pivot_offset = Vector2(252, 120)
 var style := StyleBoxFlat.new()
 style.bg_color = Color("102b36")
 style.border_color = Color("ffe27a")
 style.set_border_width_all(3)
 style.set_corner_radius_all(14)
 style.content_margin_left = 24
 style.content_margin_right = 24
 style.content_margin_top = 20
 style.content_margin_bottom = 20
 victory.add_theme_stylebox_override("panel", style)
 add_child(victory)
 var stack := VBoxContainer.new()
 stack.add_theme_constant_override("separation", 14)
 victory.add_child(stack)
 var title := _label(stack, "SCORE ATTACK CLEAR!", 30)
 title.modulate = Color("ffe27a")
 title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 result_label = _label(stack, "", 18)
 result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 var actions := HBoxContainer.new()
 actions.alignment = BoxContainer.ALIGNMENT_CENTER
 stack.add_child(actions)
 replay_button = _button(actions, "Replay same seed", func(): game.request_generation(game.generation_seed))
 next_button = _button(actions, "Next table", func(): game.request_generation((game.generation_seed + 1) % 2147483648))
 free_play_button = _button(actions, "Free Play", func(): game.request_generation(game.generation_seed, -1, -1, {"enabled": false}))
 var footer := _label(stack, "Same physics. Unlimited retries. One successful climb.", 14)
 footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 victory.visible = false
 zone_panel = ZonePanel.new()
 zone_panel.game = game
 add_child(zone_panel)
 character_panel = CharacterPanel.new()
 character_panel.game = game
 character_panel.selector = character_selector
 add_child(character_panel)
 game.score_attack.changed.connect(refresh)
 game.zone.changed.connect(func():
  if game.zone.state == ZoneRun.State.INACTIVE or game.generation_pending:
   refresh()
 )
 refresh()

func _label(parent: Node, text: String, font_size: int) -> Label:
 var label := Label.new()
 label.text = text
 label.add_theme_font_size_override("font_size", font_size)
 parent.add_child(label)
 return label

func _button(parent: Node, text: String, action: Callable) -> Button:
 var button := Button.new()
 button.text = text
 button.add_theme_font_size_override("font_size", 14)
 button.pressed.connect(func():
  action.call()
  button.release_focus()
 )
 parent.add_child(button)
 return button

func refresh() -> void:
 character_selector.select(0 if game.character_id == "sonic" else 1)
 mode_selector.select(2 if game.zone_enabled else (1 if game.score_attack_enabled else 0))
 target_field.value = game.score_attack_target

func start_run(chao_id: String = "") -> bool:
 target_field.apply()
 var settings := {"enabled": mode_selector.selected == 1, "target": int(target_field.value), "zone": mode_selector.selected == 2}
 if settings.zone:
  settings.merge(game.debug_panel.zone_generation_settings())
 settings.character = "sonic" if character_selector.selected == 0 else "tails"
 if not chao_id.is_empty():
  settings.chao = chao_id
 return game.request_generation(game.generation_seed, -1, -1, settings)

func _process(_delta: float) -> void:
 chao_button.text = "Act rewards" if game.zone_enabled else "Chao: %s · Lab" % PhysicsTuning.CHAO[game.tuning.chao_id].name.trim_suffix(" Chao")
 chao_button.modulate = PhysicsTuning.CHAO[game.tuning.chao_id].color
 chao_button.disabled = not game.can_regenerate() or game.zone_enabled or mode_selector.selected == 2
 start_button.disabled = not game.can_regenerate()
 character_selector.disabled = not game.can_regenerate()
 target_field.editable = mode_selector.selected == 1
 target_field.visible = mode_selector.selected != 2
 target_caption.visible = mode_selector.selected != 2
 hint.text = "Pause to edit" if start_button.disabled else "Resets the run"
 var completed: bool = game.score_attack.state == ScoreAttack.State.COMPLETE
 victory.visible = completed
 if completed and not _showing_victory:
  result_label.text = "Upper goal reached!\nScore %d  /  Target %d  /  Seed %d" % [game.score, game.score_attack.target, game.generation_seed]
  victory.scale = Vector2.ONE * 0.94
  _celebration = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
  _celebration.tween_property(victory, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  replay_button.grab_focus()
 elif not completed and _showing_victory and _celebration:
  _celebration.kill()
 _showing_victory = completed
 for button: Button in [replay_button, next_button, free_play_button]:
  button.disabled = game.generation_pending
