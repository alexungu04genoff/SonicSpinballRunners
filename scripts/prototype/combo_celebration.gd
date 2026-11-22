extends Control
## One reusable cut-in. The hit ordinal and points both come from Scorecraft.
const SonicPose = preload("res://scripts/prototype/sonic_combo_pose.gd")
const POSES := {
 "sonic": preload("res://assets/ui/combo_poses/sonic.svg"),
 "tails": preload("res://assets/ui/combo_poses/tails.svg"),
 "knuckles": preload("res://assets/ui/combo_poses/knuckles.svg"),
 "shadow": preload("res://assets/ui/combo_poses/shadow.svg"),
}
const INK := {
 "sonic": Color("#69dcff"), "tails": Color("#ffcd62"),
 "knuckles": Color("#ff9778"), "shadow": Color("#ff8498"),
}
const CARD := Vector2(316, 116)
const MARGIN := Vector2(18, 18)
const ENTER := 0.12
const HOLD := 0.62
const EXIT := 0.16
const DURATION := ENTER + HOLD + EXIT
var character := ""
var milestone := 0
var points := 0
var age := 0.0
var _title_font := SystemFont.new()
var sonic_pose: SonicPose

func install_sonic_pose(presenter: Node3D) -> void:
 sonic_pose = SonicPose.new()
 sonic_pose.name = "SonicComboPose"
 sonic_pose.prepare(presenter, POSES.sonic)
 presenter.add_child(sonic_pose)

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 _title_font.font_names = PackedStringArray(["Arial"])
 _title_font.font_weight = 900
 _title_font.font_italic = true
 size = CARD
 dismiss()

func consider(id: String, hits: int, award: int) -> void:
 if hits <= milestone or not POSES.has(id): return
 if hits != 5 and hits != 8 and (hits < 10 or hits % 5 != 0): return
 character = id
 milestone = hits
 points = award
 if not visible:
  age = 0.0
  show()
  set_process(true)
  _place()
 queue_redraw()

func reset_combo() -> void:
 milestone = 0
 dismiss()

func dismiss() -> void:
 if is_instance_valid(sonic_pose): sonic_pose.restore_ball()
 hide()
 set_process(false)

func _notification(what: int) -> void:
 if what == NOTIFICATION_PAUSED: dismiss()

func _process(delta: float) -> void:
 age += delta
 if age >= DURATION:
  dismiss()
  return
 _place()

func _place() -> void:
 # Match the HUD footprint in both the native canvas and the 480-line composite.
 var logical := get_window().get_visible_rect().size
 scale = get_viewport_rect().size / logical
 var reveal := smoothstep(0.0, ENTER, age) * (1.0 - smoothstep(ENTER + HOLD, DURATION, age))
 if character == "sonic" and is_instance_valid(sonic_pose):
  sonic_pose.show_blend(reveal)
 position = (logical - CARD - MARGIN + Vector2(36.0 * (1.0 - reveal), 0)) * scale
 modulate.a = reveal

func _draw() -> void:
 if character.is_empty(): return
 var accent: Color = INK[character]
 if character == "sonic" and is_instance_valid(sonic_pose):
  # The pose is on the table. Leave a compact score receipt in the HUD.
  draw_colored_polygon(PackedVector2Array([Vector2(156, 49), Vector2(316, 49),
   Vector2(316, 100), Vector2(302, 116), Vector2(142, 116)]), Color("#101d34"))
  draw_rect(Rect2(156, 49, 160, 3), accent)
  _draw_fitted(_title_font, Vector2(162, 80), "HIT COMBO ×%d" % milestone, 19, Color.WHITE)
  var receipt := "SONIC"
  if points > 0: receipt += "   +%d PTS" % points
  _draw_fitted(ThemeDB.fallback_font, Vector2(157, 104), receipt, 16, accent)
  return
 draw_colored_polygon(PackedVector2Array([Vector2(21, 8), Vector2(316, 8), Vector2(316, 96),
  Vector2(297, 116), Vector2(0, 116)]), Color("#080f24"))
 draw_colored_polygon(PackedVector2Array([Vector2(22, 7), Vector2(315, 7), Vector2(315, 94),
  Vector2(296, 112), Vector2(1, 112)]), Color("#172642"))
 draw_colored_polygon(PackedVector2Array([Vector2(22, 7), Vector2(138, 7), Vector2(101, 112),
  Vector2(1, 112)]), accent.darkened(0.62))
 draw_line(Vector2(102, 110), Vector2(138, 9), accent, 2, true)
 draw_rect(Rect2(141, 7, 174, 3), accent)
 draw_texture_rect(POSES[character], Rect2(3, -6, 127, 127), false)
 draw_string(_title_font, Vector2(143, 36), character.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, accent)
 _draw_fitted(_title_font, Vector2(129, 72), "COMBO ×%d" % milestone, 29, Color.WHITE)
 var feedback := "%d HITS" % milestone
 if points > 0: feedback += "    +%d PTS" % points
 _draw_fitted(ThemeDB.fallback_font, Vector2(122, 97), feedback, 16, Color("#e2edf9"))

func _draw_fitted(font: Font, at: Vector2, text: String, pixels: int, tint: Color) -> void:
 var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
 var fit := mini(pixels, floori(pixels * (CARD.x - at.x - 12.0) / width))
 draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit, tint)
