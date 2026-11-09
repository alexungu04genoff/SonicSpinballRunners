extends SceneTree
## Uses the canonical disk-loaded Prototype fixture; no alternate presentation path.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const OUTPUT := "res://experiments/aquarium_texture_refined/phase3/"
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
 if not await fixture.open(self,act,"aquarium_park",OUTPUT):
  push_error(fixture.error)
  await fixture.close()
  quit(1)
  return
 fixture.game.hud.hide()
 for frame in 12: await process_frame
 await RenderingServer.frame_post_draw
 var evidence := fixture.texture_evidence()
 var ids: Array[String]=[]
 for entry: Dictionary in evidence: ids.append(str(entry.source).get_file().get_basename())
 var expected := ["1-mixed-floor","2A-red-gold-studs","3B","4B","5A-red","6A-red","9A"]
 if act.get_file()=="RampMania.tres": expected.append_array(["7B","8A"])
 var missing: Array[String]=[]
 for id: String in expected:
  if not ids.has(id): missing.append(id)
 if not fixture.error.is_empty() or not missing.is_empty() or not fixture.still_current():
  push_error("Aquarium review material evidence failed: "+fixture.error+" missing="+str(missing)+" loaded="+str(ids))
  await fixture.close()
  quit(1)
  return
 var receipt: Dictionary=fixture.receipt.duplicate(true)
 receipt["current_texture_matches"]=evidence
 receipt["state"]=fixture.state()
 receipt["hud_hidden"]=true
 receipt["relief"]="Current selected structural normals and packed roughness/metal response; no runtime height, parallax or displacement"
 receipt["selected_materials"]={}
 var baked: Resource=fixture.game.library._act_bakes[fixture.game.library.key("aquarium_park",0)]
 for resource: Resource in baked.retirement_dependencies:
  if resource is ShaderMaterial and resource.shader.code.contains("cap_texture") and resource.shader.code.contains("strip_uv"):
   var mapping: int=resource.get_shader_parameter("mapping")
   receipt.selected_materials[str(mapping)]={"repeat_size":str(resource.get_shader_parameter("repeat_size")),"shader":"res://scripts/themes/aquarium_selected.gdshader"}
 var result := root.get_texture().get_image().save_png(OUTPUT+label+".png")
 var file := FileAccess.open(OUTPUT+label+"-receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 print("AQUARIUM_REVIEW | disk Prototype | current textures=",ids," | HUD hidden | current material response | image result=",result)
 await fixture.close()
 quit(0 if result==OK else 1)
