extends SceneTree
const Contract = preload("res://scripts/display_framing.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func run() -> void:
 var original := [root.content_scale_mode,root.content_scale_aspect,root.content_scale_size]
 for mode: int in [Window.CONTENT_SCALE_MODE_DISABLED,Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,Window.CONTENT_SCALE_MODE_VIEWPORT]:
  root.content_scale_mode = mode
  root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
  root.content_scale_size = Vector2i(1280,900)
  var owner := Node.new()
  root.add_child(owner)
  var first := Contract.attach(owner)
  check(root.content_scale_size == Contract.REFERENCE,"Gameplay owns a fixed reference")
  check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,"Native Canvas Items HUD retained")
  check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP,"Complete reference fits without cropping")
  root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
  var second := Contract.attach(owner)
  check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP,"Nested gameplay entry reasserts contract")
  first.free()
  check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP,"First owner exit cannot restore early")
  second.free()
  check([root.content_scale_mode,root.content_scale_aspect,root.content_scale_size] == [mode,Window.CONTENT_SCALE_ASPECT_EXPAND,Vector2i(1280,900)],"Final owner restores exact caller settings")
  check(not root.has_meta(Contract.LEASE),"No stale lease")
  Contract.attach(owner)
  owner.free()
  check(root.content_scale_mode == mode,"Owner teardown restores editor/host mode")
 root.content_scale_mode = original[0]
 root.content_scale_aspect = original[1]
 root.content_scale_size = original[2]
 print("RESULT | Display contract lifecycle | %d checks | %d failures" % [checks,failures])
 quit(1 if failures else 0)
