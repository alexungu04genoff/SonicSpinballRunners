extends Node
## Scoped gameplay display contract. Does not own cameras, rendering quality or physics.
const REFERENCE := Vector2i(1600, 900)
const LEASE := &"ssr_gameplay_display_contract"
var window: Window

static func attach(owner: Node) -> Node:
 var guard := new()
 guard.name = "GameplayDisplayContract"
 guard.window = owner.get_window()
 owner.add_child(guard)
 return guard

func _ready() -> void:
 if window.has_meta(LEASE):
  window.get_meta(LEASE).users += 1
 else:
  window.set_meta(LEASE, {"users":1,"size":window.content_scale_size,
   "mode":window.content_scale_mode,"aspect":window.content_scale_aspect})
 # 1600x900 is the existing 16:9 logical extent of the 1280x900 EXPAND setup.
 # KEEP fits the complete gameplay canvas; Godot owns the bars and input transform.
 window.content_scale_size = REFERENCE
 window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func _exit_tree() -> void:
 if not is_instance_valid(window) or not window.has_meta(LEASE): return
 var state: Dictionary = window.get_meta(LEASE)
 state.users -= 1
 if state.users > 0: return
 window.content_scale_size = state.size
 window.content_scale_mode = state.mode
 window.content_scale_aspect = state.aspect
 window.remove_meta(LEASE)
