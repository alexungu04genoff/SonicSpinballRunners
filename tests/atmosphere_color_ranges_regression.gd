extends SceneTree
const Ranges := preload("res://scripts/atmosphere/color_ranges.gd")
const Bindings := preload("res://scripts/atmosphere/material_bindings.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
 var values := {"ranges/enabled": true, "ranges/green/hue": 1.0 / 3.0, "ranges/green/saturation": 0.5, "ranges/green/brightness": 0.8}
 var green := Color(0.0, 0.7, 0.0, 0.4)
 check(Ranges.apply(green, values).is_equal_approx(Color(0.28, 0.28, 0.56, 0.4)), "Green changes hue, saturation and brightness while preserving alpha")
 for color: Color in [Color("a65b20"), Color.WHITE, Color.GRAY, Color.BLACK, Color.YELLOW, Color.RED, Color.BLUE]:
  check(Ranges.apply(color, values) == color, "Green adjustment preserves unrelated colors and neutrals")
 check(Ranges.apply(green, {"ranges/enabled": false, "ranges/green/hue": 0.3}) == green, "Disabled layer is exact identity")
 check(Ranges.apply(green, {"ranges/enabled": true}) == green, "Neutral enabled layer is exact identity")
 check(preload("res://scripts/atmosphere/fields.gd").valid_values("green_hill", values), "Ranges are valid production data")
 var low := Color.from_hsv(1.0 / 6.0 - 0.00001, 1.0, 0.8)
 var high := Color.from_hsv(1.0 / 6.0 + 0.00001, 1.0, 0.8)
 check((Vector3(Ranges.apply(low, values).r, Ranges.apply(low, values).g, Ranges.apply(low, values).b) - Vector3(Ranges.apply(high, values).r, Ranges.apply(high, values).g, Ranges.apply(high, values).b)).length() < 0.001, "Color range boundaries remain continuous")
 var wrap := {"ranges/enabled": true, "ranges/red/hue": -0.2}
 check(absf(Ranges.apply(Color.from_hsv(0.00001, 1.0, 1.0), wrap).h - Ranges.apply(Color.from_hsv(0.99999, 1.0, 1.0), wrap).h) < 0.001, "Red wraps smoothly across hue zero")
 check_scenery_ownership(values)
 check_stacking(values)
 if DisplayServer.get_name() != "headless": await rendered(values)
 print("ATMOSPHERE_COLOR_RANGES | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func check_scenery_ownership(values: Dictionary) -> void:
 var container := Node3D.new()
 var scenery := Node3D.new()
 scenery.set_meta("atmosphere_scenery", "local")
 container.add_child(scenery)
 var source := StandardMaterial3D.new()
 source.albedo_color = Color.GREEN
 source.emission_enabled = true
 source.emission = Color.GREEN
 for index in 3:
  var mesh := MeshInstance3D.new()
  mesh.mesh = BoxMesh.new()
  mesh.material_override = source
  (scenery if index < 2 else container).add_child(mesh)
 var bindings := Bindings.new()
 var light := DirectionalLight3D.new()
 bindings.collect(container)
 bindings.apply_palette(values, light, false)
 check(scenery.get_child(0).material_override == scenery.get_child(1).material_override, "Scenery instances share their range material")
 check(scenery.get_child(0).material_override.albedo_color != source.albedo_color, "Previously untagged scenery now responds")
 check(container.get_child(1).material_override.albedo_color == Color.GREEN and container.get_child(1).material_override.emission == Color.GREEN, "Shared gameplay source stays unchanged")
 bindings.restore()
 check(scenery.get_child(0).material_override == source, "Scenery original slot restores")
 light.free()
 container.free()

func check_stacking(values: Dictionary) -> void:
 var container := Node3D.new()
 var source := StandardMaterial3D.new()
 source.albedo_color = Color.GREEN
 source.emission_enabled = true
 source.emission = Color.GREEN
 source.set_meta("atmosphere_hue", "decor")
 preload("res://scripts/themes/theme_atmosphere.gd").color(source, "neon_pink")
 var mesh := MeshInstance3D.new()
 mesh.mesh = BoxMesh.new()
 mesh.material_override = source
 container.add_child(mesh)
 var bindings := Bindings.new()
 var light := DirectionalLight3D.new()
 bindings.collect(container, "casino_night")
 var choices := values.duplicate()
 choices["stack/decor"] = false
 choices["hue/decor"] = 0.1
 bindings.apply_palette(choices, light, false)
 check(mesh.material_override.albedo_color.is_equal_approx(Color.from_hsv(Color.GREEN.h + 0.1, 1.0, 1.0)), "Category opt-out retains its own Palette hue")
 choices.erase("hue/decor")
 choices["stack/decor"] = true
 choices["stack/palette/neon_pink"] = false
 bindings.apply_palette(choices, light, false)
 check(mesh.material_override.albedo_color == Color.GREEN and mesh.material_override.emission == Color.GREEN, "Individual color opt-out skips range adjustments")
 choices["stack/palette/neon_pink"] = true
 bindings.apply_palette(choices, light, false)
 check(mesh.material_override.albedo_color != Color.GREEN, "Individual color can stack again")
 check(preload("res://scripts/atmosphere/fields.gd").valid_values("casino_night", choices), "Both stacking controls validate for saved variants")
 bindings.restore()
 light.free()
 container.free()

 var shader_root := Node3D.new()
 var shader_material := ShaderMaterial.new()
 shader_material.shader = Shader.new()
 shader_material.shader.code = "shader_type spatial; uniform vec4 a : source_color = vec4(0.0, 1.0, 0.0, 1.0); uniform vec4 b : source_color = vec4(0.0, 1.0, 0.0, 1.0); void fragment() { ALBEDO = mix(a.rgb, b.rgb, 0.5); }"
 shader_material.set_shader_parameter("a", Color.GREEN)
 shader_material.set_shader_parameter("b", Color.GREEN)
 preload("res://scripts/themes/theme_atmosphere.gd").tag(shader_material, "a", "neon_pink", "direct", {"shader": true})
 preload("res://scripts/themes/theme_atmosphere.gd").tag(shader_material, "b", "neon_aqua", "direct", {"shader": true})
 var shader_mesh := MeshInstance3D.new()
 shader_mesh.mesh = BoxMesh.new()
 shader_mesh.material_override = shader_material
 shader_root.add_child(shader_mesh)
 var shader_bindings := Bindings.new()
 var shader_light := DirectionalLight3D.new()
 shader_bindings.collect(shader_root, "casino_night")
 var selected := values.duplicate()
 selected["stack/palette/neon_pink"] = false
 shader_bindings.apply_palette(selected, shader_light, false)
 var edited: ShaderMaterial = shader_mesh.material_override
 check(edited.get_shader_parameter("a") == Color.GREEN, "Opted-out shader color input stays unchanged")
 check(edited.get_shader_parameter("b") != Color.GREEN, "Other shader color input still stacks")
 check(edited.get_shader_parameter("atmosphere_ranges_enabled") == false, "Mixed shader inputs are not shifted a second time")
 shader_bindings.restore()
 shader_light.free()
 shader_root.free()

func rendered(values: Dictionary) -> void:
 var viewport := SubViewport.new()
 viewport.size = Vector2i(256, 128)
 viewport.own_world_3d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var container := Node3D.new()
 viewport.add_child(container)
 var shader := Shader.new()
 shader.code = "shader_type spatial; render_mode unshaded; uniform float emission_scale = 1.0; void fragment() { ALBEDO = UV.x < 0.25 ? vec3(0.0, 0.7, 0.0) : (UV.x < 0.5 ? vec3(0.6, 0.25, 0.05) : (UV.x < 0.75 ? vec3(1.0) : vec3(1.0, 1.0, 0.0))); }"
 for index in 2:
  var material := ShaderMaterial.new()
  material.shader = shader
  if index == 0: material.set_meta("atmosphere_hue", "decor")
  var mesh := MeshInstance3D.new()
  mesh.mesh = QuadMesh.new()
  mesh.mesh.size = Vector2(4, 1)
  mesh.position.y = 0.5 if index == 0 else -0.5
  mesh.material_override = material
  container.add_child(mesh)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.keep_aspect = Camera3D.KEEP_WIDTH
 camera.size = 4.0
 camera.position.z = 2.0
 viewport.add_child(camera)
 var light := DirectionalLight3D.new()
 var bindings := Bindings.new()
 bindings.collect(container)
 bindings.apply_palette({}, light, false)
 var program: Shader = container.get_child(0).material_override.shader
 await process_frame
 await RenderingServer.frame_post_draw
 var original := viewport.get_texture().get_image()
 bindings.apply_palette(values, light, false)
 await process_frame
 await RenderingServer.frame_post_draw
 var shifted := viewport.get_texture().get_image()
 var blue: Color = shifted.get_pixel(32, 32)
 check(blue.b > blue.g + 0.1 and blue.r > 0.1, "Shader turns only the green sample into desaturated blue")
 for x: int in [96, 160, 224]:
  check(shifted.get_pixel(x, 32).is_equal_approx(original.get_pixel(x, 32)), "Shader preserves brown checker, white and yellow")
 for x: int in [32, 96, 160, 224]:
  check(shifted.get_pixel(x, 96) == original.get_pixel(x, 96), "Untagged gameplay surface remains unchanged")
 check(container.get_child(0).material_override.shader == program, "Range edits reuse the prepared program")
 bindings.apply_palette({}, light, false)
 await process_frame
 await RenderingServer.frame_post_draw
 check(viewport.get_texture().get_image().get_data() == original.get_data(), "Disabling ranges restores exact rendered baseline")
 bindings.restore()
 # Textures and vertex colors must be adjusted after sampling. Compare the
 # neutral adapter against an actual StandardMaterial, not another adapter.
 var pixels := Image.create(4, 1, false, Image.FORMAT_RGBA8)
 for index in 4: pixels.set_pixel(index, 0, [Color.GREEN, Color("995511"), Color.WHITE, Color.YELLOW][index])
 for mode in ["texture", "triplanar", "vertex"]:
  var standard := StandardMaterial3D.new()
  standard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  standard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
  standard.albedo_texture = ImageTexture.create_from_image(pixels) if mode != "vertex" else null
  standard.uv1_triplanar = mode == "triplanar"
  standard.vertex_color_use_as_albedo = mode == "vertex"
  for index in 2:
   var surface: MeshInstance3D = container.get_child(index)
   var quad := QuadMesh.new()
   quad.size = Vector2(4, 1)
   if mode == "vertex":
    var arrays := quad.surface_get_arrays(0)
    var colors := PackedColorArray()
    colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
    colors.fill(Color.GREEN)
    arrays[Mesh.ARRAY_COLOR] = colors
    var colored := ArrayMesh.new()
    colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    surface.mesh = colored
   else: surface.mesh = quad
   surface.material_override = standard.duplicate()
   if index == 0: surface.material_override.set_meta("atmosphere_hue", "decor")
  bindings.collect(container)
  bindings.apply_palette({}, light, false)
  await process_frame
  await RenderingServer.frame_post_draw
  var baseline := viewport.get_texture().get_image()
  var green_x := -1
  for x in range(8, 248):
   var top := baseline.get_pixel(x, 32)
   check(top == baseline.get_pixel(x, 96), mode + " neutral output matches StandardMaterial")
   if top.g > 0.8 and top.r < 0.1: green_x = x
  check(green_x >= 0, mode + " contains a green test sample")
  bindings.apply_palette(values, light, false)
  await process_frame
  await RenderingServer.frame_post_draw
  var changed := viewport.get_texture().get_image()
  if green_x >= 0:
   check(changed.get_pixel(green_x, 32).b > changed.get_pixel(green_x, 32).g + 0.1, mode + " sampled green responds")
   check(changed.get_pixel(green_x, 96) == baseline.get_pixel(green_x, 96), mode + " gameplay texture remains unchanged")
  bindings.restore()
 var emissive := Shader.new()
 emissive.code = "shader_type spatial; render_mode specular_disabled; void fragment() { ALBEDO = vec3(0.0); EMISSION = vec3(0.0, 0.7, 0.0); }"
 for index in 2:
  var material := ShaderMaterial.new()
  material.shader = emissive
  if index == 0: material.set_meta("atmosphere_hue", "terrain_ground")
  container.get_child(index).material_override = material
 bindings.collect(container)
 bindings.apply_palette(values, light, false)
 await process_frame
 await RenderingServer.frame_post_draw
 var emission_result := viewport.get_texture().get_image()
 check(emission_result.get_pixel(32, 32).b > emission_result.get_pixel(32, 32).g + 0.1, "Terrain emission participates in selective color ranges")
 check(emission_result.get_pixel(32, 96).g > emission_result.get_pixel(32, 96).b + 0.1, "Gameplay emission remains excluded")
 bindings.restore()
 light.free()
 viewport.free()
