extends RefCounted
## Top-down outlines of the preview theme's props, measured in authored cells.
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Presentation = preload("res://scripts/themes/themed_presentation.gd")

var skin: RefCounted
var _presentation: Node3D
var _outlines := {}

func set_theme(id: String) -> void:
 if _presentation == null: _presentation = Presentation.new()
 _presentation.set_theme_definition(Themes.create(id))
 skin = _presentation.decor_skin
 _outlines.clear()

func _notification(what: int) -> void:
 if what == NOTIFICATION_PREDELETE and is_instance_valid(_presentation): _presentation.free()

func polygon(seed: String, slot: Dictionary, origin: Vector2, cell: float) -> PackedVector2Array:
 if skin == null: set_theme(Themes.IDS[0])
 var variant: String = skin.resolve(seed, slot)
 if variant.is_empty(): return PackedVector2Array()
 if not _outlines.has(variant):
  var prop: Node3D = skin.factory.call(variant)
  var points := PackedVector2Array()
  _project_meshes(prop, Transform3D.IDENTITY, points)
  prop.free()
  var hull := Geometry2D.convex_hull(points)
  if hull.size() > 1: hull.resize(hull.size() - 1) # convex_hull repeats its first vertex.
  _outlines[variant] = hull
 var size := Vector2.ONE * cell * float(slot.get("scale", 1.0))
 if slot.get("mirror_x", false): size.x = -size.x
 var transform := Transform2D(deg_to_rad(float(slot.rotation_degrees)), size, 0.0, origin)
 return transform * PackedVector2Array(_outlines[variant])

func _project_meshes(node: Node3D, parent: Transform3D, points: PackedVector2Array) -> void:
 if not node.visible: return
 var transform := parent * node.transform
 if node is MeshInstance3D and node.mesh:
  for surface in node.mesh.get_surface_count():
   var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
   for vertex in vertices:
    var point := transform * vertex
    points.append(Vector2(point.x, point.z))
 for child in node.get_children():
  if child is Node3D: _project_meshes(child, transform, points)
