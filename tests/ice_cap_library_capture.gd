extends SceneTree
## Review sheet rendered from the production library and moonlight settings.
const IceTheme = preload("res://scripts/themes/ice_cap_theme.gd")
const OUTPUT := "res://test-results/ice-review/ice-library.png"

class DisplayStage extends Node3D:
 var _world_environment: WorldEnvironment
 var _key_light: DirectionalLight3D

func _initialize() -> void:
 call_deferred("run")

func label(canvas: Node, text: String, at: Vector2, width: float, size: int, centered := false) -> void:
 var control := Label.new()
 control.text = text
 control.position = at
 control.size = Vector2(width, 36)
 control.add_theme_font_size_override("font_size", size)
 control.add_theme_color_override("font_color", Color("ffe8be"))
 control.add_theme_color_override("font_outline_color", Color("253f49"))
 control.add_theme_constant_override("outline_size", 4)
 control.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
 canvas.add_child(control)

func run() -> void:
 if DisplayServer.get_name() == "headless":
  quit(1)
  return
 root.size = Vector2i(1600, 1385)
 root.content_scale_size = Vector2i(1600, 1385)
 var canvas := CanvasLayer.new()
 root.add_child(canvas)
 var background := ColorRect.new()
 background.color = Color("243e50")
 background.size = Vector2(1600, 1385)
 canvas.add_child(background)
 var theme := IceTheme.new()
 var library: RefCounted = theme.create_decor(null)
 var sizes := ["small", "medium", "large", "landmark"]
 for row in 4:
  for column in 4:
   var type: String = sizes[column]
   if row >= library.pools[type].surface.size(): continue
   var variant: String = library.pools[type].surface[row]
   var at := Vector2(50 + column * 380, 150 + row * 285)
   var container := SubViewportContainer.new()
   container.position = at
   container.size = Vector2(360, 215)
   container.stretch = true
   canvas.add_child(container)
   var viewport := SubViewport.new()
   viewport.size = Vector2i(360, 215)
   viewport.own_world_3d = true
   viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
   container.add_child(viewport)
   var stage := DisplayStage.new()
   viewport.add_child(stage)
   stage._world_environment = WorldEnvironment.new()
   stage._world_environment.environment = Environment.new()
   stage.add_child(stage._world_environment)
   stage._key_light = DirectionalLight3D.new()
   stage._key_light.shadow_enabled = true
   stage._key_light.directional_shadow_max_distance = 12.0
   stage.add_child(stage._key_light)
   theme.configure_environment(stage)
   stage._world_environment.environment.background_mode = Environment.BG_COLOR
   stage._world_environment.environment.background_color = Color("547184")
   var plinth: MeshInstance3D = library.box(stage, "deep", Vector3(0, -0.08, 0), Vector3(3.2 if column == 3 else 2.25, 0.16, 1.6))
   plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   var prop: Node3D = library.build_variant(variant)
   stage.add_child(prop)
   prop.rotation_degrees.y = -16.0
   prop.scale = Vector3.ONE * (2.1 if column == 0 else (1.6 if column == 1 else 1.0))
   var camera := Camera3D.new()
   camera.projection = Camera3D.PROJECTION_ORTHOGONAL
   camera.keep_aspect = Camera3D.KEEP_HEIGHT
   camera.size = 3.0 if column == 3 else 2.65
   camera.position = Vector3(0, 3.1, 5.0)
   stage.add_child(camera)
   camera.look_at(Vector3(0, 1.0 if column == 3 else 0.85, 0))
   camera.current = true
   label(canvas, variant.capitalize(), at + Vector2(0, 219), 360, 21, true)
   label(canvas, type.to_upper() + " / " + str(row + 1), at + Vector2(0, 247), 360, 14, true)
 label(canvas, "ICE CAP  /  TWILIGHT GLACIER", Vector2(50, 30), 1500, 38)
 label(canvas, "13 original procedural props  /  Production moonlight  /  Filter off", Vector2(52, 82), 1500, 22)
 label(canvas, "Small shown at 2.1x, medium at 1.6x; large and landmark at 1x. All props honor exact authored yaw.", Vector2(52, 1330), 1500, 20)
 for i in 10: await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
 var result := root.get_texture().get_image().save_png(OUTPUT)
 print("RESULT | Ice Cap library | ", error_string(result))
 canvas.free()
 quit(0 if result == OK else 1)
