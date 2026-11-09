extends SceneTree
## Production comparison. Historical albedo-only review requires --albedo-only.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Materials = preload("res://scripts/themes/lava_selected_materials.gd")
const OUTPUT := "res://experiments/lava_texture_refined/phase3/"

func _initialize() -> void:
 Engine.time_scale=0.0
 call_deferred("run")

func run() -> void:
 root.size=Vector2i(1440,1000)
 root.gui_disable_input=true
 var options := preload("res://scripts/rendering_options.gd")
 options.settings_path=OUTPUT+"isolated-graphics.cfg"
 var fixture := Fixture.new()
 var act := Fixture.DEFAULT_ACT
 var label := "gameplay"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--act="): act=argument.trim_prefix("--act=")
  if argument.begins_with("--label="): label=argument.trim_prefix("--label=")
 if not await fixture.open(self,act,"lava_reef",OUTPUT):
  push_error(fixture.error)
  await fixture.close()
  quit(1)
  return
 fixture.game.hud.hide()
 var albedo_only:=OS.get_cmdline_user_args().has("--albedo-only")
 if albedo_only:Materials.set_detail(fixture.game,false)
 for frame in 12: await process_frame
 await RenderingServer.frame_post_draw
 var evidence := fixture.texture_evidence()
 var ids: Array[String]=[]
 for entry: Dictionary in evidence: ids.append(str(entry.source).get_file().get_basename())
 var expected := ["1C","2A","3B","5B","6B","9B"]
 if act.get_file()=="RampMania.tres": expected.append_array(["7A","8B"])
 if not albedo_only:
  for id: String in expected.duplicate():expected.append_array([id+"_normal",id+"_roughness"])
 var missing: Array[String]=[]
 for id: String in expected:
  if not ids.has(id): missing.append(id)
 if not fixture.error.is_empty() or not missing.is_empty() or not fixture.still_current() or not fixture.authority_error().is_empty():
  push_error("Lava review evidence failed: "+fixture.error+" missing="+str(missing)+" authority="+fixture.authority_error())
  await fixture.close()
  quit(1)
  return
 var receipt: Dictionary=fixture.receipt.duplicate(true)
 receipt["current_texture_matches"]=evidence
 receipt["state"]=fixture.state()
 receipt["hud_hidden"]=true
 receipt["relief"]="Explicit historical albedo-only comparison" if albedo_only else "Canonical structural normals and roughness"
 receipt["selected_materials"]=[]
 var baked: Resource=fixture.game.library._act_bakes[fixture.game.library.key("lava_reef",0)]
 for resource: Resource in baked.retirement_dependencies:
  if resource is ShaderMaterial and resource.resource_name.begins_with("Lava Reef "):
   receipt.selected_materials.append({"name":resource.resource_name,"mapping":resource.get_shader_parameter("mapping"),
    "repeat_size":str(resource.get_shader_parameter("repeat_size")),"shader":"res://scripts/themes/lava_selected.gdshader"})
 var result := root.get_texture().get_image().save_png(OUTPUT+label+".png")
 var file := FileAccess.open(OUTPUT+label+"-receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 file.close()
 print("LAVA_REVIEW | disk Prototype | current textures=",ids," | HUD hidden | detail enabled=",not albedo_only," | image result=",result)
 await fixture.close()
 quit(0 if result==OK else 1)
