extends SceneTree
## Matched depth on/off in the real disk-loaded game, with canonical defaults first.
const Fixture=preload("res://tests/prototype_appearance_fixture.gd")
const Materials=preload("res://scripts/themes/lava_selected_materials.gd")
const OUTPUT:="res://experiments/lava_texture_refined/canonical/"
class ControlHost extends Node:
 var theme_id:="lava_reef"
 var presentation: Node
func _initialize() -> void:
 Engine.time_scale=0.0
 call_deferred("run")
func settled() -> void:
 for frame in 12:await process_frame
 await RenderingServer.frame_post_draw
func run() -> void:
 root.size=Vector2i(1440,1000)
 root.gui_disable_input=true
 preload("res://scripts/rendering_options.gd").settings_path=OUTPUT+"isolated-graphics.cfg"
 var fixture:=Fixture.new()
 if not await fixture.open(self,"res://data/acts/Authored/RampMania.tres","lava_reef",OUTPUT):
  push_error(fixture.error)
  await fixture.close()
  quit(1)
  return
 fixture.game.hud.hide()
 assert(fixture.receipt.retro_mode=="production","Canonical review requires --retro=production")
 var materials:=Materials.bound_materials(fixture.game)
 assert(not materials.is_empty())
 var floor_count:=0
 for material: ShaderMaterial in materials:
  assert(not material.get_meta("lava_visual_relief",false),"Retired rock geometry must not be bound")
  assert(is_zero_approx(float(material.get_shader_parameter("geometry_strength"))))
  assert(is_zero_approx(float(material.get_shader_parameter("recess_depth"))))
  if material.get_meta("lava_floor",false):
   assert(is_equal_approx(float(material.get_shader_parameter("relief_strength")),6.0))
   floor_count+=1
  assert(is_equal_approx(float(material.get_shader_parameter("relief_strength")),float(material.get_meta("normal_strength",Materials.NORMAL_STRENGTH))))
  assert(is_equal_approx(float(material.get_shader_parameter("detail_mix")),1.0))
  assert(material.get_shader_parameter("relief_normal") is Texture2D)
 assert(floor_count>=2)
 var evidence:=fixture.texture_evidence()
 var found: Array[String]=[]
 for entry: Dictionary in evidence:found.append(str(entry.source).get_file().get_basename())
 for id: String in ["1C","2A","3B","5B","6B","7A","8B","9B"]:
  for suffix: String in ["","_normal","_roughness"]:assert(found.has(id+suffix),"Missing loaded texture "+id+suffix)
 for id: String in ["1C_cavity","5B_cavity"]:assert(found.has(id))
 assert(fixture.error.is_empty())
 var state:=fixture.state()
 await settled()
 assert(root.get_texture().get_image().save_png(OUTPUT+"depth-on.png")==OK)
 # Drive the real control signals against the loaded/private/batched materials.
 var host:=ControlHost.new()
 host.presentation=fixture.game
 root.add_child(host)
 var controls:=preload("res://experiments/lava_texture_refined/live_controls.gd").new()
 host.add_child(controls)
 controls.install(host)
 controls.detail.button_pressed=false
 for material: ShaderMaterial in materials:
  assert(is_zero_approx(float(material.get_shader_parameter("relief_strength"))))
  assert(is_zero_approx(float(material.get_shader_parameter("detail_mix"))))
 await settled()
 assert(fixture.state()==state,"Depth comparison changed gameplay or camera")
 assert(root.get_texture().get_image().save_png(OUTPUT+"depth-off.png")==OK)
 controls.strength.value=1.25
 controls.detail.button_pressed=true
 for material: ShaderMaterial in materials:
  assert(is_equal_approx(float(material.get_shader_parameter("relief_strength")),float(material.get_meta("normal_strength",Materials.NORMAL_STRENGTH))*1.25))
 controls.strength.value=1.0
 for material: ShaderMaterial in materials:
  assert(is_equal_approx(float(material.get_shader_parameter("relief_strength")),float(material.get_meta("normal_strength",Materials.NORMAL_STRENGTH))))
 host.free()
 assert(load("res://experiments/visual_lab/visual_lab.tscn")!=null)
 assert(fixture.still_current() and fixture.authority_error().is_empty())
 var receipt: Dictionary=fixture.receipt.duplicate(true)
 receipt["state"]=state
 receipt["current_texture_matches"]=evidence
 receipt["canonical_defaults_verified"]=true
 receipt["material_controls_verified"]=true
 receipt["recessed_geometry_materials"]=0
 receipt["floor_normal_strength"]=Materials.FLOOR_NORMAL_STRENGTH
 receipt["bound_materials"]=materials.size()
 receipt["normal_strength"]=Materials.NORMAL_STRENGTH
 receipt["hud_hidden"]=true
 receipt["albedos_unchanged"]=true
 var sources: Array=JSON.parse_string(FileAccess.get_file_as_string("res://experiments/lava_texture_refined/phase3/selected-source-receipt.json"))
 for entry: Dictionary in sources:
  assert(FileAccess.get_sha256(entry.Destination).to_upper()==str(entry.Hash).to_upper())
 if OS.get_cmdline_user_args().has("--final"):
  var paths: Array=preload("res://scripts/prototype/run_plan.gd").source_paths()
  paths.append_array(preload("res://scripts/endless/endless_plan.gd").PATHS)
  receipt["current_bakes"]=[]
  for path: String in paths:
   var document: Resource=Fixture.Document.load_document(path).document
   var baked: Resource=load(Fixture.Bake.path_for(path,"lava_reef"))
   assert(baked.matches(document,"lava_reef",receipt.pipeline_fingerprint),"Stale Lava Reef bake: "+path)
   receipt.current_bakes.append(path)
 var file:=FileAccess.open(OUTPUT+"receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 file.close()
 print("LAVA_CANONICAL | loaded textures=",found.size()," | bound materials=",materials.size()," | controls/defaults verified | disk only")
 await fixture.close()
 quit()
