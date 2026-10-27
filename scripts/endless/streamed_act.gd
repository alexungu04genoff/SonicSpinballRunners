extends RefCounted
## Builds one resident Act a single physics shape or visual node at a time.
const Mechanics = preload("res://scripts/authored_act/pinball_mechanics.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
var plan: Dictionary
var document: Resource
var runtime: Dictionary
var root := Node2D.new()
var visual := Node3D.new()
var nodes: Array[Node] = []
var prepared_nodes: Array[Node] = []
var recipe: RefCounted
var source: Dictionary
var shapes: Array
var ready := false
var phase := 0
var index := 0
var shape_index := 0
var current_body: StaticBody2D
var ring_data: Array[Dictionary] = []
var game: Node

func _notification(what: int) -> void:
 if what != NOTIFICATION_PREDELETE: return
 # A scene close can interrupt incremental attachment. Attached nodes belong
 # to the game tree; only the still-detached warm nodes need explicit cleanup.
 for node: Node in prepared_nodes:
  if is_instance_valid(node) and node.get_parent() == null: node.free()

func initialize(owner_game: Node, entry: Dictionary, library: Node) -> void:
 game = owner_game
 plan = entry
 document = library.documents[plan.id]
 source = library.runtimes[plan.id]
 shapes = library.shapes[plan.id]
 recipe = library.visuals[library.key(plan.theme, plan.id)]
 prepared_nodes = library.take_prepared_visuals(library.key(plan.theme, plan.id))
 root.name = "EndlessAct%d" % plan.sequence
 visual.name = root.name + "Visual"
 visual.position = TablePresentation.map_point(plan.offset)
 visual.visible = false
 visual.process_mode = Node.PROCESS_MODE_DISABLED
 root.process_mode = Node.PROCESS_MODE_DISABLED
 game.world.add_child(root)
 game.presentation.add_child(visual)
 var mechanics := Mechanics.new()
 mechanics.ball = game.ball
 mechanics.bind_ball_on_ready = false
 mechanics.banks = document.switch_banks.duplicate(true)
 root.add_child(mechanics)
 runtime = {"root": root, "mechanics": mechanics, "terrain": [], "objects": [], "flippers": [], "cell_size": document.cell_size}
 for trail: Dictionary in document.ring_trails:
  for point: Vector2 in preload("res://scripts/act_editor/ring_trails.gd").positions(trail):
   ring_data.append({"home": point + plan.offset, "position": point + plan.offset, "active": true})

func step() -> void:
 match phase:
  0: _terrain_step()
  1: _object_step()
  2:
   if index < recipe.records.size():
    if prepared_nodes.is_empty():
     recipe.instantiate_one(index, nodes, visual)
    else:
     var node: Node = prepared_nodes[index]
     var parent: int = recipe.records[index].parent
     (visual if parent < 0 else nodes[parent]).add_child(node)
     nodes.append(node)
    index += 1
   else:
    prepared_nodes.clear()
    recipe.bind_animations(nodes, game.presentation, runtime.mechanics)
    phase = 3
  3:
   # The complete root is already attached; activation has no recursive add_child.
   root.process_mode = Node.PROCESS_MODE_PAUSABLE
   visual.process_mode = Node.PROCESS_MODE_PAUSABLE
   visual.visible = true
   ready = true
   phase = 4

func _terrain_step() -> void:
 if index >= source.terrain.size():
  phase = 1
  index = 0
  return
 var item: Dictionary = source.terrain[index]
 if current_body == null:
  current_body = StaticBody2D.new()
  current_body.name = "Terrain%d" % index
  current_body.position = plan.offset
  current_body.collision_layer = 1
  current_body.collision_mask = 2
  current_body.physics_material_override = item.body.physics_material_override
  root.add_child(current_body)
  var descriptor := item.duplicate()
  descriptor.body = current_body
  descriptor.points = item.points.duplicate()
  for i in descriptor.points.size(): descriptor.points[i] += plan.offset
  runtime.terrain.append(descriptor)
  shape_index = 0
 elif shape_index < shapes[index].size():
  var shape := CollisionShape2D.new()
  shape.shape = shapes[index][shape_index].shape
  shape.transform = shapes[index][shape_index].transform
  current_body.add_child(shape)
  shape_index += 1
 else:
  current_body = null
  index += 1

func _object_step() -> void:
 if index >= source.objects.size():
  phase = 2
  index = 0
  return
 var item: Dictionary = source.objects[index]
 var descriptor := item.duplicate()
 descriptor.position = item.position + plan.offset
 var body: Node2D
 if item.has("mechanic"):
  body = item.body.duplicate() if item.type == "lane_barrier" else Node2D.new()
  var placement: Dictionary = document.gameplay_objects[index].duplicate(true)
  placement.object_id = descriptor.object_id
  placement.position = descriptor.position
  runtime.mechanics.add_object(placement, descriptor)
 elif item.type in ["left_flipper", "right_flipper"]:
  var flipper := PlaygroundFlipper.new()
  for property: String in ["length", "radius", "side", "authored_rest_angle"]: flipper.set(property, item.body.get(property))
  flipper.ball = game.ball
  flipper.controls = game.controls
  flipper.tuning = game.tuning
  runtime.flippers.append(flipper)
  body = flipper
 else:
  body = item.body.duplicate()
 body.position = descriptor.position
 body.rotation_degrees = item.rotation_degrees
 descriptor.body = body
 runtime.objects.append(descriptor)
 root.add_child(body)
 index += 1

func bounds() -> Rect2:
 return Rect2(plan.offset, document.terrain_bounds().size)

func spawn() -> Vector2:
 return Vector2(document.spawn_position) + Vector2(plan.offset)
