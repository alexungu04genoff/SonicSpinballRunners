extends SceneTree
## Render old native equations at fixed TIME samples against neutral overrides.
## Optional snapshots override the recorded starting Git revision.
const STARTING_REVISION := "ecbe1b812f0b0be11b7f3364c83e084fd0424c0a"
const NAMES := ["green_hill_ocean", "green_hill_cloud", "chemical_reservoir", "rooftop_canal", "sanctuary_clouds", "sanctuary_cloud_volume", "ice_aurora", "ice_snow", "ice_lake", "aquarium_water"]
var original_directory := "res://test-results/theme-motion/original-shaders"
var output := "res://test-results/theme-motion/shader-parity.json"
var view: SubViewport
var mesh: MeshInstance3D
var failures := 0
var results: Array[Dictionary] = []

func _initialize() -> void:
 run.call_deferred()

func run() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--originals="): original_directory = argument.trim_prefix("--originals=")
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
 if DisplayServer.get_name() == "headless":
  push_error("Shader parity requires a graphical renderer.")
  quit(1)
  return
 view = SubViewport.new()
 view.size = Vector2i(256, 256)
 view.own_world_3d = true
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("162234")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color.WHITE
 environment.environment.ambient_light_energy = 0.5
 view.add_child(environment)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-45, -35, 0)
 view.add_child(light)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 18.0
 camera.position = Vector3(0, 8, 12)
 view.add_child(camera)
 camera.look_at(Vector3.ZERO)
 camera.current = true
 mesh = MeshInstance3D.new()
 mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mesh.extra_cull_margin = 12.0 # Diagnostic plane accommodates existing aurora/snow envelopes.
 view.add_child(mesh)
 for shader_name: String in NAMES:
  var path := original_directory.path_join(shader_name + ".gdshader")
  var original := original_source(shader_name, path)
  if original.is_empty():
   push_error("Cannot read original shader from snapshot or Git: " + path)
   failures += 1
   continue
  if shader_name in ["green_hill_cloud", "sanctuary_cloud_volume", "ice_snow"]:
   var sphere := SphereMesh.new()
   sphere.radius = 2.0
   sphere.height = 4.0
   sphere.radial_segments = 8
   sphere.rings = 3
   mesh.mesh = sphere
  else:
   var plane := PlaneMesh.new()
   plane.size = Vector2(16, 16)
   plane.subdivide_width = 24
   plane.subdivide_depth = 12
   mesh.mesh = plane
  for seconds: float in [0.0, 7.25, 19.0]:
   var control := ShaderMaterial.new()
   control.shader = Shader.new()
   control.shader.code = original.replace("TIME", "(" + str(seconds) + ")")
   var current := ShaderMaterial.new()
   current.shader = load("res://scripts/themes/" + shader_name + ".gdshader")
   current.set_shader_parameter("time_override", seconds)
   current.set_shader_parameter("motion_candidate", 0)
   var before := await capture(control)
   var after := await capture(current)
   var comparison := compare(before, after)
   comparison.merge({"shader":shader_name, "seconds":seconds})
   results.append(comparison)
   if not comparison.passed:
    failures += 1
    before.save_png(output.get_base_dir().path_join(shader_name + "-original-" + str(seconds) + ".png"))
    after.save_png(output.get_base_dir().path_join(shader_name + "-current-" + str(seconds) + ".png"))
   print("SHADER_PARITY | ", shader_name, " | ", seconds, " | ", JSON.stringify(comparison))
 mesh.material_override = null
 var file := FileAccess.open(output, FileAccess.WRITE)
 if file: file.store_string(JSON.stringify({"failures":failures,"samples":results}, "  "))
 else: failures += 1
 print("RESULT | Theme Motion shader parity | %d samples | %d failures" % [results.size(), failures])
 quit(1 if failures else 0)

static func original_source(shader_name: String, snapshot: String) -> String:
 if FileAccess.file_exists(snapshot): return FileAccess.get_file_as_string(snapshot)
 var captured: Array = []
 var relative := "scripts/themes/" + shader_name + ".gdshader"
 var status := OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "show", STARTING_REVISION + ":" + relative]), captured, false, false)
 return str(captured[0]) if status == 0 and not captured.is_empty() else ""

func capture(material: ShaderMaterial) -> Image:
 mesh.material_override = material
 for frame in 4: await process_frame
 await RenderingServer.frame_post_draw
 var image := view.get_texture().get_image()
 image.convert(Image.FORMAT_RGBA8)
 return image

func compare(a: Image, b: Image) -> Dictionary:
 var left := a.get_data()
 var right := b.get_data()
 var maximum := 0
 var total := 0
 var changed := 0
 for index in left.size():
  if index % 4 == 3: continue
  var difference := absi(int(left[index]) - int(right[index]))
  maximum = maxi(maximum, difference)
  total += difference
  if difference > 2: changed += 1
 var channels := float(left.size()) * 0.75
 var mean := total / channels
 var fraction := changed / channels
 # Constant folding versus a uniform can change final rounding by one LSB.
 return {"max_channel_delta":maximum,"mean_channel_delta":mean,"fraction_over_2":fraction,"passed":mean <= 0.02 and fraction <= 0.0001}
