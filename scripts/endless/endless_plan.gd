extends RefCounted
## A reproducible, bounded stream of whole authored Acts. Never edits source data.
const PATHS := ["res://data/endless/second_simple.tres", "res://data/endless/third_complex.tres", "res://data/endless/first_try_smooth_decor.tres"]
const TITLES := ["Second Simple", "Third Complex", "First Try Smooth Decor"]
const Registry = preload("res://scripts/themes/theme_registry.gd")
var rng := RandomNumberGenerator.new()
var themes: Array = []
var previous_theme := ""
var previous_act := -1
var sequence := 0
var last_document: Resource
var last_offset := Vector2.ZERO

func _init(seed_value := 18) -> void:
 rng.seed = seed_value

func shuffled(values: Array) -> Array:
 var result := values.duplicate()
 for i in range(result.size() - 1, 0, -1):
  var j := rng.randi_range(0, i)
  var value: Variant = result[i]
  result[i] = result[j]
  result[j] = value
 return result

func next_zone(documents: Array) -> Array[Dictionary]:
 if themes.is_empty():
  themes = shuffled(Registry.IDS)
  if themes.back() == previous_theme:
   var swap: Variant = themes[0]
   themes[0] = themes[-1]
   themes[-1] = swap
 var theme: String = themes.pop_back()
 previous_theme = theme
 var order := shuffled(range(documents.size()))
 order.resize(3)
 if order[0] == previous_act:
  var swap: Variant = order[0]
  order[0] = order[1]
  order[1] = swap
 var result: Array[Dictionary] = []
 for id: int in order:
  var document: Resource = documents[id]
  var offset := Vector2.ZERO
  if last_document != null:
   offset = aligned_offset(last_document, last_offset, document)
  result.append({"sequence": sequence, "zone": sequence / 3, "act": sequence % 3,
   "id": id, "theme": theme, "offset": offset})
  last_document = document
  last_offset = offset
  previous_act = id
  sequence += 1
 return result

static func aligned_offset(previous: Resource, offset: Vector2, next: Resource) -> Vector2:
 return offset + Vector2(previous.exit_start_x * previous.cell_size - next.entry_start_x * next.cell_size, -next.terrain_bounds().size.y)

static func pool_error(documents: Array) -> String:
 if documents.size() < 3: return "Endless mode requires at least three Acts."
 for document: Resource in documents:
  if document.spawn_position == null or document.activation_y == null:
   return "Every endless Act needs a Spawn and Activation marker."
  if float(document.activation_y) >= document.terrain_bounds().end.y:
   return "Activation must be above the Entry, inside the Act."
  for next: Resource in documents:
   if not is_equal_approx(document.cell_size, next.cell_size) or document.exit_width != next.entry_width or document.exit_width <= 0:
    return "All endless Acts must have matching physical connector widths and cell sizes."
 return ""
