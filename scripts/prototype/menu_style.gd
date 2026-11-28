extends Control
## Screen art sits behind the interactive containers and never captures input.
const TITLE_SCENE = preload("res://assets/ui/runners/title_scene.png")
const TITLE = preload("res://assets/ui/runners/title.png")
const SKY = preload("res://assets/ui/runners/sky.png")
const PATTERN = preload("res://assets/ui/runners/result_pattern.png")
const CORNER = preload("res://assets/ui/runners/corner.png")
const FLAG = preload("res://assets/ui/runners/flag.png")
const GIFT = preload("res://assets/ui/runners/gift.png")
const TROPHY = preload("res://assets/ui/runners/trophy.png")
const SETTINGS = preload("res://assets/ui/runners/settings.png")
const PLAY = preload("res://assets/ui/runners/play.png")
const PAUSE = preload("res://assets/ui/runners/pause.png")
const FACES = preload("res://assets/ui/runners/faces.png")
const FACE_IDS := ["sonic", "tails", "knuckles", "amy", "shadow", "blaze", "rouge", "big", "cream"]
static var faces := {}
var screen := "loading"

static func face(character: String) -> Texture2D:
 var index := FACE_IDS.find(character)
 if index < 0: return null
 if not faces.has(character):
  var image := AtlasTexture.new()
  image.atlas = FACES
  image.region = Rect2(index * 96, 0, 96, 96)
  image.filter_clip = true
  faces[character] = image
 return faces[character]

static func icon(texture: Texture2D, dimensions: Vector2) -> TextureRect:
 var view := TextureRect.new()
 view.texture = texture
 view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 view.custom_minimum_size = dimensions
 view.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return view

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 resized.connect(queue_redraw)

func _draw() -> void:
 if screen == "paused":
  draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.06, 0.18, 0.66))
  return
 if screen == "menu":
  # Keep all three runners to the left of setup, including on a 4:3 canvas.
  draw_rect(Rect2(Vector2.ZERO, size), Color("123eae"))
  var art_scale := minf(size.x * 0.51 / 454.0, size.y / TITLE_SCENE.get_height())
  var extent := TITLE_SCENE.get_size() * art_scale
  var top := (size.y - extent.y) * 0.68
  draw_texture_rect(TITLE_SCENE, Rect2(Vector2(0, top), extent), false)
  var rail := PackedVector2Array([Vector2(size.x * 0.74, 0), Vector2(size.x, 0), size, Vector2(size.x * 0.51, size.y)])
  draw_colored_polygon(rail, Color("0a2d77"))
  draw_line(rail[0], rail[3], Color("288fff"), 8, true)
  var stamp := CORNER.get_size() * minf(1.5, size.y / 650.0)
  draw_texture_rect(CORNER, Rect2(size - stamp, stamp), false)
  var logo_width := minf(size.x * 0.40, 565.0)
  var logo_size := TITLE.get_size() * (logo_width / TITLE.get_width())
  draw_texture_rect(TITLE, Rect2(Vector2(size.x * 0.036, maxf(12.0, top - logo_size.y * 0.48)), logo_size), false)
  return
 draw_rect(Rect2(Vector2.ZERO, size), Color("1553a4"))
 var sky_size := maxf(size.x * 0.5, size.y * 0.65)
 var sky_rect := Rect2(Vector2.ZERO, Vector2.ONE * sky_size)
 var sky_tint := Color(0.68, 0.87, 1, 0.6)
 draw_texture_rect(SKY, sky_rect, false, sky_tint)
 draw_set_transform(Vector2(sky_size * 2, 0), 0.0, Vector2(-1, 1))
 draw_texture_rect(SKY, sky_rect, false, sky_tint)
 draw_set_transform(Vector2.ZERO)
 var stripe := PackedVector2Array([Vector2(0, size.y * 0.64), Vector2(size.x, size.y * 0.36), Vector2(size.x, size.y), Vector2(0, size.y)])
 draw_colored_polygon(stripe, Color("1049a4"))
 var pattern_height := size.x * PATTERN.get_height() / PATTERN.get_width()
 draw_texture_rect(PATTERN, Rect2(0, size.y - pattern_height, size.x, pattern_height), false, Color(1, 1, 1, 0.7))
 var decor_size := CORNER.get_size() * minf(1.35, size.y / 650)
 draw_texture_rect(CORNER, Rect2(size - decor_size, decor_size), false)
