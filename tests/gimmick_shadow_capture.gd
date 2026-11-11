extends "res://tests/gimmick_shadow_regression.gd"
## Controlled hardware comparison, not a canonical Prototype appearance capture.
func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Gimmick shadow comparison requires a graphical renderer.")
  quit(1)
  return
 var output := "res://test-results/gimmick-shadows"
 var themes: Array = Models.STYLES.keys()
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
  if arg.begins_with("--theme="): themes = [arg.trim_prefix("--theme=")]
 DirAccess.make_dir_recursive_absolute(output)
 root.size = Vector2i(800, 600)
 root.msaa_3d = Viewport.MSAA_4X
 var presenter := Presenter.new()
 root.add_child(presenter)
 presenter.set_process(false)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("273442")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color.WHITE
 environment.environment.ambient_light_energy = 0.45
 presenter.add_child(environment)
 var light := DirectionalLight3D.new()
 light.shadow_enabled = true
 light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
 light.directional_shadow_max_distance = 40.0
 light.light_energy = 1.3
 light.rotation_degrees = Vector3(-52, -30, 0)
 presenter.add_child(light)
 var floor_mesh := BoxMesh.new()
 floor_mesh.size = Vector3(12, 0.1, 12)
 var floor_visual := presenter.mesh_node(floor_mesh, presenter.material(Color("929699")), Vector3(2, -0.06, 2))
 floor_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var camera := Camera3D.new()
 presenter.add_child(camera)
 camera.position = Vector3(2, 8, 9)
 camera.look_at(Vector3(2, 0, 2))
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 7.3
 camera.far = 45
 var results: Array = []
 for theme: String in themes:
  presenter.theme = theme
  Shadows.enabled = false
  var entries: Array[Dictionary] = []
  for i in KINDS.size():
   var item := item_for(KINDS[i])
   item.position = Vector2((i % 3) * 180, (i / 3) * 190)
   item.rotation_degrees = 0
   var entry := Models.build(presenter, presenter, item)
   detail(entry.root)
   entries.append(entry)
  var references: Array[Image] = []
  var draws: Array = []
  for phase in 2:
   if phase == 1:
    Shadows.enabled = true
    for entry: Dictionary in entries:
     state(entry, 0)
     Shadows.combine(entry.root, true, [entry.rubber] if entry.kind == "slingshot" else [])
   for pose in 3:
    for entry: Dictionary in entries: state(entry, pose)
    light.rotation_degrees.x = -20 if pose == 2 else -52
    for frame in 12: await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    var count := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    check(image.save_png(output.path_join("%s-%s-%d.png" % [theme, "original" if phase == 0 else "combined", pose])) == OK, "Capture saves")
    if phase == 0:
     references.append(image)
     draws.append(count)
    else:
     var equal: bool = image.get_data() == references[pose].get_data()
     check(equal, "%s pose %d preserves pixels" % [theme, pose])
     check(count < draws[pose], "%s pose %d reduces draws" % [theme, pose])
     results.append({"theme":theme,"pose":pose,"original_draws":draws[pose],"combined_draws":count,"pixels_identical":equal})
     print("GIMMICK_SHADOW_RENDER | " + JSON.stringify(results.back()))
  for entry: Dictionary in entries: entry.root.free()
  await process_frame
 var report := {"metadata": preload("res://tests/render_profile_support.gd").metadata(), "shadow_atlas":ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size"), "cascades":4,"msaa":4,"results":results}
 FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
 presenter.free()
 quit(1 if failures else 0)
