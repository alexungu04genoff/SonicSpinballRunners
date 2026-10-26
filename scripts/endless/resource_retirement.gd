extends RefCounted
## Retains evicted dependency graphs until their owners can be released separately.
## A cache must call enqueue() successfully before erasing its last reference.
## No Resource, Array or Dictionary supplied by the caller is modified.
const MAX_PENDING := 4
var _jobs: Array[Dictionary] = []
var peak_pending := 0
var peak_pins := 0
var completed := 0
var last_steps := 0
var last_releases := 0

func enqueue(value: Variant, dependencies: Array) -> bool:
 if _jobs.size() >= MAX_PENDING: return false
 # Borrow the baked manifest in O(1). Its references are copied into private
 # pins across slices before either the owner or borrowed array is released.
 _jobs.append({"baked": true, "owner": value, "dependencies": dependencies,
  "cursor": dependencies.size() - 1, "pins": [], "stage": "pin", "scanning": true})
 peak_pending = maxi(peak_pending, _jobs.size())
 return true

func enqueue_unbaked(value: Variant) -> bool:
 # Explicit authoring fallback only. Baked play must use enqueue() so material
 # property inspection and SceneState traversal stay in the offline pipeline.
 if _jobs.size() >= MAX_PENDING: return false
 var job := {"baked": false, "stack": [], "pins": [], "seen": {}, "scanning": true}
 _visit(job, value)
 if job.stack.is_empty(): return true
 _jobs.append(job)
 peak_pending = maxi(peak_pending, _jobs.size())
 return true

static func dependencies(value: Variant) -> Array[Resource]:
 # Bake-only traversal. Reverse DFS completion orders each owner before its
 # dependencies, including descendants shared across branches of the graph.
 var collector := new()
 var job := {"baked": false, "stack": [], "pins": [], "seen": {}, "scanning": true}
 collector._visit(job, value)
 while job.scanning: collector._advance(job)
 var result: Array[Resource] = []
 for index in range(job.pins.size() - 1, -1, -1):
  var resource: Variant = job.pins[index]
  if resource is Resource and not is_same(resource, value): result.append(resource)
 return result

func pending_count() -> int:
 return _jobs.size()

func step(max_steps := 64, budget_usec := 500) -> int:
 last_steps = 0
 last_releases = 0
 if max_steps <= 0 or budget_usec <= 0: return 0
 var deadline := Time.get_ticks_usec() + budget_usec
 while not _jobs.is_empty() and last_steps < max_steps and Time.get_ticks_usec() < deadline:
  _advance(_jobs[0])
  last_steps += 1
  if not _jobs[0].scanning and _jobs[0].pins.is_empty():
   _jobs.pop_front()
   completed += 1
 return last_steps

func _visit(job: Dictionary, value: Variant) -> void:
 if value is Resource or value is SceneState:
  var id: int = value.get_instance_id()
  if job.seen.has(id): return
  job.seen[id] = true
 elif value is Array or value is Dictionary:
  # Shared containers may be visited twice; checking ancestors prevents cycles
  # without hashing whole recipes or retaining an unbounded global identity cache.
  for ancestor: Dictionary in job.stack:
   if is_same(ancestor.value, value): return
 else:
  return
 job.stack.append({"value": value, "cursor": -1, "properties": [], "keys": [], "node": 0})

func _advance(job: Dictionary) -> void:
 if job.baked:
  _advance_baked(job)
  return
 if not job.scanning:
  # Reverse DFS completion order releases owners before their descendants,
  # including a descendant shared by owners at different graph depths.
  job.pins.pop_back()
  last_releases += 1
  return
 if job.stack.is_empty():
  job.scanning = false
  job.seen.clear()
  return
 var frame: Dictionary = job.stack.back()
 var value: Variant = frame.value
 if frame.cursor == -1:
  frame.cursor = 0
  if value is PackedScene:
   _visit(job, value.get_state())
   return
  if value is ArrayMesh or value is SceneState or value is Array: return
  if value is Dictionary:
   frame.keys = value.keys()
   return
  # Images/textures store pixel data, not dependent Resources. Reading image
  # properties can cause an expensive GPU readback, so do not inspect them.
  if value is Image or value is ImageTexture or value is CompressedTexture2D or value is Shader or value is Script:
   _finish(job)
   return
  frame.properties = value.get_property_list()
  return
 if value is PackedScene:
  _finish(job)
 elif value is SceneState:
  _advance_scene(job, frame, value)
 elif value is ArrayMesh:
  if frame.cursor < value.get_surface_count():
   var material: Material = value.surface_get_material(frame.cursor)
   frame.cursor += 1
   _visit(job, material)
  elif frame.cursor == value.get_surface_count():
   frame.cursor += 1
   _visit(job, value.shadow_mesh)
  else:
   _finish(job)
 elif value is Array:
  if frame.cursor >= value.size():
   _finish(job)
  else:
   var child: Variant = value[frame.cursor]
   frame.cursor += 1
   _visit(job, child)
 elif value is Dictionary:
  if frame.cursor >= frame.keys.size() * 2:
   _finish(job)
  else:
   var key: Variant = frame.keys[frame.cursor / 2]
   var child: Variant = key if frame.cursor % 2 == 0 else value.get(key)
   frame.cursor += 1
   _visit(job, child)
 else:
  if frame.cursor >= frame.properties.size():
   _finish(job)
  else:
   var property: Dictionary = frame.properties[frame.cursor]
   frame.cursor += 1
   if property.name != "retirement_dependencies" and int(property.usage) & PROPERTY_USAGE_STORAGE and int(property.type) in [TYPE_OBJECT, TYPE_ARRAY, TYPE_DICTIONARY]:
    _visit(job, value.get(property.name))

func _advance_baked(job: Dictionary) -> void:
 match job.stage:
  "pin":
   if job.cursor >= 0:
    job.pins.append(job.dependencies[job.cursor])
    job.cursor -= 1
    peak_pins = maxi(peak_pins, job.pins.size())
   else:
    job.stage = "owner"
  "owner":
   job.owner = null
   last_releases += 1
   job.stage = "manifest"
  "manifest":
   job.dependencies = []
   job.stage = "release"
   job.scanning = false
  "release":
   job.pins.pop_back()
   last_releases += 1

func _advance_scene(job: Dictionary, frame: Dictionary, state: SceneState) -> void:
 if frame.node >= state.get_node_count():
  if frame.cursor >= 0:
   frame.cursor = -2
   _visit(job, state.get_base_scene_state())
  else:
   _finish(job)
  return
 if frame.cursor < state.get_node_property_count(frame.node):
  var child: Variant = state.get_node_property_value(frame.node, frame.cursor)
  frame.cursor += 1
  _visit(job, child)
 else:
  var instance := state.get_node_instance(frame.node)
  frame.node += 1
  frame.cursor = 0
  _visit(job, instance)

func _finish(job: Dictionary) -> void:
 var frame: Dictionary = job.stack.pop_back()
 job.pins.append(frame.value)
 peak_pins = maxi(peak_pins, job.pins.size())
