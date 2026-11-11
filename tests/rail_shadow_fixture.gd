extends RefCounted
const Visual = preload("res://scripts/authored_act/mechanics_presentation.gd")
const Path = preload("res://scripts/authored_act/rail_path.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
const Shadows = preload("res://scripts/authored_act/gimmick_shadows.gd")

class Presenter extends "res://scripts/themes/themed_presentation.gd":
 # Match offline construction/detail without waiting on the streaming scheduler.
 func stream_checkpoint(_force := false) -> void: pass

static func item(control: PackedVector2Array, height := 65.0, width := 55.0) -> Dictionary:
 var result := Objects.make_placement("elevated_rail")
 result.object_id = "shadow_fixture"
 result.properties = Objects.properties(result)
 result.properties.height = height
 result.properties.width = width
 result.path = Path.build(control)
 return result

static func build(parent: Node, theme: String, control: PackedVector2Array, height := 65.0, width := 55.0) -> Dictionary:
 var p := Presenter.new()
 p.theme_definition = Registry.create(theme)
 parent.add_child(p)
 p.set_process(false)
 var visual := Visual.new()
 p.add_child(visual)
 visual.set_process(false)
 visual.table = p
 var rail := item(control, height, width)
 var enabled := Shadows.enabled
 Shadows.enabled = false
 await visual._rail(rail)
 Shadows.enabled = enabled
 return {"presenter":p,"visual":visual,"rail":visual.get_child(0),"item":rail}

static func combine(rail: Node3D) -> int:
 return Shadows.combine(rail,true,[rail.get_node("EntryArrow")],2.0)

static func inventory(node: Node, result: Dictionary = {}) -> Dictionary:
 if result.is_empty(): result.merge({"casters":0,"surfaces":0,"triangles":0,"custom":0})
 if node is MeshInstance3D and node.mesh != null and node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
  result.casters += 1
  result.surfaces += node.mesh.get_surface_count()
  for i in node.mesh.get_surface_count():
   var arrays: Array = node.mesh.surface_get_arrays(i)
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
   result.triangles += (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
   if node.get_active_material(i) is ShaderMaterial: result.custom += 1
 for child: Node in node.get_children(): inventory(child,result)
 return result
