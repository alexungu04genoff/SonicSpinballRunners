extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)
func frames(count: int) -> void:
 for index in count: await process_frame
func run() -> void:
 root.size = Vector2i(1280, 900)
 var game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 root.add_child(game)
 paused = true
 await frames(5)
 var panel = game.lighting_controls
 panel.variants.context.selected = "draft"
 panel.reset_values()
 panel.tabs.current_tab = 4
 var picker = panel.color_range_picker
 var retro: Array = game.retro_filter.selected_effects.duplicate()
 game.retro_filter.set_effects([])
 await frames(4)
 await RenderingServer.frame_post_draw
 var picture: Image = game.view.get_texture().get_image()
 var pixel := Vector2i(-1, -1)
 for y in range(int(picture.get_height() * 0.3), int(picture.get_height() * 0.75), 3):
  for x in range(int(picture.get_width() * 0.3), int(picture.get_width() * 0.7), 3):
   var color := Color(0, 0, 0, 0)
   for dy in range(-2, 3):
    for dx in range(-2, 3): color += picture.get_pixel(x + dx, y + dy)
   color /= 25.0
   if color.s > 0.3 and color.h > 0.28 and color.h < 0.36:
    pixel = Vector2i(x, y)
    break
  if pixel.x >= 0: break
 check(pixel.x >= 0, "Find a green scene sample")
 if pixel.x < 0:
  game.free()
  quit(1)
  return
 var displayed: Rect2 = picker.displayed_rect(game.view_container.get_global_rect(), picture.get_size())
 var point := displayed.position + (Vector2(pixel) + Vector2(0.5, 0.5)) / Vector2(picture.get_size()) * displayed.size
 game.retro_filter.set_effects(retro)
 panel.set_value("ranges/enabled", true)
 panel.set_value("ranges/green/hue", 0.55)
 panel.set_value("ranges/green/brightness", 2.5)
 await frames(4)
 var ball: int = game.ball.get_instance_id()
 var ball_position: Vector2 = game.ball.position
 var camera: Transform3D = game.presentation.camera.transform
 picker.arm.button_pressed = true
 for index in 3:
  picker.mode.select(index)
  picker.start = point
  picker.latest = point
  check(await picker.pick_at(point), "Scene pick succeeds")
  print("PICKER_SAMPLE | ", index, " | ", picker.selected, " | ", picker.swatch.color, " | point=", point)
  check(picker.selected == "green", "Already shifted green retains its original range with Retro enabled")
  var key: String = "ranges/green/" + ["hue", "saturation", "brightness"][index]
  var original: float = panel.values[key]
  picker.dragging = true
  var motion := InputEventMouseMotion.new()
  motion.position = point + Vector2(40, 0)
  motion.shift_pressed = true
  picker._input(motion)
  check(float(panel.values[key]) > original, "Scene drag adjusts selected " + key)
  var release := InputEventMouseButton.new()
  release.button_index = MOUSE_BUTTON_LEFT
  release.position = motion.position
  picker._input(release)
  check(not picker.dragging, "Release ends drag")
 check(paused and game.ball.get_instance_id() == ball and game.ball.position == ball_position and game.presentation.camera.transform == camera, "Picker preserves pause, ball and camera")
 check(game.retro_filter.selected_effects == retro and game.retro_filter.effect_layer.visible, "Picker restores Retro")
 for entry: Dictionary in panel.emission.cloud_lights:
  check(entry.material.get_shader_parameter("fake_light_direction") == entry.base, "Picker preserves authored cloud lighting")
 var escape := InputEventKey.new()
 escape.keycode = KEY_ESCAPE
 escape.pressed = true
 picker._input(escape)
 check(not picker.arm.button_pressed, "Escape exits picking")
 await frames(3)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/atmosphere-controls/picker.png")
 await check_text_entry(game, panel)
 game.free()
 print("ATMOSPHERE_PICKER | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func press_key(code: int, unicode := 0) -> void:
 var event := InputEventKey.new()
 event.keycode = code
 event.physical_keycode = code
 event.unicode = unicode
 event.pressed = true
 Input.parse_input_event(event)
 event = event.duplicate()
 event.pressed = false
 Input.parse_input_event(event)
 await frames(2)

func type_text(text: String) -> void:
 for character: String in text: await press_key(character.to_upper().unicode_at(0), character.unicode_at(0))

func check_text_entry(game: Node, panel: CanvasLayer) -> void:
 panel.tabs.current_tab = 0
 panel.variants.create(false)
 await frames(3)
 var follow: bool = game.presentation.camera_follow_enabled
 var ball: int = game.ball.get_instance_id()
 await type_text("Gold VIP")
 check(panel.variants.title.text == "Gold VIP" and panel.variants.selected_record().name == "Gold VIP", "Variant name receives every letter: text=%s saved=%s" % [panel.variants.title.text, panel.variants.selected_record().name])
 check(game.presentation.camera_follow_enabled == follow and game.ball.get_instance_id() == ball, "Typing O does not trigger overview or gameplay shortcuts")
 panel.variants.title.release_focus()
 for fullscreen in [false, true]:
  if fullscreen: game.toggle_fullscreen()
  panel.tabs.current_tab = 1
  await frames(3)
  var number: SpinBox = panel.widgets["env/tonemap_exposure"]
  var edit := number.get_line_edit()
  var click := InputEventMouseButton.new()
  click.position = edit.get_global_rect().get_center()
  click.button_index = MOUSE_BUTTON_LEFT
  click.pressed = true
  root.push_input(click, true)
  click = click.duplicate()
  click.pressed = false
  root.push_input(click, true)
  await frames(3)
  check(edit.has_focus(), "Click focuses numeric field in fullscreen=%s" % fullscreen)
  edit.select_all()
  var typed := "2.73" if fullscreen else "1.23"
  await type_text(typed)
  await press_key(KEY_ENTER)
  await frames(3)
  check(is_equal_approx(panel.values["env/tonemap_exposure"], float(typed)), "Typed number applies on Enter in fullscreen=%s" % fullscreen)
  check(edit.text == typed, "Numeric display has two decimals")
 if game.player_view: game.toggle_fullscreen()
 panel.tabs.current_tab = 5
 panel.set_value("env/fog_density", 0.0065)
 await frames(3)
 var density: SpinBox = panel.widgets["env/fog_density"]
 check(density.get_line_edit().text == "0.01" and is_equal_approx(panel.values["env/fog_density"], 0.0065), "Two-decimal display preserves fine fog precision")
