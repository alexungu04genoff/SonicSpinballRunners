extends CanvasLayer
## Small, temporary authoring controls for the canonical production materials.
const Materials = preload("res://scripts/themes/sanctuary_selected_materials.gd")
var game: Node
var panel: PanelContainer
var detail: CheckButton
var strength: SpinBox
var _last_theme := ""

func install(owner_game: Node) -> void:
 game=owner_game
 layer=35
 process_mode=Node.PROCESS_MODE_ALWAYS
 panel=PanelContainer.new()
 panel.position=Vector2(20,200)
 add_child(panel)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color(.025,.07,.11,.97)
 style.set_content_margin_all(12)
 panel.add_theme_stylebox_override("panel",style)
 var column:=VBoxContainer.new()
 panel.add_child(column)
 var title:=Label.new()
 title.text="Sky Sanctuary materials · F8"
 column.add_child(title)
 detail=CheckButton.new()
 detail.text="Material detail"
 detail.button_pressed=true
 column.add_child(detail)
 var row:=HBoxContainer.new()
 column.add_child(row)
 var label:=Label.new()
 label.text="Normal strength"
 row.add_child(label)
 strength=SpinBox.new()
 strength.min_value=0.0
 strength.max_value=2.0
 strength.step=.05
 strength.value=1.0
 row.add_child(strength)
 var close:=Button.new()
 close.text="Close"
 close.pressed.connect(panel.hide)
 column.add_child(close)
 detail.toggled.connect(func(_value: bool):refresh())
 strength.value_changed.connect(func(_value: float):refresh())
 panel.hide()
 visible=game.theme_id=="sky_sanctuary"

func refresh() -> void:
 if game.theme_id=="sky_sanctuary":
  Materials.set_detail(game.presentation,detail.button_pressed,strength.value)

func _process(_delta: float) -> void:
 if _last_theme==game.theme_id:return
 _last_theme=game.theme_id
 visible=_last_theme=="sky_sanctuary"
 refresh()

func handle_key(event: InputEventKey) -> bool:
 if game.theme_id!="sky_sanctuary":return false
 var key:=event.physical_keycode if event.physical_keycode!=0 else event.keycode
 if key!=KEY_F8:return false
 panel.visible=not panel.visible
 return true
