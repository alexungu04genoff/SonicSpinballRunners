extends SceneTree
## Lightweight landmark regression and optional production-material contact sheet.
const Presentation = preload("res://scripts/themes/themed_presentation.gd")
const GreenHillTheme = preload("res://scripts/themes/green_hill_theme.gd")
const Slots = preload("res://scripts/act_editor/decor_slots.gd")
const OUTPUT := "res://test-results/green-hill-landmarks"
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 checks += 1
 if ok: print("PASS | ", message)
 else:
  failures += 1
  push_error("FAIL | " + message)

func valid_visual(node: Node) -> bool:
 if not node is Node3D or node is CollisionObject3D or node is CollisionShape3D: return false
 if node is MeshInstance3D:
  if node.mesh == null or not node.transform.is_finite(): return false
  var faces: PackedVector3Array = node.mesh.get_faces()
  if faces.is_empty(): return false
  for i in range(0, faces.size(), 3):
   var a := faces[i]
   var b := faces[i + 1]
   var c := faces[i + 2]
   if not a.is_finite() or not b.is_finite() or not c.is_finite(): return false
   if (b - a).cross(c - a).length_squared() < 0.000000000001: return false
 for child in node.get_children():
  if not valid_visual(child): return false
 return true

func label(canvas: Node, text: String, at: Vector2, size: int) -> void:
 var caption := Label.new()
 caption.text = text
 caption.position = at
 caption.add_theme_font_size_override("font_size", size)
 caption.add_theme_color_override("font_color", Color("eef8e6"))
 caption.add_theme_color_override("font_outline_color", Color("132c36"))
 caption.add_theme_constant_override("outline_size", 4)
 canvas.add_child(caption)

func run() -> void:
 root.size = Vector2i(1400, 900)
 var stage := Presentation.new()
 stage.set_theme_definition(GreenHillTheme.new())
 root.add_child(stage)
 var library: RefCounted = stage.decor_skin
 var slot := Slots.make_slot("landmark")
 slot.variant_mode = "fixed"
 var source := slot.duplicate(true)
 for hint: String in Slots.HINTS:
  slot.placement_hint = hint
  check(library.variants_for(slot) == ["turf_loop", "rope_bridge"], "Stable loop index and appended bridge: " + hint)
  for index in 2:
   slot.variant_index = index
   var prop: Node3D = library.instantiate_slot("landmark-regression", slot)
   check(prop != null and valid_visual(prop), "Finite nondegenerate collisionless geometry: %s / %d" % [hint, index])
   check(prop.get_meta("decor_variant") == ["turf_loop", "rope_bridge"][index], "Fixed index resolves to intended landmark")
   prop.free()
 source.variant_mode = "auto"
 var before := source.duplicate(true)
 check(library.resolve("stable", source) == library.resolve("stable", source) and source == before, "Auto remains deterministic and leaves Act fields untouched")
 if DisplayServer.get_name() != "headless":
  var environment := WorldEnvironment.new()
  environment.environment = Environment.new()
  stage.add_child(environment)
  stage.add_child(DirectionalLight3D.new())
  stage.theme_definition.configure_environment(stage)
  for i in 2:
   slot.variant_index = i
   var prop: Node3D = library.instantiate_slot("contact-sheet", slot)
   stage.add_child(prop)
   prop.position.x = -1.9 if i == 0 else 1.9
  var camera := Camera3D.new()
  camera.projection = Camera3D.PROJECTION_ORTHOGONAL
  camera.keep_aspect = Camera3D.KEEP_WIDTH
  camera.size = 8.0
  stage.add_child(camera)
  camera.current = true
  var canvas := CanvasLayer.new()
  root.add_child(canvas)
  label(canvas, "GREEN HILL  /  LANDMARKS", Vector2(45, 32), 34)
  label(canvas, "Variant 1 — Turf Loop", Vector2(80, 755), 28)
  label(canvas, "Variant 2 — Rope Bridge", Vector2(775, 755), 28)
  label(canvas, "Production materials and lighting  •  Collisionless scenery  •  Filter off", Vector2(45, 840), 20)
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
  for angle: String in ["front", "three-quarter"]:
   camera.position = Vector3(0, 2.25, 10) if angle == "front" else Vector3(3.3, 4.5, 10)
   camera.look_at(Vector3(0, 0.85, 0))
   for frame in 12: await process_frame
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(OUTPUT.path_join(angle + ".png")) == OK, "Rendered landmark view: " + angle)
  canvas.free()
 stage.free()
 print("RESULT | Green Hill landmarks | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)
