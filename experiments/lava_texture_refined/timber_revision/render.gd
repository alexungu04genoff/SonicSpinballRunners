extends "res://experiments/lava_texture_refined/warm_revision/render.gd"
## Render only the newly requested 5B. Reuse the approved 3B and 9B PNGs.
const TIMBER_OUTPUT := "res://experiments/lava_texture_refined/timber_revision/"

func run() -> void:
 var viewport := SubViewport.new()
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.size=Vector2i(1024,1024)
 root.add_child(viewport)
 var swatch := ColorRect.new()
 swatch.size=Vector2(viewport.size)
 viewport.add_child(swatch)
 var source := FileAccess.get_file_as_string(BASE+"selected.gdshader")
 source=source.left(source.find("void fragment()"))+FileAccess.get_file_as_string(TIMBER_OUTPUT+"timber.gdshaderinc")
 var shader := Shader.new()
 shader.code=source
 var paint := ShaderMaterial.new()
 paint.shader=shader
 swatch.material=paint
 for frame in 3: await process_frame
 await RenderingServer.frame_post_draw
 var picture := viewport.get_texture().get_image()
 picture.resize(512,512,Image.INTERPOLATE_LANCZOS)
 assert(picture.save_png(TIMBER_OUTPUT+"5B.png")==OK)
 var repeated := Image.create(1024,1024,false,picture.get_format())
 for y in 2:
  for x in 2: repeated.blit_rect(picture,Rect2i(0,0,512,512),Vector2i(x,y)*512)
 assert(repeated.save_png(TIMBER_OUTPUT+"5B-repeat.png")==OK)
 swatch.free()
 viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X
 viewport.size=Vector2i(1000,760)
 await study(viewport,true,TIMBER_OUTPUT+"timber-study.png",TIMBER_OUTPUT+"5B.png")
 viewport.free()
 print("TIMBER_REVIEW | 5B albedo, repeat and unlit study saved. Approved 3B and 9B reused unchanged.")
 quit()
