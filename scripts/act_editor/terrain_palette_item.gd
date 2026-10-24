extends Button
## A small terrain preview that can also be dragged onto the authoring canvas.
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
var definition: Dictionary = {}

func configure(value: Dictionary) -> void:
	definition = value
	text = definition.label
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(242, 52)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "%s\n%s terrain. Click to stamp repeatedly, or drag onto the grid." % [definition.label, "Closed solid" if definition.closed else "Open wall"]
	set_meta("shape_id", definition.id)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("17283a") if state == "normal" else Color("29465b")
		style.set_corner_radius_all(6)
		style.content_margin_left = 66
		style.content_margin_right = 8
		add_theme_stylebox_override(state, style)
	queue_redraw()

func _draw() -> void:
	if definition.is_empty():
		return
	var frame := Vector2(definition.size)
	var scale_factor: float = 34.0 / maxf(frame.x, frame.y)
	var origin := Vector2(30, size.y * 0.5) - frame * scale_factor * 0.5
	var points := PackedVector2Array()
	for point: Vector2 in definition.points:
		points.append(origin + point * scale_factor)
	var color: Color = definition.color
	if definition.closed:
		draw_colored_polygon(points, Color(color, 0.3))
		points.append(points[0])
	draw_polyline(points, color, 2.0, true)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if definition.is_empty():
		return null
	var preview := Label.new()
	preview.text = "  " + definition.label + "  "
	preview.add_theme_color_override("font_color", definition.color)
	set_drag_preview(preview)
	return {"terrain_stamp": {"shape_id": definition.id, "base_size": definition.size,
		"anchor": Vector2i.ZERO, "quarter_turns": 0, "flip_h": false, "flip_v": false}}
