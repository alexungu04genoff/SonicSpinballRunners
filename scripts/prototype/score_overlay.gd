extends Control
## Screen-space feedback observes accepted awards; it never changes score or physics.
const MAX_POPUPS := 12
const LIFETIME := 0.95
var game: Node
var popups: Array[Dictionary] = []
var displayed_multiplier := 1
var pulse := 0.0

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 process_mode = Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func add_award(details: Dictionary, at: Vector2) -> void:
 var total := int(details.get("total", 0))
 if total <= 0: return
 var kind := str(details.kind)
 # Nearby rapid pickups share one exact total instead of covering the ball.
 for popup: Dictionary in popups:
  if popup.kind == kind and popup.age < 0.12 and Vector2(popup.at).distance_to(at) < game.ball.radius * 5.0:
   popup.total += total
   return
 if popups.size() == MAX_POPUPS: popups.pop_front()
 var tint := Color("ffe07a") if kind == "ring" else Color("9eeaff")
 if kind in ["ring_rack", "switch_bank", "spinner_goal", "lane_set"]: tint = Color("a4ffad")
 popups.append({"at": at, "total": total, "kind": kind, "age": 0.0, "color": tint})

func _process(delta: float) -> void:
 var unavailable: bool = not game.started or game.closing or game.finished or game.drafting or is_instance_valid(game.transfer)
 visible = not unavailable and not get_tree().paused
 if unavailable: popups.clear()
 if not visible: return
 var current: int = game.scorecraft.multiplier
 if current > displayed_multiplier: pulse = 0.22
 displayed_multiplier = current
 pulse = maxf(0.0, pulse - delta)
 for i in range(popups.size() - 1, -1, -1):
  popups[i].age += delta
  if popups[i].age >= LIFETIME: popups.remove_at(i)
 queue_redraw()

func screen_point(at: Vector2, height: float) -> Vector2:
 var camera: Camera3D = game.presentation.camera
 var world := TablePresentation.map_point(at, height)
 if camera.is_position_behind(world): return Vector2.INF
 return camera.unproject_position(world) * get_viewport_rect().size / Vector2(game.view.size)

func _text(text: String, at: Vector2, font_size: int, tint: Color) -> void:
 if not at.is_finite(): return
 var font := ThemeDB.fallback_font
 var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
 at.x = clampf(at.x, 8.0, maxf(8.0, get_viewport_rect().size.x - extent.x - 8.0))
 at.y = clampf(at.y, extent.y, get_viewport_rect().size.y - 8.0)
 draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.02, 0.04, 0.07, tint.a * 0.9))
 draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)

func _draw() -> void:
 if not visible: return
 var at := screen_point(game.ball.position, game.presentation.ball_height())
 var tint := Color("dbe7ef") if displayed_multiplier == 1 else (Color("ffe07a") if displayed_multiplier == 2 else Color("a4ffad"))
 _text("×%d" % displayed_multiplier, at + Vector2(23, -18), 23 + int(pulse * 18.0), tint)
 for popup: Dictionary in popups:
  var point := screen_point(popup.at, game.ball.radius * TablePresentation.SCALE)
  if not get_viewport_rect().grow(40).has_point(point): continue
  var color: Color = popup.color
  color.a = 1.0 - smoothstep(0.35, LIFETIME, popup.age)
  _text("+%d" % popup.total, point + Vector2(-18, -42 - popup.age * 38), 21, color)
