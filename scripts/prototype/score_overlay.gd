extends Control
## Screen-space feedback observes accepted awards; it never changes score or physics.
const MAX_POPUPS := 12
const LIFETIME := 0.95
const FONT_SIZE := 23
const FONT_SCALE := 1.2
const COMBO_COLORS := [Color.WHITE, Color("40e87d"), Color("ffd433"), Color("ff424a")]
var game: Node
var popups: Array[Dictionary] = []
var displayed_multiplier := 1
var pulse := 0.0
var table_labels: Array[WeakRef] = []

func track_label(label: Label3D) -> void:
 if label.has_meta("score_overlay"): return
 label.set_meta("score_overlay", true)
 label.hide()
 table_labels.append(weakref(label))

func _ready() -> void:
 hide()
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
 for i in range(table_labels.size() - 1, -1, -1):
  if table_labels[i].get_ref() == null: table_labels.remove_at(i)
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
 var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) * FONT_SCALE
 at.x = clampf(at.x, 8.0, maxf(8.0, get_viewport_rect().size.x - extent.x - 8.0))
 at.y = clampf(at.y, extent.y, get_viewport_rect().size.y - 8.0)
 draw_set_transform(at, 0.0, Vector2.ONE * FONT_SCALE)
 draw_string_outline(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.02, 0.04, 0.07, tint.a * 0.9))
 draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
 draw_set_transform(Vector2.ZERO)

func _draw_goal(goal: Node3D) -> void:
 var point := screen_point(goal.center, goal.position.y)
 if get_viewport_rect().has_point(point):
  var caption := "GOAL" if goal.unlocked else "GOAL · %d / %d" % [game.act_score, game.act_score_target]
  _text(caption, point + Vector2(-35, -22), FONT_SIZE, Color("ffd447") if goal.unlocked else Color("a6abb3"))
 elif goal.unlocked:
  var direction := point - size * 0.5
  if not point.is_finite():
   # Projecting behind a perspective camera flips left and right.
   var local: Vector3 = game.presentation.camera.get_camera_transform().affine_inverse() * goal.global_position
   direction = Vector2(local.x, -local.y) * size / Vector2(game.view.size)
  _draw_goal_pointer(Vector2.DOWN if direction.is_zero_approx() else direction.normalized())

func _draw_goal_pointer(direction: Vector2) -> void:
 var half_size := Vector2(45, 17)
 var room := size * 0.5 - half_size - Vector2(14, 14)
 var distance := minf(room.x / maxf(absf(direction.x), 0.001), room.y / maxf(absf(direction.y), 0.001))
 var center := size * 0.5 + direction * distance
 # Keep the pointer clear of the score plate, Special meter and pause button.
 if center.x - half_size.x < game.player_hud.plate_width:
  center.y = clampf(center.y, 150, size.y - 105)
 elif center.x + half_size.x > size.x - 78:
  center.y = maxf(center.y, 98)
 var badge := Rect2(center - half_size, half_size * 2)
 var gold := Color("ffdf47")
 draw_rect(badge, Color("102e66ed"))
 draw_rect(badge, gold, false, 2)
 var arrow := center + Vector2(-26, 0)
 var wing := direction.orthogonal() * 7.0
 draw_colored_polygon(PackedVector2Array([arrow + direction * 10.0, arrow - direction * 6.0 + wing, arrow - direction * 3.0, arrow - direction * 6.0 - wing]), gold)
 draw_string(get_theme_font(&"font", &"RaceTitle"), center + Vector2(-12, 6), "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw() -> void:
 if not visible: return
 var at := screen_point(game.ball.position, game.presentation.ball_height())
 var tint: Color = COMBO_COLORS[clampi(displayed_multiplier - 1, 0, 3)]
 if displayed_multiplier >= 2:
  var marker := at + Vector2(23, -18)
  var pose: MeshInstance3D = game.combo_celebration.character_pose
  if is_instance_valid(pose) and pose.is_visible_in_tree():
   var edge := pose.to_global(Vector3.RIGHT * pose.mesh.get_aabb().end.x)
   var projected: Vector2 = game.presentation.camera.unproject_position(edge)
   marker.x = maxf(marker.x, projected.x * get_viewport_rect().size.x / game.view.size.x + 8)
  _text("×%d" % displayed_multiplier, marker, FONT_SIZE, tint)
 if game.active != null:
  _draw_goal(game.active.runtime.goal_ring)
 for reference: WeakRef in table_labels:
  var label: Label3D = reference.get_ref()
  if label == null or label.text.is_empty() or game.presentation.camera.is_position_behind(label.global_position): continue
  var point: Vector2 = game.presentation.camera.unproject_position(label.global_position) * get_viewport_rect().size / Vector2(game.view.size)
  if get_viewport_rect().has_point(point): _text(label.text, point, FONT_SIZE, label.modulate)
 for popup: Dictionary in popups:
  var point := screen_point(popup.at, game.ball.radius * TablePresentation.SCALE)
  if not get_viewport_rect().grow(40).has_point(point): continue
  var color: Color = popup.color
  color.a = 1.0 - smoothstep(0.35, LIFETIME, popup.age)
  var caption := "LOOP! +%d" if popup.kind == "loop" else "+%d"
  _text(caption % popup.total, point + Vector2(-18, -42 - popup.age * 38), 21, color)
