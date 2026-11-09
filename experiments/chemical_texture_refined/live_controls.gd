extends CanvasLayer
var game: Node
var panel: PanelContainer
var maps_toggle: CheckButton
var light_toggle: CheckButton
var _last_theme := ""

func install(owner_game: Node) -> void:
 game=owner_game
 layer=35
 process_mode=Node.PROCESS_MODE_ALWAYS
 var root := Control.new()
 root.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(root)
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=PanelContainer.new()
 root.add_child(panel)
 panel.position=Vector2(20,200)
 var style := StyleBoxFlat.new()
 style.bg_color=Color(.025,.07,.11,.97)
 style.set_content_margin_all(12)
 panel.add_theme_stylebox_override("panel",style)
 var column := VBoxContainer.new()
 panel.add_child(column)
 var header := HBoxContainer.new()
 column.add_child(header)
 var title := Label.new()
 title.text="Chemical Plant | F8 controls | F7 close-up"
 header.add_child(title)
 var close := Button.new()
 close.text="Close ×"
 close.focus_mode=Control.FOCUS_NONE
 close.pressed.connect(panel.hide)
 header.add_child(close)
 maps_toggle=CheckButton.new()
 maps_toggle.text="Material relief"
 maps_toggle.button_pressed=true
 maps_toggle.toggled.connect(func(value: bool) -> void:
  var theme=game.presentation.theme_definition
  theme.material_maps.enabled=value
  theme.material_maps.update(game.presentation)
 )
 column.add_child(maps_toggle)
 light_toggle=CheckButton.new()
 light_toggle.text="Improved lighting"
 light_toggle.button_pressed=true
 light_toggle.toggled.connect(func(value: bool) -> void: game.presentation.theme_definition.set_lighting(game.presentation,value))
 column.add_child(light_toggle)
 add_value(column,"Normal strength",0.0,2.0,.05,1.0,func(value: float) -> void:
  var theme=game.presentation.theme_definition
  theme.material_maps.strength=value
  theme.material_maps.update(game.presentation)
 )
 add_value(column,"Key light",.3,2.0,.05,1.25,func(value: float) -> void:
  var theme=game.presentation.theme_definition
  theme.key_energy=value
  theme.set_lighting(game.presentation,theme.improved_lighting)
 )
 add_value(column,"Ambient fill",.1,.8,.02,.30,func(value: float) -> void:
  var theme=game.presentation.theme_definition
  theme.ambient_energy=value
  theme.set_lighting(game.presentation,theme.improved_lighting)
 )
 add_value(column,"Neon intensity",0.0,3.0,.1,1.5,func(value: float) -> void:
  var theme=game.presentation.theme_definition
  theme.material_maps.neon_strength=value
  theme.material_maps.update(game.presentation)
 )
 add_value(column,"Ledge neon spread",.1,3.0,.1,1.5,func(value: float) -> void:
  var theme=game.presentation.theme_definition
  theme.material_maps.neon_spread=value
  theme.material_maps.update(game.presentation)
 )
 add_value(column,"Floor neon spread",.1,4.0,.1,2.7,func(value: float) -> void:
  var theme=game.presentation.theme_definition
  theme.material_maps.floor_neon_spread=value
  theme.material_maps.update(game.presentation)
 )
 panel.hide()
 if "--chemical-comparison" in OS.get_cmdline_user_args(): call_deferred("save_comparison")
 if "--chemical-neon-preview" in OS.get_cmdline_user_args(): call_deferred("save_neon_preview")

func save_neon_preview() -> void:
 for frame in 30: await get_tree().process_frame
 game.rooftop_materials.toggle_detail_camera()
 game._toggle_photo_ui()
 for frame in 12: await get_tree().process_frame
 await RenderingServer.frame_post_draw
 game.get_viewport().get_texture().get_image().save_png("res://experiments/chemical_texture_refined/screenshots/neon.png")
 game._toggle_photo_ui()
 print("CHEMICAL_NEON | Preview saved; F8 adjusts neon intensity.")

func add_value(parent: Node,title: String,low: float,high: float,step: float,value: float,callback: Callable) -> void:
 var row := HBoxContainer.new()
 parent.add_child(row)
 var label := Label.new()
 label.text=title
 label.custom_minimum_size.x=170
 row.add_child(label)
 var field := SpinBox.new()
 field.min_value=low
 field.max_value=high
 field.step=step
 field.value=value
 field.custom_minimum_size.x=120
 field.value_changed.connect(callback)
 row.add_child(field)

func _process(_delta: float) -> void:
 if _last_theme!=game.theme_id:
  _last_theme=game.theme_id
  visible=_last_theme=="chemical_plant"

func handle_key(event: InputEventKey) -> bool:
 if game.theme_id!="chemical_plant": return false
 var key := event.physical_keycode if event.physical_keycode!=0 else event.keycode
 if key==KEY_F8: panel.visible=not panel.visible
 elif key==KEY_F7: game.rooftop_materials.toggle_detail_camera()
 elif key==KEY_F4: game.retro_filter.set_effects(game.retro_filter.settings.default_effects if game.retro_filter.selected_effects.is_empty() else [])
 else: return false
 return true

func save_comparison() -> void:
 for frame in 30: await get_tree().process_frame
 var was_paused: bool=get_tree().paused
 get_tree().paused=true
 game.rooftop_materials.toggle_detail_camera()
 # Identical clean rendering for both frames; no time-varying retro grain.
 var effects=game.retro_filter.selected_effects.duplicate()
 game.retro_filter.set_effects([])
 var hidden: Array[CanvasLayer]=[]
 for layer: Node in game.find_children("*","CanvasLayer",true,false):
  if layer!=game.retro_filter.effect_layer and layer.visible:
   hidden.append(layer)
   layer.hide()
 var folder := "res://experiments/chemical_texture_refined/screenshots/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var theme=game.presentation.theme_definition
 for enhanced in [false,true]:
  theme.material_maps.enabled=enhanced
  theme.material_maps.update(game.presentation)
  theme.set_lighting(game.presentation,enhanced)
  for frame in 12: await get_tree().process_frame
  await RenderingServer.frame_post_draw
  game.get_viewport().get_texture().get_image().save_png(folder+("after.png" if enhanced else "before.png"))
 for layer in hidden: layer.show()
 game.retro_filter.set_effects(effects)
 get_tree().paused=was_paused
 print("CHEMICAL_COMPARISON | Same-camera before and after saved. F8 controls; F7 camera; F4 retro.")
