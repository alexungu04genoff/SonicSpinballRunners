extends SceneTree
## A review catalogue of the live theme materials, not replacement texture assets.
const Themes = preload("res://scripts/themes/theme_registry.gd")
const OUTPUT := "res://docs/surface-catalog"
const KEYS := ["floor", "top", "wall", "ledge", "ramp"]
const HEADINGS := ["A / MAIN FLOOR", "B / RAISED TOP", "C / WALL SIDE", "D / OUTER LEDGE", "E / RAMP DECK"]
var views: Array[Dictionary] = []

class Stage extends Node3D:
 var _world_environment: WorldEnvironment
 var _key_light: DirectionalLight3D

func _initialize() -> void:
 call_deferred("run")

func label(parent: Node, text: String, at: Vector2, size: int) -> void:
 var item := Label.new()
 item.text = text
 item.position = at
 item.add_theme_font_size_override("font_size", size)
 item.add_theme_color_override("font_color", Color("e8edf5"))
 parent.add_child(item)

func panel(mat: Material, column: int) -> MeshInstance3D:
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var vertical := column in [2, 3]
 var height := 1.45 if column == 3 else 0.65
 var top := 0.0 if column == 3 else 0.325
 var positions: Array[Vector3]
 if vertical:
  positions = [Vector3(-1.2, top, 0), Vector3(1.2, top, 0), Vector3(-1.2, top - height, 0), Vector3(1.2, top - height, 0)]
 else:
  positions = [Vector3(-1.2, 0, -0.7), Vector3(1.2, 0, -0.7), Vector3(-1.2, 0, 0.7), Vector3(1.2, 0, 0.7)]
 if column == 4:
  positions = [Vector3(-0.3, 0, -1.2), Vector3(0.3, 0, -1.2), Vector3(-0.3, 0, 1.2), Vector3(0.3, 0, 1.2)]
 var coords := [Vector2(0, 0), Vector2(2.4, 0), Vector2(0, height if vertical else 1.4), Vector2(2.4, height if vertical else 1.4)]
 if column == 4: coords = [Vector2(-0.3, 0), Vector2(0.3, 0), Vector2(-0.3, 2.4), Vector2(0.3, 2.4)]
 for index: int in [0, 2, 1, 1, 2, 3]:
  surface.set_normal(Vector3.BACK if vertical else Vector3.UP)
  surface.set_uv(coords[index])
  surface.set_uv2(Vector2(0.0 if index % 2 == 0 else 1.0, coords[index].y))
  surface.add_vertex(positions[index])
 var result := MeshInstance3D.new()
 result.mesh = surface.commit()
 # Neutral pattern reference: keep production uniforms and procedural code,
 # but remove lighting from this private copy so colors are easy to compare.
 var sample: Material = mat.duplicate()
 if sample is ShaderMaterial:
  var shader := Shader.new()
  shader.code = sample.shader.code.replace("render_mode ", "render_mode unshaded, ")
  # Unshaded rendering omits EMISSION. Fold it into the preview color so neon
  # inserts remain represented, without halo effects obscuring their shapes.
  if shader.code.contains("EMISSION ="):
   var closing := shader.code.rfind("}")
   shader.code = shader.code.insert(closing, "ALBEDO = clamp(ALBEDO + EMISSION, vec3(0.0), vec3(1.0));\n")
  sample.shader = shader
 elif sample is StandardMaterial3D:
  sample.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 result.material_override = sample
 if column == 4: result.rotation.y = PI * 0.5
 return result

func run() -> void:
 if DisplayServer.get_name() == "headless":
  quit(1)
  return
 root.size = Vector2i(1780, 1400)
 root.content_scale_size = Vector2i(1780, 1400)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var canvas := CanvasLayer.new()
 root.add_child(canvas)
 var background := ColorRect.new()
 background.color = Color("101623")
 background.size = Vector2(1780, 1400)
 canvas.add_child(background)
 label(canvas, "FIVE ZONES / CURRENT SURFACE MATERIALS", Vector2(30, 20), 34)
 label(canvas, "Current shader patterns / neutral unlit copies / bloom + retro off. These previews are not tileable game assets.", Vector2(30, 66), 19)
 for column in 5:
  label(canvas, HEADINGS[column], Vector2(30 + column * 350, 109), 21)
 for row in Themes.IDS.size():
  var theme: RefCounted = Themes.create(Themes.IDS[row])
  var y := 155 + row * 235
  label(canvas, str(row + 1) + " / " + theme.display_name, Vector2(30, y), 25)
  var materials := [theme.floor_material, theme.top_material, theme.side_material, theme.cliff_material, theme.ramp_materials().deck]
  for column in 5:
   var container := SubViewportContainer.new()
   container.position = Vector2(30 + column * 350, y + 36)
   container.size = Vector2(320, 175)
   container.stretch = true
   canvas.add_child(container)
   var viewport := SubViewport.new()
   viewport.size = Vector2i(640, 350)
   viewport.own_world_3d = true
   viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
   container.add_child(viewport)
   var stage := Stage.new()
   viewport.add_child(stage)
   stage._world_environment = WorldEnvironment.new()
   stage._world_environment.environment = Environment.new()
   stage.add_child(stage._world_environment)
   stage._key_light = DirectionalLight3D.new()
   stage.add_child(stage._key_light)
   theme.configure_environment(stage)
   stage._world_environment.environment.glow_enabled = false
   stage._world_environment.environment.background_mode = Environment.BG_COLOR
   stage._world_environment.environment.background_color = Color("101623")
   stage.add_child(panel(materials[column], column))
   var camera := Camera3D.new()
   camera.projection = Camera3D.PROJECTION_ORTHOGONAL
   camera.keep_aspect = Camera3D.KEEP_WIDTH
   camera.size = 2.65
   stage.add_child(camera)
   if column in [2, 3]:
    var center := Vector3(0, -0.725 if column == 3 else 0, 0)
    camera.position = center + Vector3(0, 0, 4)
    camera.look_at(center)
   else:
    camera.position = Vector3(0, 4, 0.001)
    camera.look_at(Vector3.ZERO)
   camera.current = true
   views.append({"viewport": viewport, "path": OUTPUT + "/" + Themes.IDS[row] + "-" + KEYS[column] + ".png"})
 label(canvas, "A = playable floor   B = horizontal platform cap   C = raised wall face   D = cliff below table   E = ramp surface", Vector2(30, 1350), 20)
 for i in 20: await process_frame
 await RenderingServer.frame_post_draw
 var failures := 0
 for entry: Dictionary in views:
  if entry.viewport.get_texture().get_image().save_png(entry.path) != OK: failures += 1
 if root.get_texture().get_image().save_png(OUTPUT + "/all-surfaces.png") != OK: failures += 1
 print("RESULT | Surface catalogue | 25 swatches + sheet | ", failures, " failures")
 canvas.free()
 quit(1 if failures else 0)
