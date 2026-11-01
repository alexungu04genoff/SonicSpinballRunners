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
 panel.set_value("ranges/green/hue", 0.23)
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
 game.free()
 print("ATMOSPHERE_PICKER | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
