extends RefCounted
## Deterministic, disposable Acts for editor qualification; never production content.
const Act = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Decor = preload("res://scripts/act_editor/decor_slots.gd")
const Selection = preload("res://scripts/act_editor/editor_selection.gd")
const Composite = preload("res://scripts/act_editor/composite_terrain.gd")
const History = preload("res://scripts/act_editor/terrain_history.gd")
const Transform = preload("res://scripts/act_editor/selection_transform.gd")
const DIRECTORY := "res://test-results/editor-qualification-fixtures"
# Fixture indices stay stable when the user-facing palette inserts new types.
# Additional types are appended and still participate in every mixed-object check.
const HARDWARE_ORDER := ["round_bumper", "triangle_bumper", "left_flipper", "right_flipper",
 "one_way_gate", "switch_target", "wall_switch", "drop_target_bank", "slingshot", "spring",
 "spinner", "magnetic_field", "elevated_rail", "teleporter", "lane_barrier", "diverter",
 "dash_panel", "buzz_bomber"]

static func piece(at: Vector2i, shape := "rectangle_1x1") -> Dictionary:
 var definition := Shapes.get_definition(shape)
 return {"shape_id": shape, "base_size": definition.size, "anchor": at,
  "quarter_turns": 0, "flip_h": false, "flip_v": false}

static func base(title: String) -> Resource:
 var document := Act.new()
 document.title = title
 document.grid_size = Vector2i(32, 40)
 document.entry_start_x = 15
 document.entry_width = 2
 document.exit_start_x = 15
 document.exit_width = 2
 document.spawn_position = Vector2(800, 1750)
 document.goal_position = Vector2(800, 150)
 document.activation_y = 1800.0
 document.decor_seed = "editor-qualification-20261118"
 document.design_thesis = "Disposable editor qualification fixture."
 return document

static func all(document: Resource, markers := false) -> Dictionary:
 var selection := Selection.empty()
 for kind: String in Selection.COLLECTIONS:
  selection[kind] = range(document.get(Selection.COLLECTIONS[kind]).size())
 if markers: selection.markers = ["spawn", "goal", "activation"]
 return selection

static func dense() -> Resource:
 var document := base("Qualification A - dense mixed mechanics")
 document.placements = [piece(Vector2i(2, 3)), piece(Vector2i(27, 3)), piece(Vector2i(3, 29), "rectangle_1x3")]
 document.placements[2].quarter_turns = 1
 document.placements[2]["terrain_scale"] = 2.0 # Raised support for all three authored Decor slots.
 document.placements[0]["terrain_scale"] = 1.21
 document.placements[0]["fine_rotation_degrees"] = 17.25
 document.placements[0]["offset"] = Vector2(0.137, 0.29)
 for definition: Dictionary in Shapes.definitions():
  if not definition.closed:
   document.placements.append(piece(Vector2i(25, 27), definition.id))
   break
 var sources := [piece(Vector2i(6, 25)), piece(Vector2i(7, 25)), piece(Vector2i(6, 26))]
 var merged := Composite.merge(sources)
 assert(merged.error.is_empty(), merged.error)
 var smoothed := Composite.smooth(merged.placement, 0.35)
 assert(smoothed.error.is_empty(), smoothed.error)
 History.remember(smoothed.placement, sources)
 document.placements.append(smoothed.placement)
 var definitions: Array[Dictionary] = []
 for type: String in HARDWARE_ORDER: definitions.append(Objects.get_definition(type))
 for definition: Dictionary in Objects.definitions():
  if definition.id not in HARDWARE_ORDER: definitions.append(definition)
 for definition: Dictionary in definitions:
  var item := Objects.make_placement(definition.id)
  var index: int = document.gameplay_objects.size()
  item.object_id = "qualification_" + definition.id
  item.position = Vector2(250 + (index % 6) * 220, 400 + floori(index / 6.0) * 300)
  item.rotation_degrees += 23.0
  document.gameplay_objects.append(item)
 document.gameplay_objects[17].properties.patrol_left = -62.5
 document.gameplay_objects[17].properties.patrol_right = 117.25
 document.gameplay_objects[13].properties.exit_x = 83.25
 document.gameplay_objects[13].properties.exit_y = -61.5
 document.gameplay_objects[13].properties.exit_angle = 37.0
 for index in 3:
  var item := Objects.make_placement(["switch_target", "one_way_gate", "diverter"][index])
  item.object_id = "qualification_secondary_%d" % index
  item.position = Vector2(900 + index * 170, 1400)
  document.gameplay_objects.append(item)
 document.switch_banks = [
  {"bank_id": "qualification_bank_a", "label": "Two switches and two routes",
   "members": ["qualification_switch_target", "qualification_wall_switch"],
   "gates": ["qualification_one_way_gate"],
   "actions": [{"object_id": "qualification_diverter", "action": "toggle"}], "completion_bonus": 750},
  {"bank_id": "qualification_bank_b", "label": "Independent objective",
   "members": ["qualification_secondary_0"], "gates": ["qualification_secondary_1"],
   "actions": [{"object_id": "qualification_secondary_2", "action": "set_b"}], "completion_bonus": 250}]
 for index in 3:
  var slot := Decor.make_slot(Decor.TYPES[index])
  slot.slot_id = "qualification_decor_%d" % index
  slot.position = Vector2(175 + index * 115, 1500)
  slot.rotation_degrees = 13.5 + index * 20.0
  slot.scale = 0.73 + index * 0.2
  document.decor_slots.append(slot)
 document.ring_trails = [
  {"start": Vector2(700, 1550), "end": Vector2(700, 1550), "spacing": 25.0, "pattern_id": "qualification_single"},
  {"start": Vector2(350.25, 1200.5), "end": Vector2(590.75, 1257.25), "spacing": 29.5, "pattern_id": "qualification_line"},
  {"kind": "ellipse", "start": Vector2(750, 1100), "end": Vector2(930, 1190), "spacing": 43.0, "fill": false, "rotation_degrees": 31.25, "pattern_id": "qualification_outline"},
  {"kind": "ellipse", "start": Vector2(1000, 1150), "end": Vector2(1160, 1250), "spacing": 30.0, "fill": true, "rotation_degrees": -18.75, "pattern_id": "qualification_fill"}]
 var grouped := Selection.single("terrain", 0)
 grouped.gameplay = [5, 6, 4, 15]
 grouped.decor = [0]
 grouped.ring = [1]
 Selection.group(document, grouped)
 document.editor_groups[0].name = "Linked mixed assembly"
 document.editor_locks = Selection.single("terrain", 1)
 document.editor_hidden = Selection.single("decor", 2)
 return document

static func linked() -> Resource:
 var document := dense()
 document.title = "Qualification B - linked assembly"
 document.editor_locks = {}
 document.editor_hidden = {}
 return document

static func smoothed() -> Resource:
 var document := base("Qualification C - smoothed mirrored terrain")
 var sources := [piece(Vector2i(8, 12)), piece(Vector2i(9, 12)), piece(Vector2i(8, 13))]
 var merged := Composite.merge(sources)
 var result := Composite.smooth(merged.placement, 0.45)
 assert(result.error.is_empty(), result.error)
 History.remember(result.placement, sources)
 document.placements = [result.placement, piece(Vector2i(25, 30))]
 Transform.apply(document, Selection.single("terrain", 0), Vector2(500, 700), 1.3, 29.0)
 Transform.mirror(document, Selection.single("terrain", 0), Vector2(800, 1000), true)
 return document

static func terrain_points(item: Dictionary, cell := 50.0) -> PackedVector2Array:
 var points := Shapes.transformed_points(item)
 for index in points.size(): points[index] = (points[index] + Shapes.placement_position(item)) * cell
 return points

static func object_points(item: Dictionary, cell := 50.0) -> PackedVector2Array:
 var points := Objects.local_points(item, cell)
 for index in points.size(): points[index] = item.position + points[index].rotated(deg_to_rad(float(item.rotation_degrees)))
 return points
