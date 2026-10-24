class_name CharacterPanel
extends PanelContainer
var game: Node
var selector: OptionButton
var heading: Label
var description: Label
var meter: ProgressBar
var feedback: Label
var combo_hud: ScorecraftPanel

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 position = Vector2(625, 155)
 custom_minimum_size.x = 245
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var style := StyleBoxFlat.new()
 style.bg_color = Color("102b36")
 style.set_content_margin_all(10)
 style.set_corner_radius_all(8)
 add_theme_stylebox_override("panel", style)
 var stack := VBoxContainer.new()
 add_child(stack)
 heading = _label(stack, 16)
 description = _label(stack, 13)
 meter = ProgressBar.new()
 meter.custom_minimum_size.y = 20
 stack.add_child(meter)
 feedback = _label(stack, 13)
 combo_hud = ScorecraftPanel.new()
 combo_hud.game = game
 stack.add_child(combo_hud)

func _label(parent: Node, font_size: int) -> Label:
 var label := Label.new()
 label.custom_minimum_size.x = 225
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size", font_size)
 parent.add_child(label)
 return label

func _process(_delta: float) -> void:
 var ability: CharacterSpecials = game.specials
 var selected: CharacterDefinition = CharacterSpecials.CHARACTERS[CharacterSpecials.CHARACTER_IDS[selector.selected]]
 heading.text = "%s · %s" % [ability.definition.display_name, "READY · Space / A" if ability.ready_to_use() else "Special · Space / A"]
 heading.modulate = ability.definition.color
 description.text = selected.description
 if selected != ability.definition:
  description.text = "Next run: %s\n%s" % [selected.display_name, selected.description]
 meter.max_value = ability.definition.meter_capacity
 meter.value = game.special_meter
 feedback.text = ability.feedback
