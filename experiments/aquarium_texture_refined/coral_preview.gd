extends SceneTree
## Albedo-only material study on the existing production coral constructor.
## This is not a game capture and does not alter the production material library.
const Decor := preload("res://scripts/decor/aquarium_park_decor.gd")
const OUTPUT := "res://experiments/aquarium_texture_refined/"
const PALETTE := ["4bbecb","8972bc"]
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 for repeated: bool in [false,true]:
  var viewport := SubViewport.new()
  viewport.size=Vector2i(1536,256) if repeated else Vector2i(512,256)
  viewport.own_world_3d=true
  viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  viewport.msaa_3d=Viewport.MSAA_4X
  root.add_child(viewport)
  var world := Node3D.new()
  viewport.add_child(world)
  var environment := WorldEnvironment.new()
  environment.environment=Environment.new()
  environment.environment.background_mode=Environment.BG_COLOR
  environment.environment.background_color=Color("182832")
  world.add_child(environment)
  var camera := Camera3D.new()
  camera.projection=Camera3D.PROJECTION_ORTHOGONAL
  camera.size=1.6
  camera.position=Vector3(0,.66,4)
  world.add_child(camera)
  camera.current=true
  for pair in (3 if repeated else 1):
   for index in 2:
    var library := Decor.new(null)
    for key: String in ["plant","coral"]:
     var material: StandardMaterial3D=library.materials[key]
     material.albedo_color=Color(PALETTE[index]).darkened(.14 if key=="plant" else 0.0)
     material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
     material.emission_enabled=false
    var center := (pair-1)*3.2 if repeated else 0.0
    library.coral(world,Vector3(center+(-.6 if index==0 else .6),0,0),1.0)
  for frame in 4: await process_frame
  await RenderingServer.frame_post_draw
  var path := OUTPUT+("repeat-13B.png" if repeated else "13B-material-study.png")
  if viewport.get_texture().get_image().save_png(path)!=OK:
   quit(1)
   return
  viewport.free()
 print("13B: cyan/violet color groups on unchanged production coral meshes; albedo-only studio preview.")
 quit()
