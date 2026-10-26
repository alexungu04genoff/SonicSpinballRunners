extends Control
## Standalone Act replay and session loadout controls.
var game: Node
var character_selector: OptionButton
var start_button: Button
var chao_button: Button
var chao_lab: ChaoLabPanel
var character_panel: CharacterPanel
var hint: Label

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var row := HBoxContainer.new()
 row.position = Vector2(25, 108)
 row.add_theme_constant_override("separation", 8)
 add_child(row)
 character_selector = OptionButton.new()
 for id: String in CharacterSpecials.CHARACTER_IDS:
  character_selector.add_item(CharacterSpecials.CHARACTERS[id].selection_label)
 character_selector.select(CharacterSpecials.CHARACTER_IDS.find(game.character_id))
 character_selector.item_selected.connect(func(_index: int): character_selector.release_focus())
 row.add_child(character_selector)
 start_button = _button(row, "Replay Act", func(): start_run())
 start_button.tooltip_text = "Reload this saved Act with the selected character and Chao. Score and rings reset; physics tuning stays."
 chao_lab = ChaoLabPanel.new()
 chao_lab.game = game
 chao_lab.start_run = start_run
 chao_lab.next_character = func(): return CharacterSpecials.CHARACTER_IDS[character_selector.selected]
 add_child(chao_lab)
 chao_button = _button(row, "Chao: None", chao_lab.open_lab)
 hint = Label.new()
 row.add_child(hint)
 character_panel = CharacterPanel.new()
 character_panel.game = game
 character_panel.selector = character_selector
 add_child(character_panel)

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

func start_run(chao_id: String = "") -> bool:
 var settings := {"character": CharacterSpecials.CHARACTER_IDS[character_selector.selected]}
 if not chao_id.is_empty(): settings.chao = chao_id
 return game.request_replay(settings)

func _process(_delta: float) -> void:
 var available: bool = game.can_reload_act()
 start_button.disabled = not available
 character_selector.disabled = not available
 chao_button.disabled = not available
 chao_button.text = "Chao: %s · Lab" % PhysicsTuning.CHAO[game.tuning.chao_id].name.trim_suffix(" Chao")
 chao_button.modulate = PhysicsTuning.CHAO[game.tuning.chao_id].color
 hint.text = "Resets the Act" if available else "Pause to edit"
