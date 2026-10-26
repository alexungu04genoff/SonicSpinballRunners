extends Button
## Collisionless gameplay preview and drag payload for the Act authoring palette.
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Preview = preload("res://scripts/act_editor/gameplay_preview.gd")
## Palette icons fit their box independently of canvas scale.
const ICON_CELL_SIZE := 50.0
var definition: Dictionary = {}

func configure(value: Dictionary) -> void:
	definition = value
	text = definition.label
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(220, 36)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "%s\nGameplay object. Click to place repeatedly, or drag onto the canvas. Hold Alt for free position." % definition.label
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("17283a") if state == "normal" else Color("29465b")
		style.set_corner_radius_all(6)
		style.content_margin_left = 44
		style.content_margin_right = 6
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		add_theme_stylebox_override(state, style)
	queue_redraw()

func _draw() -> void:
	if definition.is_empty():
		return
	var placement: Dictionary = Objects.make_placement(definition.id)
	var points: PackedVector2Array = Preview.rotated_points(placement, ICON_CELL_SIZE)
	if points.is_empty():
		return
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	var scale_factor := 28.0 / maxf(bounds.size.x, bounds.size.y)
	var anchor := Vector2(21, size.y * 0.5) - bounds.get_center() * scale_factor
	Preview.draw_object(self, placement, anchor, scale_factor, ICON_CELL_SIZE, false, false, false)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if definition.is_empty():
		return null
	var preview := Label.new()
	preview.text = "  " + definition.label + "  "
	preview.add_theme_color_override("font_color", definition.color)
	set_drag_preview(preview)
	return {"gameplay_stamp": Objects.make_placement(definition.id)}
