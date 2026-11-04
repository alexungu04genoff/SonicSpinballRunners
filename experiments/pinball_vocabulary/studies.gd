extends SceneTree
## Rebuild only these disposable studies with -- --write. Production libraries are never modified.
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Shapes = preload("res://scripts/act_editor/terrain_shapes.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const DIRECTORY := "res://experiments/pinball_vocabulary/"
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var failed := false
 for sides: int in [96, 16]:
  var path := DIRECTORY + "study_%d.tres" % sides
  if "--write" in OS.get_cmdline_user_args():
   var source := Document.load_document("res://data/acts/routing_mechanics_sandbox.tres")
   var act: Resource = source.document
   act.title = "Pinball Toys / Terrain Study / %d sides" % sides
   act.gameplay_objects = act.gameplay_objects.filter(func(item: Dictionary): return item.type in ["left_flipper", "right_flipper", "spring"] and item.object_id != "upper")
   act.switch_banks = []
   for spec: Array in [[Vector2(180, 810), 30.0], [Vector2(420, 810), -30.0]]:
    var sling := Objects.make_placement("slingshot")
    sling.object_id = "study_sling_" + str(act.gameplay_objects.size())
    sling.position = spec[0]
    sling.rotation_degrees = spec[1]
    act.gameplay_objects.append(sling)
   var bank := Objects.bank_from_span(Objects.make_placement("drop_target_bank"), Vector2(236, 160), Vector2(364, 160))
   bank.object_id = "study_drop_bank"
   bank.properties.reset_delay = 5.0
   act.gameplay_objects.append(bank)
   for spec: Array in [["circle_3x3", Vector2i(2, 5)], ["oval_2x3", Vector2i(7, 5)], ["bump_3x2", Vector2i(2, 10)], ["outer_corner_3x3", Vector2i(7, 10)]]:
    var definition := Shapes.get_definition(spec[0])
    var outline := PackedVector2Array()
    var stride := int(96 / sides)
    var source_points: PackedVector2Array = definition.points
    var arc_points := source_points.size() - (1 if str(spec[0]).begins_with("outer_corner") else 0)
    for i in range(0, arc_points, stride): outline.append(source_points[i])
    if str(spec[0]).begins_with("outer_corner"): outline.append(source_points[-1])
    act.placements.append({"shape_id": "composite", "base_size": definition.size, "anchor": spec[1], "quarter_turns": 0, "flip_h": false, "flip_v": false, "composite_version": 1, "smoothing_strength": 0.0, "outline": outline})
   var error: Error = act.save_document(path)
   if error != OK:
    push_error(str(act.validation_errors()))
    failed = true
    continue
  var loaded := Document.load_document(path)
  if loaded.document == null:
   push_error(str(loaded))
   failed = true
   continue
  var ball := PlaygroundBall.new()
  var tuning := PhysicsTuning.new()
  var controls := PlaygroundInput.new()
  var runtime := Compiler.compile(loaded.document, tuning, controls, ball)
  if not runtime.error.is_empty():
   push_error(runtime.error)
   failed = true
  else:
   for terrain: Dictionary in runtime.terrain:
    if terrain.collision is CollisionPolygon2D and terrain.points != terrain.collision.polygon: failed = true
   print("PASS | ", sides, "-side study loads; visual source and collision polygons match")
   runtime.root.free()
  ball.free()
  controls.free()
  tuning.free()
 quit(1 if failed else 0)


