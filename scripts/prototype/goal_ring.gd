extends Node3D
## Collisionless goal presentation; the run checks authoritative swept 2D motion.
var center := Vector2.ZERO
var radius := 25.0
var unlocked := false
var material := StandardMaterial3D.new()

func configure(document: Resource, offset: Vector2) -> void:
 center = document.goal_center() + offset
 radius = float(document.cell_size) * float(document.goal_diameter_cells) * 0.5
 position = TablePresentation.map_point(center, maxf(0.025, radius * TablePresentation.SCALE * 0.15))
 var hoop := MeshInstance3D.new()
 var mesh := TorusMesh.new()
 mesh.outer_radius = radius * TablePresentation.SCALE
 mesh.inner_radius = mesh.outer_radius * 0.78
 mesh.rings = 32
 mesh.ring_segments = 8
 hoop.mesh = mesh
 material.metallic = 0.55
 material.roughness = 0.25
 material.emission_enabled = true
 hoop.material_override = material
 add_child(hoop)
 set_unlocked(false)

func set_unlocked(value: bool) -> void:
 unlocked = value
 material.albedo_color = Color("ffd447") if value else Color("70757e")
 material.emission = material.albedo_color * (0.6 if value else 0.03)

func crossed(start: Vector2, finish: Vector2, ball_radius: float) -> bool:
 return unlocked and Geometry2D.get_closest_point_to_segment(center, start, finish).distance_to(center) <= radius + ball_radius
