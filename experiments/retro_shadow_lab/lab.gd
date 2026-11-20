extends Node
## This scene is the only entry point. Review sessions use the disk-backed game.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const AtmosphereFields = preload("res://scripts/atmosphere/fields.gd")
const Receivers = preload("receivers.gd")
const Endless = preload("res://scripts/diagnostics/grounding_endless.gd")
const ACTS := [Fixture.DEFAULT_ACT, "res://data/acts/Authored/RampMania.tres", "res://data/acts/Experiments/Side to Side.tres", "res://data/acts/Experiments/Launch Tube Workshop.tres"]
const MODES := ["Normal", "Clean · 2 levels", "Clean · 4 levels", "Ordered dither · 4 levels", "Clean · 3 levels", "Clean · 8 levels", "Clean · 5 levels"]
const MENU_ORDER := [0, 5, 6, 2, 4, 3, 1]
const PROFILES := ["production", "quality", "performance"]
@export var lab_title := "Retro Shadow Lab"
@export var capture_argument := "--shadow-evidence"
@export var capture_script: GDScript
var receivers := Receivers.new()
var fixture: RefCounted
var game: Node
var theme := "green_hill"
var act_index := 0
var endless := false
var study_card := false
var profile := 1
var mode := 0
var rings := true
var reviewed_rings: Array[WeakRef] = []
var ring_span := Vector2i(-1, -1)
var displayed_span := Vector2i(-1, -1)
var playing := false
var busy := true
var closing := false
var output := "user://retro-shadow-lab"
var layer := CanvasLayer.new()
var panel := VBoxContainer.new()
var status := Label.new()
var blur: SpinBox
var angle: SpinBox
var zoom: SpinBox
var tone_fields: Array[SpinBox] = []
var tone_row: HBoxContainer
var pattern_row: HBoxContainer
var motion_time := 0.0
var open_ms := 0.0
var start_focus := Vector2.ZERO
var camera_choice: OptionButton
var mode_choice: OptionButton
var theme_choice: OptionButton
var focus_choice: OptionButton
var pan_clock := 0
var failures: Array[String] = []
var evidence: RefCounted

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 Engine.time_scale = 0.0
 Engine.max_fps = 0
 var window := get_window()
 window.size = Vector2i(1280, 900)
 Review.position_review_window(window)
 window.title = lab_title
 get_tree().auto_accept_quit = false
 window.close_requested.connect(close)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
  if arg.begins_with("--theme="): theme = arg.trim_prefix("--theme=")
  if arg == "--penumbra-study": study_card = true; mode = 5
 DirAccess.make_dir_recursive_absolute(output)
 Review.Options.settings_path = output.path_join("isolated-graphics.cfg")
 Review.Options.update_quality(lab_profile(profile), false)
 build_ui()
 if capture_argument in OS.get_cmdline_user_args():
  var runner: GDScript = capture_script if capture_script else load("res://experiments/retro_shadow_lab/evidence.gd")
  evidence = runner.new()
  evidence.run.call_deferred(self)
 else:
  open_game.call_deferred()

func row() -> HBoxContainer:
 var box := HBoxContainer.new()
 panel.add_child(box)
 return box

func choice(parent: Node, names: Array, index: int, callback: Callable) -> OptionButton:
 var menu := OptionButton.new()
 for item: String in names: menu.add_item(item)
 menu.select(index)
 menu.item_selected.connect(callback)
 parent.add_child(menu)
 return menu

func number(parent: Node, caption: String, low: float, high: float, step: float, value: float, callback: Callable) -> SpinBox:
 var label := Label.new()
 label.text = caption
 parent.add_child(label)
 var spin := SpinBox.new()
 spin.min_value = low
 spin.max_value = high
 spin.step = step
 spin.value = value
 spin.value_changed.connect(callback)
 parent.add_child(spin)
 return spin

func build_ui() -> void:
 add_child(layer)
 layer.layer = 120
 var frame := PanelContainer.new()
 layer.add_child(frame)
 frame.add_child(panel)
 var box := row()
 var mode_names := MENU_ORDER.map(func(i): return MODES[i])
 mode_choice = choice(box, mode_names, MENU_ORDER.find(mode), func(i): set_mode(MENU_ORDER[i]))
 choice(box, ["Profile A", "Profile B", "Profile C"], profile, set_profile)
 theme_choice = choice(box, Fixture.Registry.NAMES, Fixture.Registry.IDS.find(theme), func(i): theme = Fixture.Registry.IDS[i]; open_game())
 choice(box, ["First Try", "RampMania", "Side to Side", "Launch Tube", "Penumbra study", "Endless tour"], 4 if study_card else 0, select_fixture)
 choice(box, ["Ring shadows on", "Ring shadows off"], 0, func(i): set_rings(i == 0))
 pattern_row = row()
 box = pattern_row
 var origin_label := Label.new()
 origin_label.text = "Saturn/Dreamcast-inspired pattern"
 box.add_child(origin_label)
 choice(box, ["Screen", "Object", "World"], 2, func(i): receivers.anchor = i; receivers.update())
 choice(box, ["Bayer 2×2", "Bayer 4×4"], 1, func(i): receivers.matrix = [2, 4][i]; receivers.update())
 number(box, "Cell", 0.01, 0.25, 0.005, receivers.cell, func(v): receivers.cell = v; receivers.update())
 number(box, "Width", 0, 1, 0.05, receivers.width, func(v): receivers.width = v; receivers.update())
 pattern_row.hide()
 tone_row = row()
 box = tone_row
 tone_fields.append(number(box, "Two-level dark", 0, 1, 0.01, receivers.binary_dark, func(v): receivers.binary_dark = v; receivers.update()))
 for i in 4:
  tone_fields.append(number(box, ["Dark", "Low", "High", "Lit"][i], 0, 1, 0.01, receivers.levels[i], func(v): receivers.levels[i] = v; receivers.update()))
 tone_row.hide()
 box = row()
 blur = number(box, "Blur", 0.5, AtmosphereFields.MAX_SHADOW_BLUR, 0.05, 1, func(v): if game: game.presentation._key_light.shadow_blur = v)
 angle = number(box, "Sun °", 0, 5, 0.05, 0, func(v): if game: game.presentation._key_light.light_angular_distance = v)
 camera_choice = choice(box, ["Dramatic", "Wide", "Real", "Top-down"], 0, func(i): if game: game.select_play_camera(game.PLAY_CAMERAS[i]); camera(start_focus))
 zoom = number(box, "Zoom", 0.6, 2.5, 0.05, 1.3, func(v): if game: game.presentation.camera_settings.zoom = v; camera(start_focus))
 box = row()
 focus_choice = choice(box, ["Serve", "Ring row", "Raised edge", "Act center"], 0, set_focus)
 choice(box, ["Hold pose", "Pan + spin", "Play Act / tour"], 0, set_motion)
 var native := Button.new()
 native.text = "Native range"
 native.pressed.connect(set_native_range)
 box.add_child(native)
 for label: String in ["Starting tones", "Deeper tones"]:
  var button := Button.new()
  button.text = label
  button.pressed.connect(set_tones.bind(label == "Deeper tones"))
  box.add_child(button)
 panel.add_child(status)

func set_tones(deeper: bool) -> void:
 receivers.native_range = false
 tone_row.show()
 receivers.binary_dark = 0.32 if deeper else 0.50
 receivers.levels = Vector4(0.08, 0.30, 0.67, 1.00) if deeper else Vector4(0.25, 0.50, 0.75, 1.00)
 tone_fields[0].set_value_no_signal(receivers.binary_dark)
 for i in 4: tone_fields[i + 1].set_value_no_signal(receivers.levels[i])
 receivers.update()
 refresh()

func set_native_range() -> void:
 receivers.native_range = true
 tone_row.hide()
 receivers.update()
 refresh()

func set_mode(index: int) -> void:
 mode = index
 mode_choice.select(MENU_ORDER.find(index))
 if pattern_row: pattern_row.visible = index == 3
 receivers.mode = -1 if index == 0 else index
 if game:
  receivers.sync(game)
  if index != 0: receivers.update()
 refresh()

func lab_profile(index: int) -> Dictionary:
 var settings := Review.profile(PROFILES[index])
 # Both experiment scenes provide their own treatments over the historical
 # control image. Keep the production choices out of their A/B comparisons.
 settings.authored_faces = false
 settings.clean_eight_shadows = false
 return settings

func set_profile(index: int) -> void:
 profile = index
 Review.Options.update_quality(lab_profile(index), false)
 refresh()

func full_retro_active() -> bool:
 return game.retro_filter.selected_effects == game.retro_filter.settings.default_effects

func keep_full_retro(_preset := -1) -> void:
 if not full_retro_active(): game.retro_filter.set_effects(game.retro_filter.settings.default_effects)

func set_rings(enabled: bool) -> void:
 rings = enabled
 for ref: WeakRef in reviewed_rings:
  var ring: MeshInstance3D = ref.get_ref()
  if ring: Review.show_ring_shadows([ring], true)
 reviewed_rings.clear()
 ring_span = Vector2i(-1, -1)
 if not enabled and game and not game.resident.is_empty():
  ring_span = resident_span()
  for ring: MeshInstance3D in game.presentation.ring_visuals:
   reviewed_rings.append(weakref(ring))
  Review.show_ring_shadows(game.presentation.ring_visuals, false)

func resident_span() -> Vector2i:
 return Vector2i(game.resident.front().plan.sequence, game.resident.back().plan.sequence)

func select_fixture(index: int) -> void:
 study_card = index == 4
 endless = index == 5
 act_index = index if index < ACTS.size() else 0
 open_game()

func camera(target: Vector2) -> void:
 game.presentation.reset_camera(target)
 game._update_backgrounds()

func set_focus(index: int) -> void:
 if not game or not game.started: return
 start_focus = game.ball.position
 if index == 1:
  for ring: MeshInstance3D in game.presentation.ring_visuals:
   if ring.is_visible_in_tree():
    start_focus = TablePresentation.unmap_point(ring.global_position)
    break
 if index == 2: start_focus = Vector2(game.active.plan.offset) + Vector2(570, 500)
 if index == 3: start_focus = game.active.bounds().get_center()
 camera(start_focus)

func spin(phase: float) -> void:
 var presentation: Node = game.presentation
 presentation.ring_spin_phase = phase
 presentation._spin_rings(0.0)

var motion_mode := 0
func set_motion(index: int) -> void:
 if not game: return
 motion_mode = index
 playing = index == 2
 Engine.time_scale = 1.0 if playing else 0.0
 get_tree().paused = not playing
 game.ball.freeze = not playing
 game.set_physics_process(playing)
 game.presentation.set_process(playing)
 game.controls.input_blocked = not playing
 if playing and endless and not game.touring: game.toggle_tour()
 if playing and fixture:
  # The canonical fixture disables native input recursively for screenshots.
  game.controls.set_process_unhandled_input(true)
  if game.ball.serve_pending and game.active.runtime.launch_tubes.is_empty(): game.auto_launch_time = 0.1
 motion_time = 0.0
 pan_clock = Time.get_ticks_usec()

func open_game() -> bool:
 busy = true
 panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 layer.hide()
 await release()
 if closing: get_tree().quit(); return false
 Engine.time_scale = 0.0
 get_tree().paused = false
 # A source checkout may have baked only one theme for an experimental Act.
 # Offer only available recipes. The portable contains all review variants.
 var available := []
 for i in Fixture.Registry.IDS.size():
  var id: String = Fixture.Registry.IDS[i]
  var exists := endless or ResourceLoader.exists(Fixture.Bake.path_for(ACTS[act_index], id))
  theme_choice.set_item_disabled(i, not exists)
  if exists: available.append(id)
 if not available.is_empty() and theme not in available: theme = available.front()
 theme_choice.select(Fixture.Registry.IDS.find(theme))
 var began := Time.get_ticks_usec()
 if endless:
  game = Endless.new()
  game.diagnostic_theme = theme
  game.next_theme = "chemical_plant" if theme != "chemical_plant" else "rooftop_run"
  get_tree().root.add_child(game)
  var deadline := Time.get_ticks_msec() + 180000
  while not game.started and game.library.error.is_empty() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
  if not game.started: return failed("Endless could not load disk recipes: " + game.library.error)
 else:
  fixture = Fixture.new()
  if not await fixture.open(get_tree(), ACTS[act_index], theme, output, "default", "production"): return failed(fixture.error)
  game = fixture.game
  fixture.session.archive_attempted = true
 if closing: busy = false; close(); return false
 open_ms = (Time.get_ticks_usec() - began) / 1000.0
 start_focus = game.ball.position
 if fixture: game.fps_label.hide()
 game.select_play_camera(game.PLAY_CAMERAS[camera_choice.selected])
 if study_card: place_study()
 set_focus(focus_choice.selected)
 blur.set_value_no_signal(game.presentation._key_light.shadow_blur)
 angle.set_value_no_signal(game.presentation._key_light.light_angular_distance)
 zoom.set_value_no_signal(game.presentation.camera_settings.zoom)
 set_motion(motion_mode)
 game.retro_filter.preset_changed.connect(keep_full_retro)
 keep_full_retro()
 set_rings(rings)
 set_mode(mode)
 busy = false
 layer.visible = capture_argument not in OS.get_cmdline_user_args()
 refresh()
 return true

func place_study() -> void:
 preload("penumbra_card.gd").place(game)
 game.presentation._key_light.shadow_blur = 1.25
 game.presentation._key_light.light_angular_distance = 4.0
 game.presentation.camera_settings.zoom = 2.1

func failed(message: String) -> bool:
 failures.append(message)
 push_error(message)
 busy = false
 layer.show()
 status.text = message
 if closing: get_tree().quit(1)
 return false

func refresh() -> void:
 if not game or not game.started: return
 var quality := Review.Options.quality()
 var palette := "Native range" if receivers.native_range else "Art palette"
 status.text = "%s   ·   Full Retro   ·   %s   ·   %s   ·   %d receivers   ·   %d atlas / %d cascades / %d%%   ·   F1 controls" % [str(game.active.plan.theme).capitalize(), MODES[mode], palette, receivers.stats().receivers, quality.directional_shadow_resolution, quality.directional_shadow_cascades, quality.scale_percent]

func _process(_delta: float) -> void:
 if busy or not game or not game.started: return
 receivers.sync(game)
 if layer.visible and not game.resident.is_empty():
  if displayed_span != resident_span():
   displayed_span = resident_span()
   refresh()
  blur.set_value_no_signal(game.presentation._key_light.shadow_blur)
  angle.set_value_no_signal(game.presentation._key_light.light_angular_distance)
 if not rings and endless and not game.resident.is_empty() and ring_span != resident_span(): set_rings(false)
 if motion_mode == 1:
  motion_time = (Time.get_ticks_usec() - pan_clock) / 1000000.0
  camera(start_focus + Vector2(sin(motion_time * 0.65) * 150, -90 * (1.0 - cos(motion_time * 0.42))))
  spin(motion_time * 2.0)

func _input(event: InputEvent) -> void:
 if not busy and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
  layer.visible = not layer.visible
  get_viewport().set_input_as_handled()

func release() -> void:
 receivers.clear()
 var next_rings := rings
 set_rings(true)
 rings = next_rings
 if fixture: await fixture.close()
 elif is_instance_valid(game):
  await game.prepare_to_close()
  game.free()
 fixture = null
 game = null

func close() -> void:
 closing = true
 if busy or evidence != null: return
 busy = true
 await release()
 get_tree().quit()
