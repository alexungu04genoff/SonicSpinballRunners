extends RefCounted
## A visible matte stair, wall and supported shelf under the real foreground
## atmosphere. The surrounding playfield and HUD retain their production paths.
static func box(root: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> void:
 var node := MeshInstance3D.new()
 var mesh := BoxMesh.new()
 mesh.size = size
 node.name = label
 node.mesh = mesh
 node.material_override = material
 root.add_child(node)
 node.position = at

static func place(game: Node) -> void:
 # The neutral fixture owns the foreground of this disposable case. This
 # keeps native decor from intersecting the treads. Gameplay Acts use their
 # ordinary geometry and the same camera, lighting and Retro stack.
 for node: GeometryInstance3D in game.view.find_children("*","GeometryInstance3D",true,false):
  if not game.presentation.camera.is_ancestor_of(node): node.hide()
 var root := Node3D.new()
 root.name = "ContactStudy"
 game.active.visual.add_child(root)
 root.global_position = TablePresentation.map_point(game.ball.position, 0.50)
 var matte := ShaderMaterial.new()
 matte.shader = Shader.new()
 matte.shader.code = """shader_type spatial;
render_mode specular_disabled;
void fragment() {
 ALBEDO = vec3(0.46, 0.52, 0.58);
 ROUGHNESS = 1.0;
}
"""
 matte.set_meta("atmosphere_hue", "terrain_ledges")
 box(root, "Floor", Vector3(0,-0.10,0), Vector3(5.8,0.20,4.6), matte)
 box(root, "RearWall", Vector3(0,0.55,-1.35), Vector3(4.0,1.10,0.18), matte)
 for i in 5:
  var height := 0.16 * (i + 1)
  box(root, "Riser%d" % i, Vector3(-0.72,height / 2.0,0.96 - i * 0.42), Vector3(1.75,height,0.42), matte)
 box(root, "SupportedShelf", Vector3(1.08,0.87,-0.55), Vector3(1.45,0.14,1.13), matte)
 for x: float in [0.48,1.65]:
  box(root, "ShelfLeg", Vector3(x,0.40,-0.73), Vector3(0.19,0.80,0.72), matte)
 var lightstrip := StandardMaterial3D.new()
 lightstrip.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 lightstrip.albedo_color = Color(0.98,0.64,0.23)
 box(root, "UnlitReference", Vector3(1.08,0.55,-1.24), Vector3(0.8,0.08,0.04), lightstrip)
 var slider := StandardMaterial3D.new()
 slider.albedo_color = Color("#bc6436")
 slider.roughness = 0.8
 box(root,"Slider",Vector3(1.10,0.12,0.60),Vector3(0.52,0.24,0.48),slider)
