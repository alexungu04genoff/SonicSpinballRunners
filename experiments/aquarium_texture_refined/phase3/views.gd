extends SceneTree
## Requested wider and alternate-angle views in the real disk-loaded Prototype.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
var OUTPUT := "res://experiments/aquarium_texture_refined/phase3/views/"
var receipts: Array[Dictionary]=[]
func _initialize() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): OUTPUT=argument.trim_prefix("--output=").trim_suffix("/")+"/"
 Engine.time_scale=0.0
 call_deferred("run")
func shot(fixture: RefCounted, label: String, target: Vector2, distance: float, yaw: float, elevation: float) -> bool:
 var presentation: Node3D=fixture.game.presentation
 var camera: Camera3D=presentation.camera
 var focus: Vector3=presentation.map_point(target)+Vector3.UP*.08
 var a := deg_to_rad(yaw)
 var e := deg_to_rad(elevation)
 presentation.camera_focus=target
 presentation.camera_target=target
 camera.position=focus+Vector3(sin(a)*cos(e),sin(e),cos(a)*cos(e))*distance
 camera.look_at(focus)
 camera.far=maxf(camera.far,180.0)
 fixture.game._process(0.0)
 fixture.game._update_foreground_contribution()
 for frame in 10: await process_frame
 await RenderingServer.frame_post_draw
 if not fixture.still_current():
  push_error("Source or bake changed during requested views")
  return false
 var result := root.get_texture().get_image().save_png(OUTPUT+label+".png")
 var receipt: Dictionary=fixture.receipt.duplicate(true)
 receipt["state"]=fixture.state()
 receipt["current_texture_matches"]=fixture.texture_evidence()
 receipt["view"]={"label":label,"target":str(target),"distance":distance,"yaw":yaw,"elevation":elevation,"hud_hidden":true}
 receipts.append(receipt)
 print("AQUARIUM_VIEW | ",label," | bounds=",presentation.table_bounds," | image=",result)
 return result==OK and fixture.error.is_empty()
func run() -> void:
 root.size=Vector2i(1600,1100)
 root.gui_disable_input=true
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 var options := preload("res://scripts/rendering_options.gd")
 options.settings_path=OUTPUT+"isolated-graphics.cfg"
 var success := true
 for ramp: bool in [false,true]:
  paused=false
  var fixture := Fixture.new()
  var act := "res://data/acts/Authored/RampMania.tres" if ramp else Fixture.DEFAULT_ACT
  var act_bake: Resource=load(Fixture.Bake.path_for(act,"aquarium_park"))
  var theme_bake: Resource=load(Fixture.Bake.theme_path("aquarium_park"))
  var current_hash: String=Fixture.Bake.pipeline_hash("aquarium_park")
  print("VIEW_FRESHNESS | current=",current_hash," act=",act_bake.pipeline_fingerprint," theme=",theme_bake.pipeline_fingerprint)
  if not await fixture.open(self,act,"aquarium_park",OUTPUT):
   push_error(fixture.error)
   await fixture.close()
   quit(1)
   return
  fixture.game.hud.hide()
  var presentation: Node3D=fixture.game.presentation
  var original_transform: Transform3D=presentation.camera.transform
  var original_follow: bool=presentation.camera_follow_enabled
  var original_focus: Vector2=presentation.camera_focus
  presentation.camera_follow_enabled=false
  presentation.overview_focus=presentation.table_bounds.get_center()
  presentation.reset_camera()
  var bounds: Rect2=presentation.table_bounds
  var distance: float=presentation._camera_offset.length()
  if ramp:
   success=await shot(fixture,"03-ramp-overview",bounds.get_center(),distance*1.05,-12.0,59.0) and success
   success=await shot(fixture,"04-ramp-and-objects",Vector2(280,330),distance*.66,32.0,43.0) and success
  else:
   success=await shot(fixture,"01-park-overview",bounds.get_center(),distance*1.08,0.0,59.0) and success
   success=await shot(fixture,"02-borders-and-scenery",bounds.get_center()+Vector2(0,bounds.size.y*.22),distance*.66,-32.0,43.0) and success
  presentation.camera_follow_enabled=original_follow
  presentation.camera_focus=original_focus
  presentation.camera.transform=original_transform
  await fixture.close()
 var file := FileAccess.open(OUTPUT+"receipts.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"authority":"Prototype","requested_views":receipts,"complete":success},"  "))
 quit(0 if success else 1)
