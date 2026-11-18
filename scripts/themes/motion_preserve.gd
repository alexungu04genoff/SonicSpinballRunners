extends RefCounted
## Offline custom batches retain only explicitly declared moving subtrees.
## Ordinary transforms and materials are unchanged when the candidate is off.

static func take(root: Node3D) -> Array[Node3D]:
 var result: Array[Node3D] = []
 _take(root, Transform3D.IDENTITY, result)
 return result

static func _take(parent: Node3D, transform: Transform3D, result: Array[Node3D]) -> void:
 for child: Node in parent.get_children():
  if not child is Node3D: continue
  var local: Transform3D = transform * child.transform
  if child.has_meta("theme_motion"):
   var spec: Dictionary = child.get_meta("theme_motion").duplicate(true)
   if spec.get("kind", "") == "drift":
    # Drift is expressed in the original parent's coordinates. Flattening a
    # scaled/rotated tank must transform its motion envelope with its geometry.
    var displacement: Vector3 = transform.basis * (Vector3(spec.axis).normalized() * float(spec.amplitude))
    if displacement.length_squared() > 0.0:
     spec.axis = displacement.normalized()
     spec.amplitude = displacement.length()
     child.set_meta("theme_motion", spec)
   parent.remove_child(child)
   child.transform = local
   result.append(child)
  else:
   _take(child, local, result)

static func restore(root: Node3D, nodes: Array[Node3D]) -> void:
 for node: Node3D in nodes: root.add_child(node)
