extends SceneTree
## Production model builders at close range, across every stage palette.
const Models = preload("res://scripts/pinball_models.gd")
const Themes = preload("res://scripts/themes/theme_registry.gd")

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var output := "res://test-results/pinball-models/gallery.png"
 var shadow_review := "--profile-shadows" in OS.get_cmdline_user_args()
 Models.MeshBatch.shadow_batch_enabled = not "--profile-original-shadows" in OS.get_cmdline_user_args()
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--profile-output="): output = argument.trim_prefix("--profile-output=")
 root.size = Vector2i(1500, 1050)
 var p := TablePresentation.new()
 p.set_process(false)
 root.add_child(p)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("121d30")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color.WHITE
 environment.environment.ambient_light_energy = 0.7
 p.add_child(environment)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-60, -25, 0)
 light.light_energy = 1.5
 light.shadow_enabled = shadow_review
 light.directional_shadow_max_distance = 40.0
 p.add_child(light)
 if shadow_review:
  var floor_mesh := BoxMesh.new()
  floor_mesh.size = Vector3(20, 0.1, 20)
  var floor_visual := p.mesh_node(floor_mesh, p.material(Color("778596")), Vector3(4, -0.06, 4))
  floor_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var camera := Camera3D.new()
 p.add_child(camera)
 camera.position = Vector3(4.2, 11, 9.2)
 camera.look_at(Vector3(4.2, 0, 3.7))
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 12.5
 var index := 0
 for theme: String in Themes.IDS:
  var panel := Node3D.new()
  p.add_child(panel)
  panel.position = Vector3((index % 3) * 3.2 + 0.5, 0, (index / 3) * 3.7)
  var materials := Models.materials(theme)
  var bumper := Node3D.new()
  panel.add_child(bumper)
  Models.round_bumper(p, bumper, 0.5, 1.3, materials)
  var sling := Node3D.new()
  panel.add_child(sling)
  sling.position.x = 1.4
  Models.triangle_bumper(p, sling, PackedVector2Array([Vector2(-40, 35), Vector2(0, -40), Vector2(40, 35)]), 0.38, materials)
  var paddle := Node3D.new()
  panel.add_child(paddle)
  paddle.position = Vector3(-0.2, 0, 1.05)
  Models.flipper(p, paddle, 1.65, 0.18, 1.2, materials)
  var label := Label3D.new()
  panel.add_child(label)
  label.text = theme.replace("_", " ").to_upper()
  label.position = Vector3(0.7, 0.1, 1.85)
  label.rotation_degrees.x = -55
  label.font_size = 40
  label.pixel_size = 0.006
  index += 1
 for i in 10: await process_frame
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute(output.get_base_dir())
  root.get_texture().get_image().save_png(output)
 print("RESULT | Pinball model palette gallery | %d themes built" % index)
 p.free()
 quit()
