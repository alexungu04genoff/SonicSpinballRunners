extends "res://experiments/lava_texture_refined/warm_revision/render.gd"
## Albedo authoring only. Match floor values while sharing the rock palette.
const BALANCED_OUTPUT := "res://experiments/lava_texture_refined/balanced_revision/"
const TIMBER_SOURCE := "res://experiments/lava_texture_refined/timber_revision/"

func signal_luma(picture: Image) -> float:
 var total := 0.0
 for y in range(0,picture.get_height(),2):
  for x in range(0,picture.get_width(),2):
   var color := picture.get_pixel(x,y)
   total += color.r*0.2126+color.g*0.7152+color.b*0.0722
 return total / (picture.get_width()*picture.get_height()/4.0)

func capture(viewport: SubViewport) -> Image:
 for frame in 3: await process_frame
 await RenderingServer.frame_post_draw
 var picture := viewport.get_texture().get_image()
 picture.resize(512,512,Image.INTERPOLATE_LANCZOS)
 return picture

func save_surface(picture: Image, id: String) -> void:
 assert(picture.save_png(BALANCED_OUTPUT+id+".png")==OK)
 var repeated := Image.create(1024,1024,false,picture.get_format())
 for y in 2:
  for x in 2: repeated.blit_rect(picture,Rect2i(0,0,512,512),Vector2i(x,y)*512)
 assert(repeated.save_png(BALANCED_OUTPUT+id+"-repeat.png")==OK)

func run() -> void:
 var previous_floor := signal_luma(read_image(BASE+"1C.png"))
 var previous_top := signal_luma(read_image(TIMBER_SOURCE+"5B.png"))
 var target := (previous_floor+previous_top)*0.5
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
 source+=FileAccess.get_file_as_string(BALANCED_OUTPUT+"balanced.gdshaderinc")
 var shader := Shader.new()
 shader.code=source
 var paint := ShaderMaterial.new()
 paint.shader=shader
 swatch.material=paint
 paint.set_shader_parameter("item",1)
 var raw_floor := await capture(viewport)
 var mineral_gain := target/signal_luma(raw_floor)
 paint.set_shader_parameter("rock_gain",mineral_gain)
 var floor_image := await capture(viewport)
 save_surface(floor_image,"1C")
 # Solve the wood contribution while keeping the identical rock palette on both floors.
 paint.set_shader_parameter("item",5)
 paint.set_shader_parameter("wood_gain",0.0)
 var rock_contribution := signal_luma(await capture(viewport))
 paint.set_shader_parameter("wood_gain",1.0)
 var full_top := signal_luma(await capture(viewport))
 var timber_gain := (target-rock_contribution)/(full_top-rock_contribution)
 paint.set_shader_parameter("wood_gain",timber_gain)
 var top_image := await capture(viewport)
 save_surface(top_image,"5B")
 var receipt := {
  "phase":2,"production_integration":false,"changed":["1C","5B"],
  "metric":"Mean Rec.709-weighted sRGB signal, not a photometric luminance measurement",
  "previous":{"1C":previous_floor,"5B":previous_top},"target":target,
  "revised":{"1C":signal_luma(floor_image),"5B":signal_luma(top_image)},
  "rock_gain":mineral_gain,"wood_gain":timber_gain,
  "approved_unchanged":["3B","9B"],"maps":["albedo"]
 }
 var file := FileAccess.open(BALANCED_OUTPUT+"render-receipt.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt,"  "))
 file.close()
 swatch.free()
 viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X
 viewport.size=Vector2i(1000,760)
 await study(viewport,true,BALANCED_OUTPUT+"balanced-study.png",BALANCED_OUTPUT+"5B.png",BALANCED_OUTPUT+"1C.png")
 viewport.free()
 print("BALANCED_REVIEW | ",JSON.stringify(receipt))
 quit()
