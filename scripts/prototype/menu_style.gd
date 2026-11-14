extends Control
## Static graphic shapes keep menus inexpensive and readable at any resolution.

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 resized.connect(queue_redraw)

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO, size), Color("09245b"))
 draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x * 0.76, 0), Vector2(size.x * 0.38, size.y), Vector2(0, size.y)]), Color("113f88"))
 draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.55, 0), Vector2(size.x * 0.73, 0), Vector2(size.x * 0.35, size.y), Vector2(size.x * 0.17, size.y)]), Color("1551a3"))
 var center := Vector2(size.x * 0.84, size.y * 0.48)
 var radius := size.y * 0.39
 draw_arc(center, radius, 0, TAU, 96, Color(0.3, 0.7, 1.0, 0.12), 30, true)
 draw_arc(center, radius + 27, -1.8, 2.1, 64, Color(0.4, 0.8, 1.0, 0.2), 3, true)
 draw_arc(center, radius - 25, -2.1, 1.7, 64, Color(1.0, 0.8, 0.15, 0.3), 4, true)
 for row in 5:
  for column in 9:
   if (row + column) % 2 == 0:
    draw_rect(Rect2(size.x - 240 + column * 28, size.y - 140 + row * 28, 28, 28), Color(0.2, 0.6, 1.0, 0.08))

static func make_theme() -> Theme:
 var result := Theme.new()
 var font := SystemFont.new()
 font.font_names = PackedStringArray(["Arial"])
 font.font_weight = 700
 result.default_font = font
 result.default_font_size = 18
 for kind: String in ["Button", "OptionButton"]:
  for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
   var box := StyleBoxFlat.new()
   box.bg_color = Color("174981") if state == "normal" else Color("227ac2")
   if state == "disabled": box.bg_color = Color("17345e")
   if state == "focus": box.bg_color = Color.TRANSPARENT
   box.border_color = Color("ffdb49") if state == "focus" else Color("398ed0")
   box.set_border_width_all(2 if state == "focus" else 1)
   box.set_corner_radius_all(3)
   box.content_margin_left = 18
   box.content_margin_right = 18
   box.content_margin_top = 10
   box.content_margin_bottom = 10
   result.set_stylebox(state, kind, box)
  result.set_color("font_color", kind, Color.WHITE)
  result.set_color("font_hover_color", kind, Color.WHITE)
 result.set_type_variation("PrimaryButton", "Button")
 for state: String in ["normal", "hover", "pressed"]:
  var box := StyleBoxFlat.new()
  box.bg_color = Color("ffda3d") if state == "normal" else Color("fff3a1")
  box.set_content_margin_all(14)
  box.set_corner_radius_all(3)
  result.set_stylebox(state, "PrimaryButton", box)
  result.set_color("font_" + ("color" if state == "normal" else state + "_color"), "PrimaryButton", Color("082758"))
 result.set_font_size("font_size", "PrimaryButton", 25)
 return result
