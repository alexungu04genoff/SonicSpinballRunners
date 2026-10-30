extends Node3D
## Flat, collisionless warnings below the active Act's entry / cleared Act's exit.
var pulse_phase := 0.0
var sign_materials: Array[StandardMaterial3D] = []

func configure(document: Resource, offset: Vector2) -> void:
 process_mode = Node.PROCESS_MODE_PAUSABLE
 name = "ClearedExitWarning"
 visible = false
 var cell := float(document.cell_size)
 var entry: Dictionary = document.get_connector("entry")
 var width := float(entry.width) * cell
 var center := offset + Vector2((float(entry.start_x) + float(entry.width) * 0.5) * cell, document.terrain_bounds().end.y + cell * 0.6)
 position = TablePresentation.map_point(center, 0.025)
 var material := StandardMaterial3D.new()
 material.albedo_color = Color("171b20")
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 var mesh := ImmediateMesh.new()
 mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
 var size := minf(cell * 0.38, width * 0.22) * TablePresentation.SCALE
 for index in 3:
  var x := (index - 1) * width * 0.28 * TablePresentation.SCALE
  var points := [Vector3(x, 0, -size * 0.5), Vector3(x + size * 0.5, 0, size * 0.5), Vector3(x - size * 0.5, 0, size * 0.5)]
  for edge in 3:
   var a: Vector3 = points[edge]
   var b: Vector3 = points[(edge + 1) % 3]
   var normal := (b - a).cross(Vector3.UP).normalized() * size * 0.045
   for vertex: Vector3 in [a - normal, a + normal, b + normal, a - normal, b + normal, b - normal]:
    mesh.surface_add_vertex(vertex)
 mesh.surface_end()
 var yellow := material.duplicate() as StandardMaterial3D
 yellow.albedo_color = Color("ffd43b")
 sign_materials = [material, yellow]
 _set_opacity(0.40)
 mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, yellow)
 for index in 3:
  var x := (index - 1) * width * 0.28 * TablePresentation.SCALE
  for vertex: Vector3 in [Vector3(x, 0, -size * 0.43), Vector3(x + size * 0.43, 0, size * 0.46), Vector3(x - size * 0.43, 0, size * 0.46)]:
   mesh.surface_add_vertex(vertex)
 mesh.surface_end()
 mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
 for index in 3:
  var x := (index - 1) * width * 0.28 * TablePresentation.SCALE
  _quad(mesh, x, -size * 0.12, size * 0.15, size * 0.11)
  _quad(mesh, x, size * 0.24, size * 0.34, size * 0.11)
 mesh.surface_end()
 var marker := MeshInstance3D.new()
 marker.mesh = mesh
 marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(marker)

func _quad(mesh: ImmediateMesh, x: float, top: float, bottom: float, width: float) -> void:
 var a := Vector3(x - width * 0.5, 0.002, top)
 var b := Vector3(x + width * 0.5, 0.002, top)
 var c := Vector3(x + width * 0.5, 0.002, bottom)
 var d := Vector3(x - width * 0.5, 0.002, bottom)
 for vertex: Vector3 in [a, b, c, a, c, d]: mesh.surface_add_vertex(vertex)

func _process(delta: float) -> void:
 if not is_visible_in_tree(): return
 pulse_phase = fposmod(pulse_phase + delta * TAU / 2.4, TAU)
 _set_opacity(0.40 + 0.05 * sin(pulse_phase))

func _set_opacity(value: float) -> void:
 for material: StandardMaterial3D in sign_materials:
  material.albedo_color.a = value
