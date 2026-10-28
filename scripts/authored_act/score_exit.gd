extends StaticBody2D
## Score-controlled connector hardware, independent of authored routing gates.
var unlocked := true
var marker: MeshInstance3D
var label: Label3D
var _material: StandardMaterial3D

func configure(document: Resource, offset: Vector2, visual_parent: Node3D, gated: bool) -> void:
 name = "ActScoreExit"
 var connector: Dictionary = document.get_connector("exit")
 var width := float(connector.width) * float(document.cell_size)
 position = offset + Vector2((float(connector.start_x) + float(connector.width) * 0.5) * float(document.cell_size), 0)
 collision_mask = 2
 var shape := RectangleShape2D.new()
 shape.size = Vector2(width, maxf(4.0, float(document.cell_size) * 0.08))
 var collision := CollisionShape2D.new()
 collision.shape = shape
 add_child(collision)
 physics_material_override = PhysicsMaterial.new()
 physics_material_override.bounce = 0.8
 marker = MeshInstance3D.new()
 var mesh := BoxMesh.new()
 mesh.size = Vector3(width * TablePresentation.SCALE, 0.12, shape.size.y * TablePresentation.SCALE)
 marker.mesh = mesh
 marker.position = TablePresentation.map_point(position, 0.08)
 _material = StandardMaterial3D.new()
 _material.emission_enabled = true
 marker.material_override = _material
 visual_parent.add_child(marker)
 label = Label3D.new()
 label.position = marker.position + Vector3(0, 0.30, 0)
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size = 34
 label.pixel_size = 0.002
 visual_parent.add_child(label)
 set_unlocked(not gated)
 marker.visible = gated
 label.visible = gated

func set_unlocked(value: bool) -> void:
 unlocked = value
 # The ordinary ball CCD and conservative shape sweep see this body on layer 1.
 set_deferred("collision_layer", 0 if value else 1)
 if is_instance_valid(marker):
  var color := Color("74efb0") if value else Color("ff9b52")
  _material.albedo_color = color
  _material.emission = color * 0.35
  marker.scale.y = 0.15 if value else 1.0
  label.text = "EXIT OPEN" if value else "SCORE TARGET · EXIT LOCKED"
  label.modulate = color

func _exit_tree() -> void:
 if is_instance_valid(marker): marker.queue_free()
 if is_instance_valid(label): label.queue_free()
