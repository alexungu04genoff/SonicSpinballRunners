extends SceneTree
## Close-up material study using the production terrain and border builders.
const Presentation = preload("res://scripts/themes/themed_presentation.gd")
const GreenHill = preload("res://scripts/themes/green_hill_theme.gd")
const Rooftop = preload("res://scripts/themes/rooftop_run_theme.gd")
const OUTPUT := "res://docs/rooftop-textures/"
var p: Node3D

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 if DisplayServer.get_name() == "headless":
  quit(1)
  return
 root.size = Vector2i(1440, 1000)
 p = Presentation.new()
 p.set_process(false)
 root.add_child(p)
 p._world_environment = WorldEnvironment.new()
 p._world_environment.environment = Environment.new()
 p.add_child(p._world_environment)
 p._key_light = DirectionalLight3D.new()
 p._key_light.shadow_enabled = true
 p.add_child(p._key_light)
 var camera := Camera3D.new()
 p.add_child(camera)
 camera.current = true
 camera.near = 0.05
 camera.far = 180.0
 var circle := PackedVector2Array()
 for i in 96:
  var angle := float(i) * TAU / 96.0
  circle.append(Vector2(cos(angle) * 145.0, sin(angle) * 100.0))
 var floor_outline := PackedVector2Array([Vector2(-210, -155), Vector2(210, -155), Vector2(210, 155), Vector2(-210, 155)])
 var holes: Array[PackedVector2Array] = [circle]
 var no_holes: Array[PackedVector2Array] = []
 for theme: RefCounted in [GreenHill.new(), Rooftop.new()]:
  p.set_theme_definition(theme)
  theme.configure_environment(p)
  var stage := Node3D.new()
  p.add_child(stage)
  p.authored_mode = true
  p._make_land(floor_outline, 0.5, stage, 0.0, 0.0)
  p.mesh_node(p._prism(circle, 0.325, theme.side_material, theme.top_material), null, Vector3.ZERO, stage)
  p._add_border(circle, no_holes, theme.top_border_width, 0.325, theme.top_border_material, stage, "TopSurfaceBorder")
  p._add_border(floor_outline, holes, theme.floor_border_width, 0.0, theme.floor_border_material, stage, "FloorPathBorder")
  for view: String in ["curve", "overhead", "grazing"]:
   camera.projection = Camera3D.PROJECTION_PERSPECTIVE
   camera.fov = 44
   var center := Vector3(0, 0.25, 0.65)
   camera.position = center + Vector3(0.9, 1.3, 2.2)
   if view == "overhead":
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 4.6
    center = Vector3.ZERO
    camera.position = Vector3(0, 8, 0.001)
   elif view == "grazing":
    camera.position = center + Vector3(0.3, 0.65, 3.2)
   camera.look_at(center)
   for i in 8: await process_frame
   await RenderingServer.frame_post_draw
   var suffix := ""
   for arg: String in OS.get_cmdline_user_args():
    if arg.begins_with("--label="): suffix = "-" + arg.trim_prefix("--label=")
   assert(root.get_texture().get_image().save_png(OUTPUT + theme.theme_id + "-" + view + suffix + ".png") == OK)
  stage.free()
 p.free()
 print("RESULT | Border path review | 6 captures")
 quit()
