extends RefCounted
## Explicit diagnostic-only silhouettes. Never loaded by normal gameplay.
## Source instances remain in their own world; only copied collisionless shadow
## geometry is submitted to the gameplay world. Static transforms are copied once.
const Audit = preload("res://scripts/diagnostics/render_audit.gd")
const THEMES := ["rooftop_run", "ice_cap"]
const CELL_SIZE := 3.0
const MAX_GROUPS := 6
var roots: Array[Node3D] = []
var geometry: Array[MeshInstance3D] = []
var receipt: Array[Dictionary] = []
var approach := "source"

func clear() -> void:
 for root: Node3D in roots:
  if is_instance_valid(root): root.free()
 roots.clear()
 geometry.clear()
 receipt.clear()

func build(game: Node, method := "source", ceiling := false) -> void:
 clear()
 receipt.clear()
 approach = method
 var began := Time.get_ticks_usec()
 for act: RefCounted in game.resident:
  if act.plan.theme not in THEMES: continue
  if not ceiling and act != game.active: continue
  var source: Node3D = act.background_visual
  if not is_instance_valid(source): continue
  var groups := {}
  var candidates := 0
  var accepted := 0
  var nodes: Array[Node] = [source]
  while not nodes.is_empty():
   var node: Node = nodes.pop_back()
   nodes.append_array(node.get_children())
   var mesh := Audit.mesh_of(node)
   if mesh == null or mesh is ImmediateMesh: continue
   var material: Material = node.material_override
   if material == null: material = mesh.surface_get_material(0)
   if Audit.material_state(material).transparent: continue
   var transforms: Array[Transform3D] = []
   if node is MultiMeshInstance3D:
    for index in node.multimesh.instance_count: transforms.append(node.global_transform * node.multimesh.get_instance_transform(index))
   else: transforms.append(node.global_transform)
   for transform: Transform3D in transforms:
    candidates += 1
    var bounds := transform * mesh.get_aabb()
    var role := _semantic_role(act.plan.theme, bounds, mesh, material)
    if role.is_empty() and not ceiling: continue
    # Global transforms are directly comparable because follow() copies the
    # foreground camera transform/projection into the independent background.
    # local scenery: backdrop(T(offset-1200)) * local(T(act)-T(backdrop))
    # * source transforms = T(act) * source transforms. No guessed offset.
    var center := bounds.get_center()
    var cell := Vector2i(floori(center.x / CELL_SIZE), floori(center.z / CELL_SIZE))
    if not groups.has(cell): groups[cell] = []
    groups[cell].append({"mesh": mesh, "transform": transform, "bounds": bounds, "role": role if not role.is_empty() else "all_near_ceiling", "source": str(node.get_path())})
    accepted += 1
  var root := Node3D.new()
  root.name = "GroundingTrialAct%d" % act.plan.sequence
  root.set_meta("grounding_zone", act.plan.zone)
  root.set_meta("grounding_sequence", act.plan.sequence)
  root.set_meta("grounding_ceiling", ceiling)
  game.presentation.add_child(root)
  # Native ownership handles Act/Zone retirement; no transform polling.
  source.tree_exiting.connect(root.queue_free, CONNECT_ONE_SHOT)
  roots.append(root)
  var group_count := 0
  for cell: Vector2i in groups:
   if group_count >= MAX_GROUPS and not ceiling: break
   var surface := SurfaceTool.new()
   surface.begin(Mesh.PRIMITIVE_TRIANGLES)
   var parts: Array[Dictionary] = []
   for part: Dictionary in groups[cell]:
    var transform: Transform3D = root.global_transform.affine_inverse() * part.transform
    if method == "hull":
     # Per-component boxes preserve arch openings; never one box around a ruin.
     var box := BoxMesh.new()
     box.size = part.mesh.get_aabb().size
     var centered := transform * Transform3D(Basis.IDENTITY, part.mesh.get_aabb().get_center())
     surface.append_from(box, 0, centered)
    else:
     for index in part.mesh.get_surface_count(): surface.append_from(part.mesh, index, transform)
    parts.append({"semantic_role": part.role, "source": part.source, "world_transform": str(part.transform), "world_bounds": str(part.bounds)})
   var combined := surface.commit()
   if combined == null: continue
   var proxy := MeshInstance3D.new()
   proxy.name = "SceneryShadow_%d" % group_count
   proxy.mesh = combined
   proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
   proxy.set_meta("grounding_proxy", true)
   root.add_child(proxy)
   geometry.append(proxy)
   receipt.append({"theme": act.plan.theme, "sequence": act.plan.sequence, "zone": act.plan.zone, "method": method,
    "cell": str(cell), "triangles": Audit.triangles(combined), "surfaces": combined.get_surface_count(), "bounds": str(proxy.global_transform * proxy.get_aabb()),
    "source_components": parts, "candidates_in_act": candidates, "selected_in_act": accepted})
   group_count += 1
 receipt.append({"preparation_ms": (Time.get_ticks_usec() - began) / 1000.0, "groups": receipt.size(), "ceiling": ceiling})

static func _semantic_role(theme: String, bounds: AABB, mesh: Mesh, material: Material) -> String:
 # The production batchers discard prop names. Select the known large opaque
 # structural component families by their authored dimensions and material tags,
 # then record every exact source instance and matrix in the receipt. This is
 # deliberately limited to local scenery, never skyline/cloud/water batches.
 var size := bounds.size
 var tags := str(material.get_meta("atmosphere_bindings", {})) if material != null else ""
 match theme:
  "rooftop_run":
   if size.y > 2.5 and size.x > 0.9 and size.z > 0.9: return "courtyard_house_body"
   if size.y > 0.3 and size.y < 0.55 and size.x > 1.0 and size.z > 1.0 and Audit.triangles(mesh) <= 20: return "courtyard_house_roof"
  "ice_cap":
   if "ice" in tags and size.y > 0.7 and size.x < 1.2 and size.z < 1.2: return "opaque_crystal_shaft"
 return ""

func set_visible(game: Node, enabled: bool, reveal := false) -> void:
 update_visibility(game, enabled)
 for proxy: MeshInstance3D in geometry:
  if not is_instance_valid(proxy): continue
  proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if reveal else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
  if reveal:
   var material := StandardMaterial3D.new()
   material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
   material.albedo_color = Color("ff36cb")
   proxy.material_override = material
  else: proxy.material_override = null

func update_visibility(game: Node, enabled: bool) -> void:
 for root: Node3D in roots:
  if not is_instance_valid(root): continue
  # Cross-world shadows cannot alpha blend with backdrop composition. Suppress
  # experiments during overlap instead of casting from a partially visible Zone.
  root.visible = enabled and game.background_blend <= 0.0 and int(root.get_meta("grounding_zone")) == game._background_zone \
   and (bool(root.get_meta("grounding_ceiling")) or int(root.get_meta("grounding_sequence")) == game.active_sequence)
