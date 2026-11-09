extends CanvasLayer
## Small session-only controls for judging the approved materials.
var maps: RefCounted
var retro: Node

func install(material_maps: RefCounted, retro_filter: Node) -> void:
 maps=material_maps
 retro=retro_filter
 process_mode=Node.PROCESS_MODE_ALWAYS
 layer=80
 var panel:=PanelContainer.new()
 panel.position=Vector2(16,16)
 add_child(panel)
 var row:=HBoxContainer.new()
 row.add_theme_constant_override("separation",14)
 panel.add_child(row)
 var toggle:=CheckButton.new()
 toggle.text="Material maps"
 toggle.button_pressed=true
 toggle.toggled.connect(func(value: bool): maps.enabled=value; maps.update())
 row.add_child(toggle)
 var label:=Label.new()
 label.text="Normal strength"
 row.add_child(label)
 var slider:=HSlider.new()
 slider.custom_minimum_size=Vector2(170,0)
 slider.min_value=0.0
 slider.max_value=2.0
 slider.step=0.05
 slider.value=1.0
 slider.value_changed.connect(func(value: float): maps.strength=value; maps.update())
 row.add_child(slider)
 var ao_label:=Label.new()
 ao_label.text="Cavity"
 row.add_child(ao_label)
 var ao_slider:=HSlider.new()
 ao_slider.custom_minimum_size=Vector2(110,0)
 ao_slider.max_value=1.0
 ao_slider.step=0.05
 ao_slider.value=maps.ao_strength
 ao_slider.value_changed.connect(func(value: float): maps.ao_strength=value; maps.update())
 row.add_child(ao_slider)
 var retro_toggle:=CheckButton.new()
 retro_toggle.text="Retro"
 retro_toggle.toggled.connect(func(value: bool): retro.set_effects(retro.settings.default_effects if value else []))
 row.add_child(retro_toggle)

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_F8: visible=not visible
  elif event.keycode==KEY_F11:
   var mode:=DisplayServer.window_get_mode()
   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
