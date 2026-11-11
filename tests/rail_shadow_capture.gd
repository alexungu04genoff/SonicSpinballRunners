extends SceneTree
## Isolated static rail comparison, not a canonical Prototype appearance capture.
const Fixture = preload("res://tests/rail_shadow_fixture.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Rail capture requires a graphical renderer.")
  quit(1)
  return
 var output := "res://test-results/rail-shadows"
 var themes: Array = Fixture.Registry.IDS.duplicate()
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--theme="): themes = [arg.trim_prefix("--theme=")]
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
 DirAccess.make_dir_recursive_absolute(output)
 root.size = Vector2i(800,600)
 root.msaa_3d = Viewport.MSAA_4X
 var world := Node3D.new()
 root.add_child(world)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("273442")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color.WHITE
 environment.environment.ambient_light_energy = 0.45
 world.add_child(environment)
 var light := DirectionalLight3D.new()
 light.shadow_enabled = true
 light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
 light.directional_shadow_max_distance = 40.0
 light.light_energy = 1.3
 world.add_child(light)
 var floor_visual := MeshInstance3D.new()
 floor_visual.mesh = BoxMesh.new()
 floor_visual.mesh.size = Vector3(30,0.1,30)
 floor_visual.position = Vector3(2,-0.06,2)
 floor_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 floor_visual.material_override = StandardMaterial3D.new()
 floor_visual.material_override.albedo_color = Color("929699")
 world.add_child(floor_visual)
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.far = 45
 var results: Array = []
 var control := PackedVector2Array([Vector2(0,500),Vector2(0,200),Vector2(220,50),Vector2(450,200),Vector2(450,500)])
 for theme: String in themes:
  var fixture := await Fixture.build(world,theme,control)
  var before := Fixture.inventory(fixture.rail)
  var reference: Array[Image] = []
  var draws: Array = []
  for phase in 2:
   if phase == 1: Fixture.combine(fixture.rail)
   for view in 3:
    var focus := Vector3(2.2,0,2.6) if view == 0 else Vector3(0,0,3.5)
    camera.position = focus + Vector3(0,8,7)
    camera.look_at(focus)
    camera.size = 8.5 if view == 0 else 2.8
    light.rotation_degrees = Vector3(-20 if view == 2 else -52,-30,0)
    for frame in 12: await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    var count := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    if image.save_png(output.path_join("%s-%s-%d.png" % [theme,"original" if phase == 0 else "combined",view])) != OK: failures += 1
    if phase == 0:
     reference.append(image)
     draws.append(count)
    else:
     var equal := image.get_data() == reference[view].get_data()
     if not equal or count >= draws[view]: failures += 1
     results.append({"theme":theme,"view":view,"pixels_identical":equal,"original_draws":draws[view],"combined_draws":count,"original_inventory":before,"combined_inventory":Fixture.inventory(fixture.rail)})
     print("RAIL_SHADOW_RENDER | " + JSON.stringify(results.back()))
  fixture.presenter.free()
  await process_frame
 var report := {"metadata":preload("res://tests/render_profile_support.gd").metadata(),"shadow_atlas":ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size"),"cascades":4,"msaa":4,"results":results,"failures":failures}
 var receipt := FileAccess.open(output.path_join("receipt.json"),FileAccess.WRITE)
 if receipt == null: failures += 1
 else: receipt.store_string(JSON.stringify(report,"  "))
 world.free()
 quit(1 if failures else 0)
