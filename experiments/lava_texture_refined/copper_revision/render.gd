extends "res://experiments/lava_texture_refined/balanced_revision/render.gd"
## Propose quieter timber and restore the earlier purple 3B in the study only.
const COPPER_OUTPUT := "res://experiments/lava_texture_refined/copper_revision/"

func run() -> void:
 var destination := COPPER_OUTPUT
 var timber_scale := 1.0
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): destination=argument.trim_prefix("--output=").trim_suffix("/")+"/"
  if argument.begins_with("--timber-scale="): timber_scale=float(argument.trim_prefix("--timber-scale="))
 assert(timber_scale>0.0 and timber_scale<=1.0)
 DirAccess.make_dir_recursive_absolute(destination)
 var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BALANCED_OUTPUT+"render-receipt.json"))
 var viewport := SubViewport.new()
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.size=Vector2i(1024,1024)
 root.add_child(viewport)
 var swatch := ColorRect.new()
 swatch.size=Vector2(viewport.size)
 viewport.add_child(swatch)
 var source := FileAccess.get_file_as_string(BASE+"selected.gdshader")
 source=source.left(source.find("void fragment()"))
 var timber := FileAccess.get_file_as_string(TIMBER_SOURCE+"timber.gdshaderinc")
 source+=timber.left(timber.find("vec3 timber_with_rock_insets"))
 source+=FileAccess.get_file_as_string(COPPER_OUTPUT+"wood.gdshaderinc")
 var balanced := FileAccess.get_file_as_string(BALANCED_OUTPUT+"balanced.gdshaderinc")
 assert(balanced.contains("vec3 timber=orange_timber(uv)*wood_gain;"))
 source+=balanced.replace("vec3 timber=orange_timber(uv)*wood_gain;","vec3 timber=muted_timber(orange_timber(uv)*wood_gain);")
 var shader := Shader.new()
 shader.code=source
 var paint := ShaderMaterial.new()
 paint.shader=shader
 paint.set_shader_parameter("item",5)
 paint.set_shader_parameter("rock_gain",previous.rock_gain)
 paint.set_shader_parameter("wood_gain",previous.wood_gain*timber_scale)
 swatch.material=paint
 var picture := await capture(viewport)
 assert(picture.save_png(destination+"5B.png")==OK)
 var repeated := Image.create(1024,1024,false,picture.get_format())
 for y in 2:
  for x in 2: repeated.blit_rect(picture,Rect2i(0,0,512,512),Vector2i(x,y)*512)
 assert(repeated.save_png(destination+"5B-repeat.png")==OK)
 var receipt := {
  "phase":2,"production_integration":false,"new_albedo":"5B",
  "proposal":"Muted reddish-brown timber with a slight plum undertone",
  "timber_scale":timber_scale,
  "retained_floor":BALANCED_OUTPUT+"1C.png","restored_wall":BASE+"3B.png",
  "retained_facade":OUTPUT+"9B.png","maps":["albedo"],
  "mean_srgb_signal_before":previous.revised["5B"],"mean_srgb_signal_after":signal_luma(picture)
 }
 var file := FileAccess.open(destination+"render-receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 file.close()
 swatch.free()
 viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X
 viewport.size=Vector2i(1000,760)
 await study(viewport,true,destination+"copper-study.png",destination+"5B.png",BALANCED_OUTPUT+"1C.png",BASE+"3B.png")
 viewport.free()
 print("COPPER_REVIEW | ",JSON.stringify(receipt))
 quit()
