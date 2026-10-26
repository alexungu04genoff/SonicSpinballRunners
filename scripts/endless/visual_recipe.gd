extends Resource
## Small one-node scenes share meshes/materials. Live construction never instantiates
## an entire Act or recursively duplicates a large scene in a single frame.
const MechanicsVisual = preload("res://scripts/authored_act/mechanics_presentation.gd")
const Flicky = preload("res://scripts/decor/island_flicky.gd")
const WarmManifest = preload("res://scripts/endless/warm_manifest.gd")
@export var records: Array[Dictionary] = []
var indices := {}
@export var animations: Array[Dictionary] = []
@export var flippers: Array[int] = []
@export var retracted: Array[int] = []
@export var rings: Array[int] = []
@export var bumpers := {}
@export var batch_stats := {}
@export var warm_manifest_version := 0
@export var retirement_dependencies: Array[Resource] = []
var error := ""

func has_warm_manifest() -> bool:
 if warm_manifest_version != WarmManifest.VERSION: return false
 for record: Dictionary in records:
  if not record.get("warm_signatures") is PackedStringArray: return false
  if not record.get("warm_visible") is bool or not record.get("warm_cull_margin") is float: return false
 return true

func capture(node: Node, parent := -1, recursive := true) -> void:
 var index := records.size()
 indices[node.get_instance_id()] = index
 var copy: Node = ClassDB.instantiate(node.get_class())
 for property: Dictionary in node.get_property_list():
  var key: String = property.name
  if int(property.usage) & PROPERTY_USAGE_STORAGE == 0 or key in ["script", "owner", "unique_name_in_owner", "scene_file_path"]: continue
  copy.set(key, node.get(key))
 var record := {"parent": parent}
 if node is MultiMeshInstance3D and node.multimesh != null:
  var instance_data := _capture_instances(node.multimesh)
  if not instance_data.is_empty():
   record.merge(instance_data)
   copy.multimesh = null
 var scene := PackedScene.new()
 scene.pack(copy)
 copy.free()
 record.scene = scene
 records.append(record)
 if node.get_script() == MechanicsVisual:
  animations.append({"index": index, "script": MechanicsVisual,
   "values": {"spinners": node.spinners, "fields": node.fields, "gimmicks": node.gimmicks}})
 elif node.get_script() == Flicky:
  animations.append({"index": index, "script": Flicky,
   "values": {"phase": node.phase, "pose": node.pose, "head": node.head, "wings": node.wings}})
 else:
  assert(node.get_script() == null, "A new animated decor script needs an explicit streaming binding.")
 if recursive:
  for child: Node in node.get_children(): capture(child, index)

func _capture_instances(multimesh: MultiMesh) -> Dictionary:
 if multimesh.instance_count == 0: return {}
 if multimesh.transform_format != MultiMesh.TRANSFORM_3D or multimesh.use_colors or multimesh.use_custom_data:
  error = "This MultiMesh needs an explicit color/custom-data bake adapter."
  return {}
 var transforms: Array = multimesh.get_meta("offline_transforms", [])
 if DisplayServer.get_name() == "headless" and transforms.size() != multimesh.instance_count:
  error = "A headless MultiMesh has no saved CPU transforms. Use the theme instance-transform helper before baking."
  return {}
 var buffer := PackedFloat32Array()
 var bounds := AABB()
 for index in multimesh.instance_count:
  var transform: Transform3D = transforms[index] if not transforms.is_empty() else multimesh.get_instance_transform(index)
  buffer.append_array(preload("res://scripts/endless/static_batches.gd")._transform_buffer(transform))
  var item: AABB = transform * multimesh.mesh.get_aabb()
  bounds = item if index == 0 else bounds.merge(item)
 if multimesh.custom_aabb != AABB(): bounds = multimesh.custom_aabb
 return {"instance_mesh": multimesh.mesh, "instance_buffer": buffer, "instance_bounds": bounds}

func finish(presenter: TablePresentation = null) -> void:
 for animation: Dictionary in animations: animation.values = _encode(animation.values)
 if presenter == null: return
 for node: Node in presenter.flipper_visuals: flippers.append(indices[node.get_instance_id()])
 for node: Node in presenter.flipper_retracted_visuals: retracted.append(indices[node.get_instance_id()])
 for node: Node in presenter.ring_visuals: rings.append(indices[node.get_instance_id()])
 for id: int in presenter.bumper_visuals: bumpers[id] = indices[presenter.bumper_visuals[id].get_instance_id()]

func _encode(value: Variant) -> Variant:
 if value is Node: return {"$node": indices[value.get_instance_id()]}
 if value is Array:
  var result: Array = []
  for item: Variant in value: result.append(_encode(item))
  return result
 if value is Dictionary:
  if value.has("object_id") and value.has("properties") and value.has("cooldown"):
   return {"$mechanic": value.object_id}
  var result := {}
  for key: Variant in value: result[key] = _encode(value[key])
  return result
 return value

func instantiate_one(index: int, nodes: Array[Node], root: Node) -> void:
 var record := records[index]
 var node: Node = record.scene.instantiate()
 if record.has("instance_buffer"):
  var multimesh := MultiMesh.new()
  multimesh.transform_format = MultiMesh.TRANSFORM_3D
  multimesh.mesh = record.instance_mesh
  multimesh.instance_count = record.instance_buffer.size() / 12
  multimesh.custom_aabb = record.instance_bounds
  multimesh.buffer = record.instance_buffer
  node.multimesh = multimesh
 # The staging root is disabled until ready. Native particles must inherit its
 # eventual activation instead of remaining permanently disabled themselves.
 node.process_mode = Node.PROCESS_MODE_INHERIT
 (root if record.parent < 0 else nodes[record.parent]).add_child(node)
 nodes.append(node)

func bind_animations(nodes: Array[Node], presenter: TablePresentation, mechanics: Node = null) -> void:
 for animation: Dictionary in animations:
  var node: Node = nodes[animation.index]
  node.set_script(animation.script)
  var values: Dictionary = _decode(animation.values, nodes, mechanics)
  for key: String in values:
   if values[key] is Array and node.get(key) is Array:
    node.get(key).assign(values[key])
   else:
    node.set(key, values[key])
  if animation.script == MechanicsVisual: node.table = presenter
  node.process_mode = Node.PROCESS_MODE_PAUSABLE
  node.set_process(true)

func _decode(value: Variant, nodes: Array[Node], mechanics: Node) -> Variant:
 if value is Dictionary:
  if value.has("$node"): return nodes[value["$node"]]
  if value.has("$mechanic"): return mechanics.by_id[value["$mechanic"]]
  var result := {}
  for key: Variant in value: result[key] = _decode(value[key], nodes, mechanics)
  return result
 if value is Array:
  var result: Array = []
  for item: Variant in value: result.append(_decode(item, nodes, mechanics))
  return result
 return value
