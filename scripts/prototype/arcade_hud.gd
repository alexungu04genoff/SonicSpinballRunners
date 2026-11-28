extends Control
## Display-only counters use the character and Ring sprites from the Runners HUD.
const Art = preload("res://scripts/prototype/menu_style.gd")
const RING = preload("res://assets/ui/runners/ring.png")
const GAUGE = preload("res://assets/ui/runners/gauge.png")
const INK := Color("0b2350")
var rings: Label
var lives: Label
var progress: Label
var message: Label
var ready_label: Label
var score: Label
var portrait: TextureRect
var portrait_letter: Label
var charge := 0.0
var target_progress := 0.0
var special_name: Label
var plate_width := 250.0

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 _icon(RING, Vector2(24, 21), Vector2(33, 33))
 rings = _label(Vector2(64, 17), 27)
 portrait = _icon(Art.face("sonic"), Vector2(154, 16), Vector2(41, 41))
 portrait_letter = _label(Vector2(163, 21), 20)
 lives = _label(Vector2(198, 20), 23)
 var caption := _label(Vector2(26, 54), 14)
 caption.text = "SCORE"
 caption.add_theme_color_override("font_color", Color("ffdf47"))
 score = _label(Vector2(91, 48), 22)
 progress = _label(Vector2(25, 83), 14)
 progress.add_theme_color_override("font_color", Color("ddf4ff"))
 message = _label(Vector2(18, 111), 16)
 message.add_theme_color_override("font_color", Color("ffe564"))
 special_name = _label(Vector2.ZERO, 16)
 _bottom_label(special_name, 22, -81)
 ready_label = _label(Vector2.ZERO, 16)
 _bottom_label(ready_label, 148, -81)
 ready_label.add_theme_color_override("font_color", Color("ffe564"))
 resized.connect(queue_redraw)

func _bottom_label(label: Label, left: float, top: float) -> void:
 label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 label.offset_left = left
 label.offset_top = top
 label.offset_bottom = top + 24

func _label(at: Vector2, font_size: int) -> Label:
 var label := Label.new()
 label.position = at
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 label.theme_type_variation = &"RaceTitle"
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_constant_override("outline_size", 4)
 add_child(label)
 return label

func _icon(texture: Texture2D, at: Vector2, dimensions: Vector2) -> TextureRect:
 var image := Art.icon(texture, dimensions)
 image.position = at
 add_child(image)
 return image

func update_values(character: String, balls: String, amount: float, target_fraction: float) -> void:
 var definition: CharacterDefinition = CharacterSpecials.CHARACTERS[character]
 portrait.texture = Art.face(character)
 portrait_letter.text = "" if portrait.texture else definition.display_name.left(1)
 portrait_letter.add_theme_color_override("font_color", definition.color)
 portrait.position.x = maxf(154, rings.position.x + rings.get_minimum_size().x + 12)
 portrait_letter.position.x = portrait.position.x + 9
 lives.position.x = portrait.position.x + 44
 lives.text = "× " + balls
 var content_right := maxf(lives.position.x + lives.get_minimum_size().x, progress.position.x + progress.get_minimum_size().x)
 content_right = maxf(content_right, score.position.x + score.get_minimum_size().x)
 var width := maxf(250, content_right + 18)
 var value := clampf(amount / definition.meter_capacity, 0.0, 1.0)
 if not is_equal_approx(charge, value) or not is_equal_approx(width, plate_width) or not is_equal_approx(target_progress, target_fraction):
  charge = value
  plate_width = width
  target_progress = target_fraction
  queue_redraw()
 special_name.text = definition.type_action.action_name.to_upper()
 ready_label.offset_left = special_name.offset_left + special_name.get_minimum_size().x + 12
 ready_label.text = "READY · SPACE / A" if amount >= definition.meter_cost else ""

func _draw() -> void:
 # Short angled plates leave the middle of the table free for play.
 draw_colored_polygon(PackedVector2Array([Vector2(15, 15), Vector2(plate_width, 15), Vector2(plate_width - 8, 78), Vector2(15, 78)]), Color("102e66ed"))
 draw_rect(Rect2(15, 12, plate_width - 15, 4), Color("ffdd39"))
 draw_rect(Rect2(15, 78, plate_width - 23, 26), INK)
 var track := Rect2(15, 104, plate_width - 23, 4)
 draw_rect(track, Color("385a82"))
 if target_progress > 0.0:
  draw_rect(Rect2(track.position, Vector2(track.size.x * target_progress, track.size.y)), Color("ffdf47"))
 var gauge := Rect2(14, size.y - 55, 205, 41)
 draw_texture_rect(GAUGE, gauge, false)
 if charge > 0.0:
  var start := gauge.position + Vector2(30, 27)
  var end := start + Vector2(149 * charge, 0)
  draw_line(start, end, Color("ffcb29") if charge >= 1.0 else Color("21dfff"), 5, true)
