extends SceneTree
## Focused graphical check of the real Visual Lab controls, not appearance evidence.
const OUTPUT := "res://experiments/aquarium_texture_refined/final_review/"
func _initialize() -> void:
 Engine.time_scale=0.0
 run.call_deferred()
func bound_materials(root_node: Node) -> Array[ShaderMaterial]:
 var found: Array[ShaderMaterial]=[]
 for node: Node in root_node.find_children("*","GeometryInstance3D",true,false):
  var candidates: Array[Material]=[node.material_override,node.material_overlay]
  var mesh: Mesh=null
  if node is MeshInstance3D:
   mesh=node.mesh
   if mesh!=null:
    for i in mesh.get_surface_count():candidates.append(node.get_active_material(i))
  elif node is MultiMeshInstance3D and node.multimesh!=null:mesh=node.multimesh.mesh
  if mesh!=null:
   for i in mesh.get_surface_count():candidates.append(mesh.surface_get_material(i))
  for material: Material in candidates:
   if material is ShaderMaterial and material.get_meta("aquarium_selected",false) and material not in found:found.append(material)
 return found
func run() -> void:
 root.size=Vector2i(1200,800)
 root.gui_disable_input=true
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 preload("res://scripts/rendering_options.gd").settings_path=OUTPUT+"isolated-controls-graphics.cfg"
 var game: Node=load("res://experiments/visual_lab/visual_lab.tscn").instantiate()
 game.theme_id="aquarium_park"
 root.add_child(game)
 for frame in 8:await process_frame
 game.controls.input_blocked=true
 game.ball.freeze=true
 var panel: CanvasLayer=game.aquarium_materials
 var materials := bound_materials(game.presentation)
 var success := materials.size()>0
 var event := InputEventKey.new()
 event.physical_keycode=KEY_F8
 event.pressed=true
 game._input(event)
 success=success and panel.panel.visible
 panel.detail.button_pressed=false
 for material: ShaderMaterial in materials:
  success=success and is_zero_approx(float(material.get_shader_parameter("relief_strength"))) and is_zero_approx(float(material.get_shader_parameter("detail_mix")))
 panel.detail.button_pressed=true
 panel.strength.value=.5
 for material: ShaderMaterial in materials:
  success=success and is_equal_approx(float(material.get_shader_parameter("relief_strength")),float(material.get_meta("normal_strength"))*.5)
 panel.strength.value=1.0
 panel.panel.hide()
 for material: ShaderMaterial in materials:
  success=success and is_equal_approx(float(material.get_shader_parameter("relief_strength")),float(material.get_meta("normal_strength"))) and is_equal_approx(float(material.get_shader_parameter("detail_mix")),1.0)
 var file := FileAccess.open(OUTPUT+"controls-receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":success,"authority":"Visual Lab authoring controls only","bound_materials":materials.size(),"checks":["F8 opens Aquarium panel","detail-off reaches bindings","strength signal reaches bindings","defaults restored and panel hidden"]},"  "))
 print("AQUARIUM_CONTROLS | pass=",success," | bound materials=",materials.size()," | defaults restored")
 game.free()
 quit(0 if success else 1)
