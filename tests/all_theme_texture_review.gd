extends SceneTree
## Close-up material study using the production terrain and border builders.
const Presentation = preload("res://scripts/themes/themed_presentation.gd")
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Mechanics = preload("res://scripts/authored_act/mechanics_presentation.gd")
const OUTPUT := "res://docs/all-theme-textures/"
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
 for theme_id: String in Themes.IDS:
  var theme: RefCounted = Themes.create(theme_id)
  p.set_theme_definition(theme)
  theme.configure_environment(p)
  var stage := Node3D.new()
  p.add_child(stage)
  p.authored_mode = true
  p._make_land(floor_outline, 0.5, stage, 0.0, 0.0)
  p.mesh_node(p._prism(circle, 0.325, theme.side_material, theme.top_material), null, Vector3.ZERO, stage)
  p._add_border(circle, no_holes, theme.top_border_width, 0.325, theme.top_border_material, stage, "TopSurfaceBorder")
  p._add_border(floor_outline, holes, theme.floor_border_width, 0.0, theme.floor_border_material, stage, "FloorPathBorder")
  for view: String in ["curve", "ramp"]:
   camera.projection = Camera3D.PROJECTION_PERSPECTIVE
   camera.fov = 44
   var center := Vector3(0, 0.25, 0.65)
   camera.position = center + Vector3(0.9, 1.3, 2.2)
   if view == "ramp":
    stage.visible = false
    var ramp := Mechanics.new()
    p.add_child(ramp)
    ramp.name = "ReviewRamp"
    ramp.table = p
    var path := preload("res://scripts/authored_act/rail_path.gd").build(PackedVector2Array([Vector2(-130, 80), Vector2(-100, -60), Vector2(30, -90), Vector2(130, 50)]))
    ramp._rail({"path": path, "properties": {"width": 55.0, "height": 65.0}})
    center = Vector3(0, 0.25, 0)
    camera.position = center + Vector3(1.7, 2.7, 3.5)
   camera.look_at(center)
   for i in 8: await process_frame
   await RenderingServer.frame_post_draw
   var suffix := ""
   for arg: String in OS.get_cmdline_user_args():
    if arg.begins_with("--label="): suffix = "-" + arg.trim_prefix("--label=")
   assert(root.get_texture().get_image().save_png(OUTPUT + theme.theme_id + "-" + view + suffix + ".png") == OK)
  if p.has_node('ReviewRamp'): p.get_node('ReviewRamp').free()
  stage.free()
 p.free()
 print("RESULT | All-theme curve and ramp review | %d captures" % (Themes.IDS.size() * 2))
 quit()
