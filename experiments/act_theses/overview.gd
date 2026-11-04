extends SceneTree
## Comparable 2D overview rendered from the saved Acts, not a separate design mockup.
const NAMES := ["Orbit Garden", "Rail Exchange", "Spinner Falls", "Split Decision", "Lockbox"]
const FEATURES := ["Drop Targets + One-Way Gate", "Rail + Diverter + Switch control", "Spinner + Gate + Switch Bank", "Diverter + Dash Panels + Switches", "Drop Targets + Switch Bank + Gate"]
const Document = preload("res://scripts/act_editor/act_geometry.gd")
class Sheet:
 extends Node2D
 const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
 const Preview = preload("res://scripts/act_editor/gameplay_preview.gd")
 const Rings = preload("res://scripts/act_editor/ring_trails.gd")
 var acts: Array = []
 func label(at: Vector2, value: String, size := 18, color := Color("24352f")) -> void:
  draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
 func terrain(doc: Resource, origin: Vector2, scale_factor: float, miniature := false) -> void:
  for placement: Dictionary in doc.placements:
   var points := Shapes.transformed_points(placement)
   for i in points.size(): points[i] = origin + (points[i] + Shapes.placement_position(placement)) * float(doc.cell_size) * scale_factor
   draw_colored_polygon(points, Color("537362") if miniature else Color("a7c09d"))
   points.append(points[0])
   draw_polyline(points, Color("45624e"), 1.0, true)
 func _draw() -> void:
  draw_rect(Rect2(0, 0, 1800, 1100), Color("edf0e8"))
  label(Vector2(24, 37), "SSR / FIVE TABLE THESES", 30)
  label(Vector2(24, 63), "Saved Act geometry at one scale • faceted terrain • experimental, outside the production pool", 17)
  for index in acts.size():
   var doc: Resource = acts[index]
   var corner := Vector2(20 + (index % 3) * 590, 85 + floori(index / 3.0) * 490)
   draw_rect(Rect2(corner, Vector2(570, 470)), Color("fafbf6"))
   label(corner + Vector2(16, 30), NAMES[index], 25)
   label(corner + Vector2(16, 57), FEATURES[index], 16)
   var size: Vector2 = Vector2(doc.grid_size) * float(doc.cell_size)
   var origin := corner + Vector2((570.0 - size.x * 0.5) * 0.5, 92)
   terrain(doc, origin, 0.5)
   for trail: Dictionary in doc.ring_trails:
    for point: Vector2 in Rings.positions(trail): draw_arc(origin + point * 0.5, 2.4, 0, TAU, 12, Color("c58c12"), 1.2, true)
   for object: Dictionary in doc.gameplay_objects:
    Preview.draw_object(self, object, origin + Vector2(object.position) * 0.5, 0.5, float(doc.cell_size), false, false, false)
   draw_arc(origin + doc.goal_center() * 0.5, 12.5, 0, TAU, 24, Color("13985a"), 2, true)
   label(origin + doc.goal_center() * 0.5 + Vector2(15, 4), "G", 13, Color("13733e"))
   label(origin + Vector2(doc.spawn_position) * 0.5 + Vector2(-4, -5), "S", 13)
   terrain(doc, corner + Vector2(470, 8), 0.095, true)
   label(corner + Vector2(16, 451), "%d × %d px  /  terrain-only inset at top right" % [size.x, size.y], 14, Color("607267"))
  var legend := Vector2(1210, 620)
  label(legend, "READ THE SHOTS", 27)
  label(legend + Vector2(0, 43), "Gold circles: Rings    G: Goal    S: Spawn", 19)
  label(legend + Vector2(0, 80), "Cyan crossing: elevated Rail, above terrain", 18)
  label(legend + Vector2(0, 117), "Arrows: authored launch / allowed direction", 18)
  label(legend + Vector2(0, 165), "Baseline: flippers, Rings, Buzz, bumpers,", 18)
  label(legend + Vector2(0, 193), "Springs and Slingshots support each thesis.", 18)
  label(legend + Vector2(0, 245), "Playability and feel remain manual questions.", 18)
  label(legend + Vector2(0, 278), "No production geometry or physics changed.", 18)
func _initialize() -> void: run.call_deferred()
func run() -> void:
 root.size = Vector2i(900, 600)
 var canvas := SubViewport.new()
 canvas.size = Vector2i(1800, 1100)
 canvas.disable_3d = true
 canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(canvas)
 var sheet := Sheet.new()
 for title: String in NAMES:
  var loaded := Document.load_document("res://data/acts/Experiments/" + title + ".tres")
  if loaded.document == null: push_error(str(loaded)); quit(1); return
  sheet.acts.append(loaded.document)
 canvas.add_child(sheet)
 for i in 8: await process_frame
 await RenderingServer.frame_post_draw
 var result := canvas.get_texture().get_image().save_png("res://docs/ACT_THESIS_OVERVIEW.png")
 print("OVERVIEW | ", result)
 quit(0 if result == OK else 1)
