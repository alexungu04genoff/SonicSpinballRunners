extends "res://scripts/decor/decor_skin.gd"
## Lightweight, collisionless props in cell units. Reuses the presentation's
## existing palm and sunflower silhouettes; all assets are constructed locally.
var presentation: Node3D

func _init(owner_presentation: Node3D) -> void:
 presentation = owner_presentation
 skin_id = "green_hill"
 pools = {
  "small": {"surface": ["flower", "small_rock"], "edge": ["flower", "small_rock"], "either": ["flower", "small_rock"]},
  "medium": {"surface": ["shrub", "medium_rock", "flower_patch"], "edge": ["medium_rock", "shrub"], "either": ["medium_rock", "shrub", "flower_patch"]},
  "large": {"surface": ["tall_rock", "checker_pedestal"], "edge": ["palm", "palm_left"], "either": ["palm", "tall_rock", "checker_pedestal"]},
  "landmark": {"surface": ["turf_loop"], "edge": ["turf_loop"], "either": ["turf_loop"]},
 }
 factory = _build_prop

func _build_prop(variant: String) -> Node3D:
 var root := Node3D.new()
 root.name = variant.to_pascal_case()
 match variant:
  "flower": presentation._flower(Vector3.ZERO, 0.72, root)
  "small_rock": _rock(root, Vector3.ZERO, Vector3(0.23, 0.18, 0.20))
  "medium_rock":
   _rock(root, Vector3.ZERO, Vector3(0.48, 0.46, 0.38))
   _rock(root, Vector3(0.20, 0, 0.12), Vector3(0.22, 0.23, 0.20))
  "tall_rock":
   _rock(root, Vector3(-0.12, 0, 0.04), Vector3(0.48, 1.12, 0.45))
   _rock(root, Vector3(0.23, 0, 0.10), Vector3(0.36, 0.68, 0.40))
  "shrub":
   for i in 3:
    var mesh := SphereMesh.new()
    mesh.radius = 0.22
    mesh.height = 0.36
    mesh.radial_segments = 7
    mesh.rings = 3
    var offset := Vector3((i - 1) * 0.18, 0.15 + (0.07 if i == 1 else 0.0), 0.08 if i == 1 else 0.0)
    presentation.mesh_node(mesh, presentation.material(Color("52ae36") if i == 1 else Color("287e38")), offset, root)
  "flower_patch":
   presentation._flower(Vector3(-0.16, 0, 0.04), 0.72, root)
   presentation._flower(Vector3(0.17, 0, -0.04), 0.54, root)
   presentation._flower(Vector3(0.02, 0, 0.15), 0.45, root)
  "palm", "palm_left": presentation._palm(Vector3.ZERO, -1 if variant == "palm_left" else 1, 0.82, root)
  "checker_pedestal":
   _checker_box(root, Vector3(0, 0.25, 0), Vector3(0.68, 0.5, 0.68))
   _grass_box(root, Vector3(0, 0.53, 0), Vector3(0.73, 0.08, 0.73))
   presentation._flower(Vector3(0, 0.57, 0), 0.63, root)
  "turf_loop":
   _checker_box(root, Vector3(0, 0.08, 0), Vector3(1.95, 0.16, 0.65))
   _grass_box(root, Vector3(0, 0.18, 0), Vector3(2.0, 0.06, 0.70))
   # A faceted upright ornament, deliberately outside the playable plane.
   for i in 16:
    var angle := TAU * float(i) / 16.0
    var radial := Vector3(cos(angle), sin(angle), 0)
    var center := Vector3(0, 1.04, 0)
    var block := _checker_box(root, center + radial * 0.82, Vector3(0.36, 0.24, 0.34))
    block.rotation.z = angle - PI * 0.5
    var turf := _grass_box(root, center + radial * 0.965, Vector3(0.39, 0.055, 0.39))
    turf.rotation.z = angle - PI * 0.5
 return root

func _rock(root: Node3D, base: Vector3, size: Vector3) -> void:
 var mesh := CylinderMesh.new()
 mesh.bottom_radius = 0.5
 mesh.top_radius = 0.29
 mesh.height = 1.0
 mesh.radial_segments = 5
 mesh.rings = 1
 var rock: MeshInstance3D = presentation.mesh_node(mesh, presentation.material(Color("b9b497")), base + Vector3.UP * size.y * 0.5, root)
 rock.scale = size
 rock.rotation.y = 0.35

func _checker_box(root: Node3D, at: Vector3, size: Vector3) -> MeshInstance3D:
 var box := BoxMesh.new()
 box.size = size
 return presentation.mesh_node(box, presentation._cliff, at, root)

func _grass_box(root: Node3D, at: Vector3, size: Vector3) -> MeshInstance3D:
 var box := BoxMesh.new()
 box.size = size
 return presentation.mesh_node(box, presentation.terrain_top_material(), at, root)
