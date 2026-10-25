extends SceneTree
## Presentation-only asset contact sheet. Uses the production Chemical Plant
## library and lighting without creating a game, ball, physics world, or Act.
const ChemicalDecor = preload("res://scripts/decor/chemical_plant_decor.gd")
const ChemicalTheme = preload("res://scripts/themes/chemical_plant_theme.gd")
const OUTPUT := "res://test-results/theme-review/chemical-library.png"
const VARIANTS := ["beacon", "valve", "vent", "pump_elbow", "control_cabinet", "fluid_canister", "pipe_cluster", "tank_tower", "girder_machinery", "fluid_reactor", "pipe_arch"]

class DisplayStage extends Node3D:
 var _world_environment: WorldEnvironment
 var _key_light: DirectionalLight3D

var labels: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func _material(color: Color) -> StandardMaterial3D:
 var result := StandardMaterial3D.new()
 result.albedo_color = color
 result.roughness = 0.85
 return result

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
 var mesh := BoxMesh.new()
 mesh.size = size
 var instance := MeshInstance3D.new()
 instance.mesh = mesh
 instance.material_override = material
 instance.position = at
 instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(instance)

func _text(parent: Node, text: String, at: Vector2, width: float, size: int, color: Color, centered := false) -> Label:
 var label := Label.new()
 label.text = text
 label.position = at
 label.size = Vector2(width, 32)
 label.add_theme_font_size_override("font_size", size)
 label.add_theme_color_override("font_color", color)
 label.add_theme_color_override("font_outline_color", Color("080e1f"))
 label.add_theme_constant_override("outline_size", 3)
 label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
 parent.add_child(label)
 return label

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Chemical Plant library capture requires a graphical renderer.")
  quit(1)
  return
 root.size = Vector2i(1600, 1000)
 var stage := DisplayStage.new()
 root.add_child(stage)
 stage._world_environment = WorldEnvironment.new()
 stage._world_environment.environment = Environment.new()
 stage.add_child(stage._world_environment)
 stage._key_light = DirectionalLight3D.new()
 stage.add_child(stage._key_light)
 var theme := ChemicalTheme.new()
 theme.configure_environment(stage)
 var library := ChemicalDecor.new(stage)
 var plinth_material := _material(Color("283c55"))
 var trim_material := _material(Color("547788"))
 var ground_material := _material(Color("0c172b"))
 _box(stage, Vector3(0, -0.34, 0), Vector3(40, 0.2, 30), ground_material)
 for i in VARIANTS.size():
  var back_row := i < 6
  var index := i if back_row else i - 6
  var anchor := Vector3((index - 2.5) * 2.35, 0, -2.75) if back_row else Vector3((index - 2.0) * 3.2, 0, 2.4)
  var display_scale := 2.0 if i < 3 else (1.4 if i < 6 else 1.0)
  var category := "SMALL" if i < 3 else ("MEDIUM" if i < 6 else ("LARGE" if i < 9 else "LANDMARK"))
  var plinth_width := 3.1 if i >= 9 else (1.95 if back_row else 2.25)
  _box(stage, anchor + Vector3(0, -0.10, 0), Vector3(plinth_width, 0.20, 1.6), plinth_material)
  _box(stage, anchor + Vector3(0, -0.02, 0.80), Vector3(plinth_width, 0.035, 0.025), trim_material)
  var prop: Node3D = library.build_variant(VARIANTS[i])
  prop.position = anchor
  prop.scale = Vector3.ONE * display_scale
  stage.add_child(prop)
  labels.append({"name": VARIANTS[i].capitalize(), "category": category, "position": anchor + Vector3(0, -0.16, 1.0)})
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.keep_aspect = Camera3D.KEEP_WIDTH
 camera.size = 17.8
 camera.position = Vector3(0, 10, 17)
 stage.add_child(camera)
 camera.look_at(Vector3(0, 0.25, 0))
 camera.current = true
 var canvas := CanvasLayer.new()
 root.add_child(canvas)
 _text(canvas, "CHEMICAL PLANT", Vector2(56, 36), 1300, 38, Color("e1f3ff"))
 _text(canvas, "Original low-poly prop library  /  Production theme lighting  /  Filter off", Vector2(58, 88), 1450, 21, Color("9db9d8"))
 _text(canvas, "11 collisionless props  •  Shared primitive meshes and materials  •  Static emissive liquid and transparent shells", Vector2(58, 906), 1450, 20, Color("adc1da"))
 _text(canvas, "Small props shown at 2× and medium at 1.4× for inspection; large props and landmarks shown at 1×.", Vector2(58, 940), 1450, 18, Color("6f8ba9"))
 for i in 8: await process_frame
 for item: Dictionary in labels:
  var screen: Vector2 = camera.unproject_position(item.position)
  _text(canvas, item.name, screen + Vector2(-120, 0), 240, 20, Color("e1f3ff"), true)
  _text(canvas, item.category, screen + Vector2(-120, 27), 240, 14, Color("61c9d5"), true)
 for i in 12: await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
 var result := root.get_texture().get_image().save_png(OUTPUT)
 print("RESULT | Chemical Plant library capture | ", OUTPUT, " | ", error_string(result))
 stage.free()
 canvas.free()
 quit(0 if result == OK else 1)
