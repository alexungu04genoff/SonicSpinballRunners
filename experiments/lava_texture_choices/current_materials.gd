extends SceneTree
## Photographs existing production materials; never generates replacement C textures.
const OUTPUT := "res://experiments/lava_texture_choices/"
const Decor = preload("res://scripts/decor/lava_reef_decor.gd")
const Bindings = preload("res://scripts/atmosphere/material_bindings.gd")

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var config := ConfigFile.new()
 config.load("res://data/atmospheres/lava_reef.cfg")
 var values: Dictionary = config.get_value("default", "values", {})
 var viewport := SubViewport.new()
 viewport.size = Vector2i(512, 512)
 viewport.own_world_3d = true
 viewport.msaa_3d = Viewport.MSAA_4X
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var stage := Node3D.new()
 viewport.add_child(stage)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 for key: String in values:
  if key.begins_with("env/"):
   environment.environment.set(key.trim_prefix("env/"), values[key])
 stage.add_child(environment)
 var sun := DirectionalLight3D.new()
 for key: String in values:
  if key.begins_with("sun/"): sun.set(key.trim_prefix("sun/"), values[key])
 sun.rotation_degrees = Vector3(values.get("sun_pitch", -56.0), values.get("sun_yaw", -30.0), 0)
 stage.add_child(sun)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 3.0
 stage.add_child(camera)
 var library := Decor.new(null)
 var mesh := MeshInstance3D.new()
 stage.add_child(mesh)
 var bindings := Bindings.new()
 for item in [10, 11]:
  bindings.restore()
  if item == 10:
   var plane := PlaneMesh.new()
   plane.size = Vector2(3.0, 3.0)
   mesh.mesh = plane
   mesh.material_override = library.materials.molten
   camera.position = Vector3(0, 5, 0)
   camera.look_at(Vector3.ZERO, Vector3.FORWARD)
   camera.size = 3.0
  else:
   mesh.mesh = library.primitive("gem")
   mesh.material_override = library.materials.crystal
   mesh.scale = Vector3(0.72, 2.1, 0.72)
   camera.position = Vector3(2.3, 1.5, 3.7)
   camera.look_at(Vector3(0, 0.80, 0), Vector3.UP)
   camera.size = 2.65
  bindings.collect(stage, "lava_reef")
  bindings.apply_palette(values, sun, false)
  bindings.apply(float(values.get("emission", 1.0)))
  for frame in 20: await process_frame
  await RenderingServer.frame_post_draw
  var result := viewport.get_texture().get_image().save_png(OUTPUT + str(item) + "C-material.png")
  if result != OK:
   quit(1)
   return
  print("Current material photographed: ", item, " / ", mesh.material_override.shader.resource_path)
 bindings.restore()
 viewport.free()
 quit()
