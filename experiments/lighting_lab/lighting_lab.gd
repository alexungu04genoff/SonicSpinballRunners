extends "res://experiments/visual_lab/visual_lab.gd"
## Presentation-only atmosphere review using the existing authored Act player.
var lighting_controls: CanvasLayer

func _ready() -> void:
 # This review tool should expose available rendering headroom by default.
 # Simulation frequency remains the project's authoritative 120 Hz.
 Engine.max_fps = 0
 if DisplayServer.get_name() != "headless":
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 super._ready()
 DisplayServer.window_set_title("Lighting Lab · Atmosphere")
 if not is_instance_valid(presentation): return
 # Other local material experiments may be installed in the shared visual lab.
 # Keep their selected materials, but give this lab sole ownership of its UI.
 _hide_material_controls()
 lighting_controls = preload("res://experiments/lighting_lab/live_controls.gd").new()
 add_child(lighting_controls)
 lighting_controls.install(self)
 presentation.set_camera_follow(false)
 print("LIGHTING_LAB_READY | ", RenderingServer.get_current_rendering_method(), " | VSync ", DisplayServer.window_get_vsync_mode(), " | FPS cap ", Engine.max_fps, " | F6 controls | wheel zoom | middle-drag pan | O follow/overview")

func _hide_material_controls() -> void:
 # The shared visual Lab can provide its own FPS overlay. This inspector owns
 # the persistent counter, so retain a single readable overlay here.
 var inherited_fps := get_node_or_null("FrameRateOverlay")
 if inherited_fps is CanvasLayer: inherited_fps.hide()
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
  # Hidden Rooftop material experiments also use 1/2 to replace materials.
  # Those swaps would bypass this Lab's bound palette copies. Numeric fields
  # still receive normal text input while focused.
  if theme_id == "rooftop_run" and is_instance_valid(get("rooftop_materials")) and key in [KEY_1, KEY_2]:
   var focus := get_viewport().gui_get_focus_owner()
   if not focus is LineEdit and not focus is TextEdit:
    get_viewport().set_input_as_handled()
    return
 super._input(event)

func _unhandled_input(event: InputEvent) -> void:
 # In Play View the inspector overlaps the world. A wheel event at a scroll
 # limit must never fall through to the camera, nor should a UI middle-drag.
 if event is InputEventMouse and is_instance_valid(lighting_controls) and lighting_controls.blocks_camera_at(event.position):
  get_viewport().set_input_as_handled()
  return
 # Wheel/pan immediately enter inspection mode, including from Follow camera.
 if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
  if view_container.get_global_rect().has_point(event.position) and not is_source_picker_open():
   presentation.set_camera_follow(false)
 super._unhandled_input(event)
