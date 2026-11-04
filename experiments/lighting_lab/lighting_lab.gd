extends "res://experiments/visual_lab/visual_lab.gd"
## Presentation-only atmosphere review using the existing authored Act player.
var lighting_controls: CanvasLayer
const PlaytestSnapshot = preload("res://scripts/atmosphere/playtest_snapshot.gd")

func _ready() -> void:
 # Exported authoring tools edit external Acts so scenery sidecars remain writable.
 authored_act_path = preload("res://scripts/portable_workspace.gd").external_act_path(authored_act_path)
 # This review tool should expose available rendering headroom by default.
 # Simulation frequency remains the project's authoritative 120 Hz.
 Engine.max_fps = 0
 if DisplayServer.get_name() != "headless":
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 super._ready()
 DisplayServer.window_set_title("Atmosphere Lab · Lighting")
 if not is_instance_valid(presentation): return
 # Other local material experiments may be installed in the shared visual lab.
 # Keep their selected materials, but give this lab sole ownership of its UI.
 _hide_material_controls()
 lighting_controls = preload("res://experiments/lighting_lab/live_controls.gd").new()
 add_child(lighting_controls)
 lighting_controls.install(self)
 # Keep the embedded ball as an inspection aid; the main Play action uses Prototype.
 play_buttons.get_child(0).hide()
 var prototype_button := _button("Play Prototype", play_prototype)
 play_buttons.add_child(prototype_button)
 play_buttons.move_child(prototype_button, 0)
 presentation.set_camera_follow(false)
 print("LIGHTING_LAB_READY | ", RenderingServer.get_current_rendering_method(), " | VSync ", DisplayServer.window_get_vsync_mode(), " | FPS cap ", Engine.max_fps, " | F6 controls | wheel zoom | middle-drag pan | O follow/overview")

func prototype_playtest_request() -> Dictionary:
 if loading_act or not is_instance_valid(lighting_controls): return {"error": "Wait for the Act to finish loading."}
 # Commit text currently being edited before capturing the visible appearance.
 var focus := get_viewport().gui_get_focus_owner()
 if focus is LineEdit and focus.get_parent() is SpinBox: focus.get_parent().apply()
 var source: Dictionary = lighting_controls.originals if lighting_controls.compare.button_pressed else lighting_controls.values
 var name := "Original atmosphere" if lighting_controls.compare.button_pressed else "Lab draft"
 var record: Dictionary = lighting_controls.variants.selected_record()
 if not record.is_empty() and not lighting_controls.compare.button_pressed: name = str(record.name)
 var saved := PlaytestSnapshot.save_preview({"theme": theme_id, "name": name, "values": source.duplicate(true)})
 if not saved.error.is_empty(): return saved
 var arguments := PackedStringArray(["--rendering-method", "forward_plus", "--rendering-driver", "vulkan"])
 if OS.has_feature("editor"):
  arguments.append_array(["--path", ProjectSettings.globalize_path("res://"), "res://scenes/prototype_run.tscn", "--"])
 else:
  arguments.append_array(["--", "--portable-play"])
 arguments.append_array(["--act", ProjectSettings.globalize_path(authored_act_path), "--theme=" + theme_id, "--atmosphere-preview=" + saved.path])
 return {"error": "", "arguments": arguments, "path": saved.path}

func play_prototype() -> void:
 var request := prototype_playtest_request()
 if not request.error.is_empty():
  lighting_controls.message.text = request.error
  return
 var process := OS.create_process(OS.get_executable_path(), request.arguments)
 lighting_controls.message.text = "Prototype opened with this atmosphere. New lighting edits: click Play Prototype again." if process >= 0 else "Could not open Prototype."

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
 # Text entry owns keys before the inherited camera, pose and material shortcuts.
 if event is InputEventKey:
  var focus := get_viewport().gui_get_focus_owner()
  if focus is LineEdit or focus is TextEdit: return
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
