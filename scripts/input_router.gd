class_name PlaygroundInput
extends Node
## Gameplay reads this adapter. A future touch UI can supply the same fields.
signal launch_requested
signal reset_requested
signal pause_requested
signal debug_requested
signal special_requested
var steering: float = 0.0
var raw_steering: float = 0.0
var steering_block_reason: String = ""
var left_held: bool = false
var right_held: bool = false
var input_blocked: bool = false
var virtual_enabled: bool = false
var virtual_steering: float = 0.0
var virtual_left: bool = false
var virtual_right: bool = false

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 _key_action("left_flipper", KEY_Q, JOY_BUTTON_LEFT_SHOULDER)
 _key_action("right_flipper", KEY_E, JOY_BUTTON_RIGHT_SHOULDER)
 _key_action("steer_left", KEY_LEFT)
 _key_action("steer_right", KEY_RIGHT)
 _key_action("special", KEY_SPACE, JOY_BUTTON_A)
 _key_action("pause", KEY_ESCAPE, JOY_BUTTON_START)
 _key_action("launch", KEY_ENTER, JOY_BUTTON_X)
 _key_action("reset_ball", KEY_R, JOY_BUTTON_BACK)
 _key_action("toggle_debug", KEY_F1)
 for direction: int in [-1, 1]:
  var event := InputEventJoypadMotion.new()
  event.axis = JOY_AXIS_LEFT_X
  event.axis_value = float(direction)
  InputMap.action_add_event("steer_left" if direction < 0 else "steer_right", event)

func _key_action(action: String, key: Key, button: int = -1) -> void:
 if InputMap.has_action(action):
  return
 InputMap.add_action(action, 0.18)
 var event := InputEventKey.new()
 event.physical_keycode = key
 InputMap.action_add_event(action, event)
 if button >= 0:
  var joy := InputEventJoypadButton.new()
  joy.button_index = button as JoyButton
  InputMap.action_add_event(action, joy)

func _physics_process(_delta: float) -> void:
 # Record input before deadzone/UI suppression so telemetry can explain a zero command.
 raw_steering = clampf(virtual_steering, -1.0, 1.0) if virtual_enabled else clampf(Input.get_action_raw_strength("steer_right") - Input.get_action_raw_strength("steer_left"), -1.0, 1.0)
 steering_block_reason = "Paused" if get_tree().paused else ("Editing a numeric field" if input_blocked else "")
 if get_tree().paused or input_blocked:
  steering = 0.0
  left_held = false
  right_held = false
  return
 steering = raw_steering if virtual_enabled else Input.get_axis("steer_left", "steer_right")
 left_held = virtual_left if virtual_enabled else Input.is_action_pressed("left_flipper")
 right_held = virtual_right if virtual_enabled else Input.is_action_pressed("right_flipper")

func _unhandled_input(event: InputEvent) -> void:
 if event.is_action_pressed("pause"):
  pause_requested.emit()
 elif event.is_action_pressed("toggle_debug"):
  debug_requested.emit()
 elif not input_blocked and not get_tree().paused:
  if event.is_action_pressed("launch"):
   launch_requested.emit()
  elif event.is_action_pressed("reset_ball"):
   reset_requested.emit()
  elif event.is_action_pressed("special"):
   special_requested.emit()
