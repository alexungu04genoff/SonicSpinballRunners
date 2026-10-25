extends SceneTree
## Reproducible shader comparison: the exact gameplay sphere, with blur disabled below.
const SHADER = preload("res://experiments/visual_lab/spin_ball.gdshader")

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.size = Vector2i(1200, 960)
 var world := Node3D.new()
 root.add_child(world)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("15202d")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color.WHITE
 environment.environment.ambient_light_energy = 0.65
 world.add_child(environment)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-30, -25, 0)
 light.light_energy = 0.8
 world.add_child(light)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 8.7
 camera.position = Vector3(0, 0, 9)
 world.add_child(camera)
 camera.current = true
 var overlay := CanvasLayer.new()
 root.add_child(overlay)
 await process_frame
 var names := ["Sonic", "Tails", "Knuckles", "Shadow"]
 var colors := [Color("075dd2"), Color("f28b17"), Color(0.94, 0.23, 0.2), Color(0.025, 0.025, 0.035)]
 for column in 4:
  label(overlay, names[column], camera.unproject_position(Vector3(-3.0 + column * 2.0, 3.8, 0)) - Vector2(40, 0), 25)
  for row in 3:
   var sphere := SphereMesh.new()
   sphere.radius = 0.65
   sphere.height = 1.3
   sphere.radial_segments = 32
   sphere.rings = 16
   var material := ShaderMaterial.new()
   material.shader = SHADER
   material.set_shader_parameter("fur_color", colors[column])
   material.set_shader_parameter("character_style", column)
   material.set_shader_parameter("blur_amount", 2.7 if row == 0 else 0.0)
   var mesh := MeshInstance3D.new()
   mesh.mesh = sphere
   mesh.material_override = material
   mesh.position = Vector3(-3.0 + column * 2.0, 2.2 - row * 2.2, 0)
   mesh.rotation.y = PI if row == 2 else 0.0
   world.add_child(mesh)
 label(overlay, "3× blur · front", Vector2(25, camera.unproject_position(Vector3(0, 3.15, 0)).y), 20)
 label(overlay, "No blur · front", Vector2(25, camera.unproject_position(Vector3(0, 0.95, 0)).y), 20)
 label(overlay, "No blur · back", Vector2(25, camera.unproject_position(Vector3(0, -1.25, 0)).y), 20)
 await process_frame
 await RenderingServer.frame_post_draw
 var error := root.get_texture().get_image().save_png("res://test-results/character-spin-gallery.png")
 print("SPIN_GALLERY | capture ", error_string(error))
 quit(0 if error == OK else 1)

func label(parent: Node, text: String, position: Vector2, size: int) -> void:
 var title := Label.new()
 title.text = text
 title.position = position
 title.add_theme_font_size_override("font_size", size)
 parent.add_child(title)
