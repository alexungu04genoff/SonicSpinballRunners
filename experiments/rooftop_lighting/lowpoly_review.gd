extends "res://experiments/rooftop_lighting/review.gd"
## Presentation-only art comparison; uses the existing frozen-scene harness.
const MODES := [1, 2, 5, 7, 8]
const TITLES := {1: "Flat floor", 2: "Edge-only normal", 5: "Smooth convex", 7: "Beveled block", 8: "Faceted stone"}
const FILES := {1: "flat", 2: "edge-only", 5: "smooth-convex", 7: "beveled-block", 8: "faceted-stone"}
const POLY_SLIDERS := {"lowpoly_normal_strength": ["Normal strength", 0.0, 2.0], "lowpoly_mortar_depth": ["Mortar depth", 0.0, 2.0], "lowpoly_detail_intensity": ["Bevel / facet intensity", 0.0, 2.0], "lowpoly_variation": ["Per-stone variation", 0.0, 1.0]}
var poly_materials := {}
var poly_sliders := {}
var poly_numbers := {}
var study_view := "gameplay"
var preset_name := "gameplay-safe"

func run() -> void:
 output_path = OUTPUT + "lowpoly-study/"
 DirAccess.make_dir_recursive_absolute(output_path)
 await super.run()
 set_study_view("gameplay")
 var act := "res://experiments/rooftop_lighting/existing_act.tres"
 var source := FileAccess.get_file_as_bytes(act)
 var document: String = game.authored_document.fingerprint()
 var ball_id: int = game.ball.get_instance_id()
 if "--capture-lowpoly" in OS.get_cmdline_user_args():
  for view_name in ["gameplay", "close"]:
   set_study_view(view_name)
   set_strength_preset(false)
   for mode in MODES:
    apply_mode(mode)
    await frames(10)
    await capture(view_name + "-" + FILES[mode] + "-safe")
   set_strength_preset(true)
   for mode in [7, 8]:
    apply_mode(mode)
    await frames(10)
    await capture(view_name + "-" + FILES[mode] + "-diagnostic")
  settings.lowpoly_normal_strength = 0.0
  for mode in [7, 8]:
   apply_mode(mode)
   await frames(8)
   await capture("zero-" + FILES[mode])
  if source != FileAccess.get_file_as_bytes(act) or document != game.authored_document.fingerprint() or ball_id != game.ball.get_instance_id(): failures += 1
  report["failures"] = failures
  report["document"] = document
  report["renderer"] = RenderingServer.get_current_rendering_method()
  FileAccess.open(output_path + "validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
  print("RESULT | Low-poly normal review | ", failures, " failures")
  quit(1 if failures else 0)
 elif "--lowpoly-controls-smoke" in OS.get_cmdline_user_args():
  walk(root.get_node("LowPolyControls"), func(node: Node) -> void:
   if node is Button: node.pressed.emit()
   if node is HSlider:
    var previous: float = node.value
    node.value = previous + 0.05
    node.value = previous
  )
  set_strength_preset(false)
  apply_mode(8)
  set_study_view("close")
  await frames(8)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output_path + "controls.png")
  var valid := geometry_fingerprint() == baseline_geometry
  print("RESULT | Low-poly controls | ", "PASS" if valid else "FAIL")
  quit(0 if valid else 1)

func set_study_view(view_name: String) -> void:
 study_view = view_name
 var camera: Camera3D = game.presentation.camera
 if view_name == "gameplay":
  camera.transform = gameplay_camera_state.transform
  camera.projection = gameplay_camera_state.projection
  camera.fov = gameplay_camera_state.fov
  camera.size = gameplay_camera_state.size
 else:
  camera.projection = Camera3D.PROJECTION_PERSPECTIVE
  camera.fov = 44
  set_review_camera(true)
 baseline_camera = camera.transform

func set_strength_preset(diagnostic: bool) -> void:
 preset_name = "diagnostic" if diagnostic else "gameplay-safe"
 settings.lowpoly_normal_strength = 1.0 if diagnostic else 0.55
 settings.lowpoly_mortar_depth = 1.0 if diagnostic else 0.65
 settings.lowpoly_detail_intensity = 1.0 if diagnostic else 0.65
 settings.lowpoly_variation = 0.25 if diagnostic else 0.15
 for property in poly_sliders:
  poly_sliders[property].set_value_no_signal(settings.get(property))
  poly_numbers[property].text = "%.2f" % settings.get(property)
 apply_mode(selected)

func apply_mode(mode: int) -> void:
 super.apply_mode(mode if mode in [1, 2, 5] else 1)
 selected = mode
 if mode in [7, 8]:
  var material: ShaderMaterial = poly_materials[mode]
  material.set_shader_parameter("normal_strength", settings.lowpoly_normal_strength)
  material.set_shader_parameter("mortar_depth", settings.lowpoly_mortar_depth)
  material.set_shader_parameter("detail_intensity", settings.lowpoly_detail_intensity)
  material.set_shader_parameter("variation_amount", settings.lowpoly_variation)
  for slot in slots:
   if slot.material != floor_material: continue
   if slot.surface == -1: slot.node.material_override = material
   else: slot.node.set_surface_override_material(slot.surface, material)
 if is_instance_valid(label): label.text = str(TITLES[mode]) + " | " + preset_name + " | Approved lighting, flat mesh"

func capture(name: String) -> void:
 await super.capture(name)
 var camera: Camera3D = game.presentation.camera
 report[name]["projection"] = camera.projection
 report[name]["orthogonal_size"] = camera.size
 report[name]["lighting"] = [str(game.presentation._key_light.rotation_degrees), settings.key_energy, settings.ambient_energy, settings.ssao_intensity, settings.exposure]
 report[name]["normal_controls"] = [settings.lowpoly_normal_strength, settings.lowpoly_mortar_depth, settings.lowpoly_detail_intensity, settings.lowpoly_variation]
 report[name]["mode"] = TITLES[selected]

func build_controls() -> void:
 for mode in [7, 8]:
  var material := ShaderMaterial.new()
  material.shader = preload("res://experiments/rooftop_lighting/lowpoly_floor.gdshader")
  material.set_shader_parameter("surface_texture", floor_material.get_shader_parameter("surface_texture"))
  material.set_shader_parameter("mortar_normal", preload("res://experiments/rooftop_lighting/lowpoly_mortar_normal.png"))
  material.set_shader_parameter("detail_normal", load("res://experiments/rooftop_lighting/lowpoly_" + ("block" if mode == 7 else "faceted") + "_basis.png"))
  poly_materials[mode] = material
 var layer := CanvasLayer.new()
 layer.name = "LowPolyControls"
 layer.layer = 100
 layer.process_mode = Node.PROCESS_MODE_ALWAYS
 root.add_child(layer)
 var panel := PanelContainer.new()
 panel.position = Vector2(8, 8)
 layer.add_child(panel)
 var column := VBoxContainer.new()
 panel.add_child(column)
 label = Label.new()
 column.add_child(label)
 var modes := HBoxContainer.new()
 column.add_child(modes)
 for mode in MODES:
  var button := Button.new()
  button.text = str(MODES.find(mode) + 1) + ". " + TITLES[mode]
  button.pressed.connect(apply_mode.bind(mode))
  modes.add_child(button)
 var actions := HBoxContainer.new()
 column.add_child(actions)
 var gameplay := Button.new()
 gameplay.text = "Gameplay-safe strength"
 gameplay.pressed.connect(set_strength_preset.bind(false))
 actions.add_child(gameplay)
 var diagnostic := Button.new()
 diagnostic.text = "Diagnostic strength"
 diagnostic.pressed.connect(set_strength_preset.bind(true))
 actions.add_child(diagnostic)
 var view_button := Button.new()
 view_button.text = "Gameplay camera / close-up"
 view_button.pressed.connect(func() -> void: set_study_view("close" if study_view == "gameplay" else "gameplay"))
 actions.add_child(view_button)
 var controls := VBoxContainer.new()
 var toggle := Button.new()
 toggle.text = "Show / hide normal controls"
 toggle.pressed.connect(func() -> void: controls.visible = not controls.visible)
 column.add_child(toggle)
 column.add_child(controls)
 controls.hide()
 var note := Label.new()
 note.text = "Controls affect the two new variants. Earlier comparisons retain their original settings."
 controls.add_child(note)
 for property in POLY_SLIDERS:
  var entry: Array = POLY_SLIDERS[property]
  var row := HBoxContainer.new()
  controls.add_child(row)
  var caption := Label.new()
  caption.text = entry[0]
  caption.custom_minimum_size.x = 220
  row.add_child(caption)
  var slider := HSlider.new()
  slider.min_value = entry[1]
  slider.max_value = entry[2]
  slider.step = 0.01
  slider.value = settings.get(property)
  slider.custom_minimum_size.x = 240
  var number := Label.new()
  number.text = "%.2f" % slider.value
  number.custom_minimum_size.x = 50
  slider.value_changed.connect(func(value: float) -> void:
   settings.set(property, value)
   number.text = "%.2f" % value
   preset_name = "custom"
   apply_mode(selected)
  )
  row.add_child(slider)
  row.add_child(number)
  poly_sliders[property] = slider
  poly_numbers[property] = number
