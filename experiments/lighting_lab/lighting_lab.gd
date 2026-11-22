extends "res://experiments/visual_lab/visual_lab.gd"
## Presentation-only atmosphere review using the existing authored Act player.
var lighting_controls: CanvasLayer
const PlaytestSnapshot = preload("res://scripts/atmosphere/playtest_snapshot.gd")
const SpinPreview = preload("res://experiments/visual_lab/sonic_spin_lab.gd")
const Celebration = preload("res://scripts/prototype/combo_celebration.gd")
const Profile = preload("res://scripts/prototype/build_profile.gd")
const PLAY_CAMERAS = preload("res://scripts/endless/endless_game.gd").PLAY_CAMERAS
var character_pose: SpinPreview.Pose
var character_tab: VBoxContainer
var character_picker: OptionButton
var preview: SpinPreview
var preview_states := {}
var previous_tab := 0

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
 _install_character_tab()
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
 arguments.append_array(["--act", ProjectSettings.globalize_path(authored_act_path), "--theme=" + theme_id, "--character=" + character_id, "--atmosphere-preview=" + saved.path])
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
 for property in ["rooftop_materials", "aquarium_materials"]:
  var other = get(property)
  if is_instance_valid(other):
   other.hide()
   other.set_process(false)

func _rebuild_presentation() -> void:
 var inspecting := is_instance_valid(preview)
 if inspecting: _remove_preview()
 if is_instance_valid(lighting_controls): lighting_controls.restore_original()
 super._rebuild_presentation()
 character_pose = Celebration.attach_character_pose(character)
 _hide_material_controls()
 if is_instance_valid(lighting_controls): lighting_controls.bind_theme()
 if inspecting: _show_preview()

func _build_presentation() -> void:
 super._build_presentation()
 character_pose = Celebration.attach_character_pose(character)

func _install_character_tab() -> void:
 character_tab = VBoxContainer.new()
 character_tab.name = "Character"
 lighting_controls.tabs.add_child(character_tab)
 var label := Label.new()
 label.text = "Character"
 character_tab.add_child(label)
 character_picker = OptionButton.new()
 character_tab.add_child(character_picker)
 for id: String in Profile.character_ids():
  character_picker.add_item(CharacterSpecials.CHARACTERS[id].display_name)
  character_picker.set_item_metadata(character_picker.item_count - 1, id)
  if id == character_id: character_picker.select(character_picker.item_count - 1)
 character_picker.item_selected.connect(func(index: int): specials.select_character(character_picker.get_item_metadata(index)))
 debug_panel.act_controls.character_selector.item_selected.connect(func(index: int):
  var id: String = CharacterSpecials.CHARACTER_IDS[index]
  if id != character_id: specials.select_character(id)
 )
 specials.character_changed.connect(_sync_character_selection, CONNECT_DEFERRED)
 lighting_controls.tabs.tab_changed.connect(_tab_changed)
 view_button.text = "F8  Character & animation"

func _sync_character_selection(id: String) -> void:
 if id != character_id: return
 debug_panel.act_controls.character_selector.select(CharacterSpecials.CHARACTER_IDS.find(id))
 for index in character_picker.item_count:
  if character_picker.get_item_metadata(index) == id: character_picker.select(index)
 if is_instance_valid(preview) and preview.active_character != id:
  _remove_preview()
  _show_preview()

func _tab_changed(index: int) -> void:
 if lighting_controls.tabs.get_tab_control(index) == character_tab: _show_preview()
 else: previous_tab = index

func _show_preview() -> void:
 if is_instance_valid(preview): return
 preview = SpinPreview.new()
 preview.game = self
 preview.pose = character_pose
 preview.embedded = true
 preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
 preview.resume_requested.connect(_return_to_table)
 character_tab.add_child(preview)
 preview.restore_view(preview_states.get(character_id, {}))
 view_button.text = "F8  Back to table"

func _remove_preview() -> void:
 preview_states[preview.active_character] = preview.view_state()
 preview.finish()
 character_tab.remove_child(preview)
 preview.queue_free()
 preview = null

func _return_to_table() -> void:
 if is_instance_valid(preview): _remove_preview()
 lighting_controls.tabs.current_tab = previous_tab
 view_button.text = "F8  Character & animation"

func _set_close_view(_enabled: bool) -> void:
 if not is_instance_valid(lighting_controls) or is_source_picker_open(): return
 if is_instance_valid(preview):
  _return_to_table()
  return
 if not lighting_controls.panel.visible: lighting_controls.toggle_panel()
 lighting_controls.tabs.current_tab = lighting_controls.tabs.get_tab_idx_from_control(character_tab)
 _show_preview()

func select_play_camera(preset: int) -> void:
 presentation.set_camera_preset(preset)
 debug_panel.camera_presets.select(preset)

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
  if key == KEY_F8:
   _set_close_view(true)
   get_viewport().set_input_as_handled()
   return
  if key == KEY_F7:
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
