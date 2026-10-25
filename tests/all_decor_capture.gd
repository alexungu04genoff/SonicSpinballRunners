extends SceneTree
## Complete production prop catalogue, including variants exclusive to one hint.
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Presentation = preload("res://scripts/themes/themed_presentation.gd")
const OUTPUT := "res://test-results/all-decor.png"

func _initialize() -> void:
 call_deferred("run")

func label(parent: Node, text: String, at: Vector2, size: int) -> void:
 var caption := Label.new()
 caption.text = text
 caption.position = at
 caption.add_theme_font_size_override("font_size", size)
 caption.add_theme_color_override("font_color", Color("fff0cc"))
 parent.add_child(caption)

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("The decor catalogue requires a graphical renderer.")
  quit(1)
  return
 root.size = Vector2i(2100, 120 + Themes.IDS.size() * 625 + 55)
 root.content_scale_size = root.size
 var canvas := CanvasLayer.new()
 root.add_child(canvas)
 var background := ColorRect.new()
 background.size = Vector2(root.size)
 background.color = Color("142b38")
 canvas.add_child(background)
 label(canvas, "SONIC SPINBALL RUNNERS / COMPLETE DECOR LIBRARY", Vector2(35, 20), 36)
 label(canvas, "Every authored prop in all themes, including hint-specific variants. Production lighting / Filter off", Vector2(35, 70), 22)
 var total := 0
 for theme_index in Themes.IDS.size():
  var theme: RefCounted = Themes.create(Themes.IDS[theme_index])
  var catalogue := Presentation.new()
  catalogue.set_theme_definition(theme)
  var variants: Array[Dictionary] = []
  var seen: Dictionary = {}
  for size: String in ["small", "medium", "large", "landmark"]:
   for hint: String in ["surface", "edge", "either"]:
    for variant: String in catalogue.decor_skin.variants_for({"slot_type": size, "placement_hint": hint}):
     if seen.has(variant): continue
     seen[variant] = true
     variants.append({"variant": variant, "size": size, "hint": hint})
  var section_y := 120 + theme_index * 625
  label(canvas, "%s / %d VARIANTS" % [theme.display_name.to_upper(), variants.size()], Vector2(35, section_y), 30)
  for i in variants.size():
   var item := variants[i]
   var at := Vector2(35 + (i % 7) * 292, section_y + 52 + (i / 7) * 276)
   var container := SubViewportContainer.new()
   container.position = at
   container.size = Vector2(275, 218)
   canvas.add_child(container)
   var viewport := SubViewport.new()
   viewport.size = Vector2i(275, 218)
   viewport.own_world_3d = true
   viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
   container.add_child(viewport)
   var p := Presentation.new()
   p.set_theme_definition(Themes.create(Themes.IDS[theme_index]))
   viewport.add_child(p)
   p._world_environment = WorldEnvironment.new()
   p._world_environment.environment = Environment.new()
   p.add_child(p._world_environment)
   p._key_light = DirectionalLight3D.new()
   p.add_child(p._key_light)
   p.theme_definition.configure_environment(p)
   p._world_environment.environment.background_mode = Environment.BG_COLOR
   p._world_environment.environment.background_color = Color("294451")
   var prop: Node3D = p.decor_skin.factory.call(item.variant)
   if prop == null:
    push_error("Missing catalogue prop: " + item.variant)
    quit(1)
    return
   p.add_child(prop)
   prop.scale = Vector3.ONE * (2.0 if item.size == "small" else (1.5 if item.size == "medium" else 1.0))
   var camera := Camera3D.new()
   camera.projection = Camera3D.PROJECTION_ORTHOGONAL
   camera.keep_aspect = Camera3D.KEEP_WIDTH
   camera.size = 3.9 if item.size in ["large", "landmark"] else 2.4
   camera.position = Vector3(1.4, 3.1, 6.0)
   p.add_child(camera)
   camera.look_at(Vector3(0, 0.95 if item.size in ["large", "landmark"] else 0.40, 0))
   camera.current = true
   label(canvas, str(item.variant).capitalize(), at + Vector2(0, 221), 23)
   label(canvas, str(item.size).to_upper() + (" / EDGE" if item.variant == "palm_left" else ""), at + Vector2(0, 250), 16)
   total += 1
  catalogue.free()
 label(canvas, "%d original collisionless props. Small: 2x / Medium: 1.5x / Large and landmarks: 1x." % total, Vector2(35, root.size.y - 40), 21)
 for frame in 14: await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
 var result := root.get_texture().get_image().save_png(OUTPUT)
 print("RESULT | All decor catalogue | %d props | %s" % [total, error_string(result)])
 canvas.free()
 quit(0 if result == OK else 1)
