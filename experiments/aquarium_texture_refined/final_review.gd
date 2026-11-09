extends SceneTree
## Focused material review in actual disk-loaded Prototype, with matched controls.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Selected = preload("res://scripts/themes/aquarium_selected_materials.gd")
const OUTPUT := "res://experiments/aquarium_texture_refined/final_review/"
var receipts: Array[Dictionary]=[]
func _initialize() -> void:
 Engine.time_scale=0.0
 run.call_deferred()
func save_view(fixture: RefCounted,label: String) -> Image:
 fixture.game._process(0.0)
 fixture.game._update_foreground_contribution()
 for frame in 10:await process_frame
 await RenderingServer.frame_post_draw
 var picture := root.get_texture().get_image()
 if not label.is_empty() and picture.save_png(OUTPUT+label+".png")!=OK:return null
 return picture
func pixel_change(a: Image,b: Image) -> float:
 a=a.duplicate()
 b=b.duplicate()
 a.convert(Image.FORMAT_RGBA8)
 b.convert(Image.FORMAT_RGBA8)
 var aa := a.get_data()
 var bb := b.get_data()
 var changed := 0
 for i in range(0,aa.size(),4):
  if maxi(absi(int(aa[i])-int(bb[i])),maxi(absi(int(aa[i+1])-int(bb[i+1])),absi(int(aa[i+2])-int(bb[i+2]))))>2:changed+=1
 return float(changed)/float(a.get_width()*a.get_height())
func run() -> void:
 root.size=Vector2i(1440,1000)
 root.gui_disable_input=true
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 preload("res://scripts/rendering_options.gd").settings_path=OUTPUT+"isolated-graphics.cfg"
 var response_manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://experiments/aquarium_texture_refined/response-manifest.json"))
 var success := true
 for ramp: bool in [false,true]:
  paused=false
  var fixture := Fixture.new()
  var act := "res://data/acts/Authored/RampMania.tres" if ramp else Fixture.DEFAULT_ACT
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
  if ramp:
   presentation.camera_follow_enabled=false
   presentation.overview_focus=presentation.table_bounds.get_center()
   presentation.reset_camera()
   var target := Vector2(280,330)
   var focus: Vector3=presentation.map_point(target)+Vector3.UP*.08
   var distance: float=presentation._camera_offset.length()*.66
   var yaw := deg_to_rad(32.)
   var elevation := deg_to_rad(43.)
   presentation.camera_focus=target
   presentation.camera_target=target
   presentation.camera.position=focus+Vector3(sin(yaw)*cos(elevation),sin(elevation),cos(yaw)*cos(elevation))*distance
   presentation.camera.look_at(focus)
  var label := "ramp" if ramp else "gameplay"
  var state_before: Dictionary=fixture.state()
  var off_count := Selected.set_detail(fixture.game,false)
  var off := await save_view(fixture,label+"-detail-off")
  Selected.set_detail(fixture.game,true,0.0)
  var normal_off := await save_view(fixture,"")
  var on_count := Selected.set_detail(fixture.game,true)
  var on := await save_view(fixture,label+"-current")
  var evidence := fixture.texture_evidence()
  var ids: Array[String]=[]
  for entry: Dictionary in evidence:ids.append(str(entry.source).get_file().get_basename())
  var expected := ["1-mixed-floor","2A-red-gold-studs","3B","4B","5A-red","6A-red","9A"]
  if ramp:expected.append_array(["7B","8A"])
  var missing: Array[String]=[]
  for id: String in expected:
   if FileAccess.get_sha256(Selected.DIRECTORY+id+".png")!=response_manifest.items[id].albedo_sha256:missing.append(id+" changed albedo")
   for suffix: String in ["","_normal","_response"]:
    if not ids.has(id+suffix):missing.append(id+suffix)
  var controls_valid := off_count>0 and off_count==on_count
  var source_unchanged := fixture.still_current()
  var state_unchanged := state_before==fixture.state()
  var visible_change := pixel_change(off,on) if off!=null and on!=null else 0.0
  var normal_change := pixel_change(normal_off,on) if normal_off!=null and on!=null else 0.0
  var valid: bool=controls_valid and source_unchanged and state_unchanged and missing.is_empty() and fixture.error.is_empty() and visible_change>.0001 and normal_change>.00001 and fixture.receipt.surface_detail=="selected_relief"
  success=success and valid
  var receipt: Dictionary=fixture.receipt.duplicate(true)
  receipt["current_texture_matches"]=evidence
  receipt["state"]=fixture.state()
  receipt["review"]={"view":label,"passed":valid,"missing":missing,"controls_bound_materials":on_count,"source_unchanged":source_unchanged,"state_unchanged":state_unchanged,"detail_changed_pixel_fraction":visible_change,"normal_only_changed_pixel_fraction":normal_change,"hud_hidden":true,"maps":"OpenGL normals; response R roughness/G exposed metal; no runtime height"}
  receipts.append(receipt)
  print("AQUARIUM_FINAL | ",label," | pass=",valid," | bound controls=",on_count," | changed pixels=",visible_change," | missing=",missing)
  Selected.set_detail(fixture.game,true)
  presentation.camera_follow_enabled=original_follow
  presentation.camera_focus=original_focus
  presentation.camera.transform=original_transform
  await fixture.close()
 var file := FileAccess.open(OUTPUT+"receipts.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"authority":"Prototype","complete":success,"views":receipts},"  "))
 quit(0 if success else 1)
