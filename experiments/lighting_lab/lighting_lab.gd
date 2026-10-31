extends "res://experiments/visual_lab/visual_lab.gd"
## Presentation-only lighting review using the existing authored Act player.
var lighting_controls: CanvasLayer

func _ready() -> void:
 super._ready()
 if not is_instance_valid(presentation): return
 # Other local material experiments may be installed in the shared visual lab.
 # Keep their selected materials, but give this lab sole ownership of its UI.
 _hide_material_controls()
 lighting_controls = preload("res://experiments/lighting_lab/live_controls.gd").new()
 add_child(lighting_controls)
 lighting_controls.install(self)
 presentation.set_camera_follow(false)
 print("LIGHTING_LAB_READY | ", RenderingServer.get_current_rendering_method(), " | F6 controls | wheel zoom | middle-drag pan | O follow/overview")

func _hide_material_controls() -> void:
 for property in ["rooftop_materials", "chemical_materials"]:
  var other = get(property)
  if is_instance_valid(other):
   other.hide()
   other.set_process(false)

func _rebuild_presentation() -> void:
 if is_instance_valid(lighting_controls): lighting_controls.restore_original()
 super._rebuild_presentation()
 _hide_material_controls()
 if is_instance_valid(lighting_controls): lighting_controls.bind_theme()

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if key == KEY_F6 and is_instance_valid(lighting_controls):
   lighting_controls.toggle_panel()
   get_viewport().set_input_as_handled()
   return
  # Shared local material panels also use these shortcuts. Keep them closed here.
  if key in [KEY_F7, KEY_F8]:
   get_viewport().set_input_as_handled()
   return
 super._input(event)

func _unhandled_input(event: InputEvent) -> void:
 # Wheel/pan immediately enter inspection mode, including from Follow camera.
 if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
  if view_container.get_global_rect().has_point(event.position) and not is_source_picker_open():
   presentation.set_camera_follow(false)
 super._unhandled_input(event)
