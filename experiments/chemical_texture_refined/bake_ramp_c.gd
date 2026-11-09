extends "res://tools/bake_theme_textures.gd"
## Original ramp structure, with only the ochre paint changed to the selected safety yellow.
func run() -> void:
 viewport = SubViewport.new()
 viewport.size = Vector2i(1024, 1024)
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 swatch = ColorRect.new()
 swatch.size = Vector2(viewport.size)
 viewport.add_child(swatch)
 var recipe := source("chemical_plant", "ramp")
 var shader := Shader.new()
 shader.code = recipe.code.replace("vec3 yellow = vec3(0.50, 0.39, 0.045);", "vec3 yellow = vec3(240.0, 173.0, 20.0) / 255.0;")
 var material := ShaderMaterial.new()
 material.shader = shader
 swatch.material = material
 for frame in 3: await process_frame
 await RenderingServer.frame_post_draw
 var image := viewport.get_texture().get_image()
 image.resize(512, 512, Image.INTERPOLATE_LANCZOS)
 image.save_png("res://experiments/chemical_texture_refined/7C-yellow.png")
 image.save_png("res://assets/textures/chemical_plant/selected/7C-yellow.png")
 print("Original ramp pattern saved with matching safety yellow.")
 viewport.queue_free()
 quit()
