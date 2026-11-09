extends SceneTree
## Two views of the real disk-loaded Prototype session. No private material swaps.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
class ControlHost extends Node:
 var theme_id:="sky_sanctuary"
 var presentation:Node
var output := "res://experiments/sky_texture_choices/phase3/"
func _initialize() -> void:
 Engine.time_scale=0.0
 run.call_deferred()
func run() -> void:
 var ramp_review:=OS.get_cmdline_user_args().has("--ramp-review")
 var wall_review:=OS.get_cmdline_user_args().has("--wall-review")
 # Current comparisons use the canonical response by default. Historical albedo
 # review remains explicit, so this helper cannot silently restore flat materials.
 var response_review:=not OS.get_cmdline_user_args().has("--albedo-only")
 var canonical_review:=OS.get_cmdline_user_args().has("--canonical-review")
 var detail_enabled:=response_review and not OS.get_cmdline_user_args().has("--relief-off")
 var act:=Fixture.DEFAULT_ACT
 if ramp_review:
  act="res://data/acts/Authored/RampMania.tres"
  output="res://experiments/sky_texture_choices/phase3-ramp/"
 if wall_review: output="res://experiments/sky_texture_choices/phase3-walls/"
 if response_review:
  output="res://experiments/sky_texture_choices/phase4-ramp/" if ramp_review else "res://experiments/sky_texture_choices/phase4/"
  if not detail_enabled:output=output.trim_suffix("/")+"-off/"
 if canonical_review:output="res://experiments/sky_texture_choices/canonical/"
 root.size=Vector2i(1440,1000)
 root.gui_disable_input=true
 DirAccess.make_dir_recursive_absolute(output)
 preload("res://scripts/rendering_options.gd").settings_path=output+"isolated-graphics.cfg"
 var fixture:=Fixture.new()
 if not await fixture.open(self,act,"sky_sanctuary",output):
  push_error(fixture.error)
  await fixture.close()
  quit(1)
  return
 var game: Node=fixture.game
 game.hud.hide()
 var bound_count:=0
 var canonical_materials:Array[ShaderMaterial]=[]
 if canonical_review:
  # Inspect the actual default bindings without applying review overrides.
  var seen:Dictionary={}
  for node in game.find_children("*","GeometryInstance3D",true,false):
   var candidates:Array=[node.material_override,node.material_overlay]
   var mesh:Mesh=null
   if node is MeshInstance3D:
    mesh=node.mesh
    if mesh!=null:
     for i in mesh.get_surface_count():candidates.append(node.get_active_material(i))
   elif node is MultiMeshInstance3D and node.multimesh!=null:mesh=node.multimesh.mesh
   if mesh!=null:
    for i in mesh.get_surface_count():candidates.append(mesh.surface_get_material(i))
   for material in candidates:
    if not material is ShaderMaterial or not material.get_meta("sky_selected",false) or seen.has(material):continue
    seen[material]=true
    canonical_materials.append(material)
    if not is_equal_approx(float(material.get_shader_parameter("relief_strength")),.75) or not is_equal_approx(float(material.get_shader_parameter("detail_mix")),1.0):
     push_error("Canonical material default differs from approved response")
     await fixture.close()
     quit(1)
     return
  bound_count=seen.size()
 else:bound_count=preload("res://scripts/themes/sanctuary_selected_materials.gd").set_detail(game,detail_enabled)
 if bound_count==0:
  push_error("No bound Sky Sanctuary materials received response controls")
  await fixture.close()
  quit(1)
  return
 var receipt: Dictionary=fixture.receipt.duplicate(true)
 receipt["textures"]=fixture.texture_evidence()
 print("SKY_TEXTURE_EVIDENCE | ",JSON.stringify(receipt.textures))
 var expected:Array=["1A","2B","3B","5A","6A","9B"]
 if ramp_review: expected.append_array(["7B","8A"])
 if response_review:
  for id: String in expected.duplicate():expected.append_array([id+"_normal",id+"_roughness"])
 var found:Array=[]
 for entry:Dictionary in receipt.textures: found.append(str(entry.source).get_file().get_basename())
 var missing:=expected.filter(func(id:String):return id not in found)
 if not fixture.error.is_empty() or not missing.is_empty():
  push_error("Selected texture evidence incomplete: "+fixture.error+" / "+str(receipt.textures.size()))
  await fixture.close()
  quit(1)
  return
 receipt["views"]={}
 var views:Array=["close"] if ramp_review else ["gameplay","close"]
 if response_review and not ramp_review: views=["gameplay","wall"]
 if canonical_review:views=["gameplay"]
 if wall_review:
  views=["wall","facade","transition"]
  game.presentation.set_process(false)
  for node in game.active.visual.find_children("*","MeshInstance3D",true,false):
   if node.mesh is ArrayMesh and node.mesh.get_surface_count()>1:
    print("WALL_BOUNDS | ",node.name," | ",node.global_transform*node.get_aabb())
 for view: String in views:
  if wall_review or view=="wall":
   game.presentation.set_process(false)
   var poses:Dictionary={
    "wall":[Vector3(3.7,0.65,4.8),Vector3(4.8,0.16,4.5)],
    "facade":[Vector3(10.3,0.7,7.0),Vector3(8.0,-0.45,5.6)],
    "transition":[Vector3(4.2,1.3,4.4),Vector3(5.6,0.23,3.5)]}
   game.presentation.camera.global_position=poses[view][0]
   game.presentation.camera.look_at(poses[view][1],Vector3.UP)
   game._update_backgrounds()
  if view=="close":
   game.presentation.set_camera_value("zoom",1.8 if ramp_review else 2.2)
   game.presentation.reset_camera(Vector2(350,330) if ramp_review else game.ball.position+Vector2(0,-100))
   game._process(0.0)
  for frame in 16: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output+view+".png")
  receipt.views[view]=fixture.state()
 if not fixture.still_current():
  print("FRESHNESS | pipeline ",fixture.Bake.pipeline_hash("sky_sanctuary")," expected ",receipt.pipeline_fingerprint," | scenery ",fixture.Bake.ScenerySettings.signature(act,"sky_sanctuary")," expected ",receipt.scenery_fingerprint," | act ",FileAccess.get_sha256(receipt.act_bake)," expected ",receipt.act_bake_sha256," | theme ",FileAccess.get_sha256(receipt.theme_bake)," expected ",receipt.theme_bake_sha256)
  push_error("Production bake changed during the visual review")
  await fixture.close()
  quit(1)
  return
 receipt["hud_hidden"]=true
 receipt["relief"]=detail_enabled
 receipt["bound_material_controls"]=bound_count
 if canonical_review:
  # Exercise the real authoring control signals against live baked/private
  # resources, then restore approved defaults before closing the isolated game.
  var host:=ControlHost.new()
  host.presentation=game
  root.add_child(host)
  var controls:=preload("res://experiments/sky_texture_choices/live_controls.gd").new()
  host.add_child(controls)
  controls.install(host)
  controls.hide()
  var controls_valid:=true
  controls.detail.button_pressed=false
  for material in canonical_materials:
   controls_valid=controls_valid and is_zero_approx(float(material.get_shader_parameter("relief_strength"))) and is_zero_approx(float(material.get_shader_parameter("detail_mix")))
  controls.strength.value=1.25
  controls.detail.button_pressed=true
  for material in canonical_materials:
   controls_valid=controls_valid and is_equal_approx(float(material.get_shader_parameter("relief_strength")),.9375) and is_equal_approx(float(material.get_shader_parameter("detail_mix")),1.0)
  controls.strength.value=1.0
  host.free()
  if not controls_valid:
   push_error("Material controls did not update all live bindings")
   await fixture.close()
   quit(1)
   return
  receipt["material_controls_verified"]=true
  var lab_scene:PackedScene=load("res://experiments/visual_lab/visual_lab.tscn")
  if lab_scene==null:
   push_error("Material lab did not load")
   await fixture.close()
   quit(1)
   return
  var paths:Array=preload("res://scripts/prototype/run_plan.gd").source_paths()
  paths.append_array(preload("res://scripts/endless/endless_plan.gd").PATHS)
  receipt["current_sky_bakes"]=[]
  for path:String in paths:
   var document:Resource=fixture.Document.load_document(path).document
   var bake:Resource=load(fixture.Bake.path_for(path,"sky_sanctuary"))
   if bake==null or not bake.matches(document,"sky_sanctuary",receipt.pipeline_fingerprint):
    push_error("Canonical Sky bake is stale: "+path)
    await fixture.close()
    quit(1)
    return
   receipt.current_sky_bakes.append(path)
 var file:=FileAccess.open(output+"receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 print("SKY_PHASE3 | ",receipt.textures.size()," source PNG matches | disk-loaded Prototype | ",views.size()," views")
 await fixture.close()
 quit()
