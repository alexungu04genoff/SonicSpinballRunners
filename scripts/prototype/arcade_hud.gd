extends Control
## Lightweight screen-space counters and a charge gauge; gameplay owns all values.
const RING = preload("res://assets/ui/hud/ring.png")
const SONIC = preload("res://assets/ui/hud/sonic.png")
const TAILS = preload("res://assets/ui/hud/tails.png")
var rings: Label
var lives: Label
var progress: Label
var message: Label
var ready_label: Label
var portrait: TextureRect
var charge := 0.0

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 _backing(Vector2(16, 16), Vector2(252, 66))
 var gauge_backing := _backing(Vector2.ZERO, Vector2(228, 60))
 gauge_backing.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 gauge_backing.offset_left = 16
 gauge_backing.offset_right = 244
 gauge_backing.offset_top = -76
 gauge_backing.offset_bottom = -16
 _icon(RING, Vector2(24, 24), Vector2(28, 28))
 rings = _label(Vector2(62, 18), 30)
 portrait = _icon(SONIC, Vector2(160, 26), Vector2(24, 24))
 lives = _label(Vector2(194, 23), 24)
 progress = _label(Vector2(24, 59), 14)
 progress.add_theme_color_override("font_color", Color("dbf7ff"))
 var name_label := _label(Vector2.ZERO, 14)
 name_label.text = "SPECIAL"
 name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 name_label.position = Vector2(24, size.y - 67)
 name_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
 name_label.offset_top = -67
 name_label.offset_bottom = -45
 ready_label = _label(Vector2.ZERO, 13)
 ready_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 ready_label.offset_left = 175
 ready_label.offset_top = -67
 ready_label.offset_bottom = -45
 ready_label.add_theme_color_override("font_color", Color("fff29a"))
 message = _label(Vector2(24, 81), 14)
 message.add_theme_color_override("font_color", Color("fff29a"))
 resized.connect(queue_redraw)

func _backing(at: Vector2, dimensions: Vector2) -> Panel:
 var panel := Panel.new()
 panel.position = at
 panel.size = dimensions
 panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 panel.show_behind_parent = true
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.025, 0.055, 0.09, 0.35)
 style.set_corner_radius_all(8)
 panel.add_theme_stylebox_override("panel", style)
 add_child(panel)
 return panel

func _label(at: Vector2, font_size: int) -> Label:
 var label := Label.new()
 label.position = at
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", Color.WHITE)
 label.add_theme_color_override("font_outline_color", Color("071730"))
 label.add_theme_constant_override("outline_size", 6 if font_size > 25 else 4)
 var font := SystemFont.new()
 font.font_names = PackedStringArray(["Arial"])
 font.font_weight = 800
 font.font_italic = true
 label.add_theme_font_override("font", font)
 add_child(label)
 return label

func _icon(texture: Texture2D, at: Vector2, dimensions: Vector2) -> TextureRect:
 var icon := TextureRect.new()
 icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
 icon.texture = texture
 icon.position = at
 icon.size = dimensions
 icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(icon)
 return icon

func update_values(character: String, balls: String, amount: float) -> void:
 portrait.texture = TAILS if character == "tails" else SONIC
 portrait.position.x = maxf(160, rings.position.x + rings.get_minimum_size().x + 24)
 lives.position.x = portrait.position.x + 34
 lives.text = "× " + balls
 var value := clampf(amount / 100.0, 0.0, 1.0)
 if not is_equal_approx(charge, value):
  charge = value
  queue_redraw()
 ready_label.text = "READY" if charge >= 1.0 else ""

func _draw() -> void:
 draw_set_transform(Vector2(24, size.y - 38), 0.0, Vector2(0.72, 0.65))
 var origin := Vector2.ZERO
 var outline := PackedVector2Array([origin + Vector2(-5, -5), origin + Vector2(285, -5), origin + Vector2(275, 24), origin + Vector2(-15, 24)])
 draw_colored_polygon(outline, Color("071730"))
 var frame := PackedVector2Array([origin, origin + Vector2(278, 0), origin + Vector2(271, 18), origin + Vector2(-7, 18)])
 draw_colored_polygon(frame, Color("e6f5ff"))
 var inside := PackedVector2Array([origin + Vector2(3, 3), origin + Vector2(273, 3), origin + Vector2(268, 15), origin + Vector2(-2, 15)])
 draw_colored_polygon(inside, Color("142a50"))
 if charge > 0.0:
  var width := 266.0 * charge
  var fill := PackedVector2Array([origin + Vector2(4, 4), origin + Vector2(4 + width, 4), origin + Vector2(width, 14), origin + Vector2(0, 14)])
  draw_colored_polygon(fill, Color("ffe15e") if charge >= 1.0 else Color("20c5f5"))
  draw_line(origin + Vector2(5, 5), origin + Vector2(3 + width, 5), Color("d8ffff"), 2.0, true)
 for index in range(1, 10):
  var x := 27.0 * index
  draw_line(origin + Vector2(x, 4), origin + Vector2(x - 4, 14), Color(0.03, 0.12, 0.26, 0.35), 1.0, true)
