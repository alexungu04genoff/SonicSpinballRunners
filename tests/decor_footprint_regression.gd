extends SceneTree
## Compare the editor outline with the transformed vertices from Play Act's factory.
const Footprints = preload("res://scripts/act_editor/decor_footprints.gd")
const Slots = preload("res://scripts/act_editor/decor_slots.gd")
const CELL := 73.0
var checks := 0
var failures := 0

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 var previews := Footprints.new()
 var terrain := [{"closed": true, "points": PackedVector2Array([Vector2.ZERO, Vector2(400, 0), Vector2(400, 400), Vector2(0, 400)])}]
 for id: String in Footprints.Themes.IDS:
  previews.set_theme(id)
  var runtime := Footprints.Presentation.new()
  runtime.set_theme_definition(Footprints.Themes.create(id))
  runtime.terrain_root = Node3D.new()
  runtime.add_child(runtime.terrain_root)
  root.add_child(runtime)
  var seen := {}
  for category: String in Slots.TYPES:
   var slot := Slots.make_slot(category)
   slot.position = Vector2(127, 175)
   slot.variant_mode = "fixed"
   for hint: String in Slots.HINTS:
    slot.placement_hint = hint
    var pool: Array = runtime.decor_skin.variants_for(slot)
    for index in pool.size():
     if seen.has(pool[index]): continue
     seen[pool[index]] = true
     slot.variant_index = index
     slot.scale = [0.125, 1.0, 1.75, 8.0][checks % 4]
     slot.rotation_degrees = [0.0, 90.0, 37.125][checks % 3]
     slot.mirror_x = checks % 2 == 0
     runtime._build_authored_decor({"decor_slots": [slot], "decor_seed": "test", "terrain": terrain}, CELL)
     var outline := previews.polygon("test", slot, slot.position, CELL)
     var model := projected_vertices(runtime.decor_root)
     checks += 1
     if not same_extents(outline, model):
      failures += 1
      push_error("Editor footprint differs from Play Act: %s/%s" % [id, pool[index]])
     runtime.decor_root.free()
  runtime.free()
 print("RESULT | Decor footprints | %d variants | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func projected_vertices(parent: Node3D) -> PackedVector2Array:
 var points := PackedVector2Array()
 for part: MeshInstance3D in parent.find_children("*", "MeshInstance3D", true, false):
  if not part.is_visible_in_tree() or not part.mesh: continue
  for surface in part.mesh.get_surface_count():
   var arrays := part.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var indices: Variant = arrays[Mesh.ARRAY_INDEX]
   for index in (indices if indices != null and not indices.is_empty() else range(vertices.size())):
    points.append(TablePresentation.unmap_point(part.to_global(vertices[index])))
 return Geometry2D.convex_hull(points)

func same_extents(outline: PackedVector2Array, model: PackedVector2Array) -> bool:
 if outline.size() < 3 or model.size() < 3: return false
 for i in 16:
  var axis := Vector2.RIGHT.rotated(i * TAU / 16.0)
  var expected := -INF
  var shown := -INF
  for point in model: expected = maxf(expected, point.dot(axis))
  for point in outline: shown = maxf(shown, point.dot(axis))
  if absf(expected - shown) > 0.01:
   print("Extent along ", axis, " in Act pixels: runtime ", expected, ", editor ", shown)
   return false
 return true
