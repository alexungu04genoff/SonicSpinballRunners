extends SceneTree
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const Manifest = preload("res://scripts/endless/warm_manifest.gd")
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Batcher = preload("res://scripts/endless/static_batches.gd")
const Assets = preload("res://scripts/endless/bake_assets.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func _initialize() -> void:
 call_deferred("run")

func signatures(node: GeometryInstance3D) -> PackedStringArray:
 return Manifest.new().signatures(node)

func texture(color: Color) -> ImageTexture:
 var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
 image.fill(color)
 return ImageTexture.create_from_image(image)

func run() -> void:
 var node := MeshInstance3D.new()
 node.mesh = BoxMesh.new()
 var unassigned := signatures(node)
 check(unassigned.size() == 1, "Default renderer material has a warm feature signature")
 var material := StandardMaterial3D.new()
 material.albedo_color = Color.RED
 node.material_override = material
 var red := signatures(node)
 material.albedo_color = Color.BLUE
 check(signatures(node) == red, "Uniform color changes do not create shader variants")
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 check(signatures(node) != red, "Transparency features retain separate signatures")
 material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
 node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 check(signatures(node) != red, "Shadow casting differences retain separate signatures")
 node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
 node.material_overlay = StandardMaterial3D.new()
 node.material_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 check(signatures(node).size() == 2, "Overlay material features are included")
 node.material_overlay = null
 material.next_pass = StandardMaterial3D.new()
 material.next_pass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 check(signatures(node) != red, "Next material passes participate in shader features")
 material.next_pass = null
 material.albedo_texture = texture(Color.RED)
 var textured := signatures(node)
 var first_binding := Manifest.new().material_probe_key(material)
 material.albedo_texture = texture(Color.BLUE)
 check(signatures(node) == textured and textured != red, "Texture presence affects the shader; pixel colors do not")
 check(Manifest.new().material_probe_key(material) != first_binding, "Distinct texture pixels retain distinct upload probes")
 material.albedo_texture = texture(Color.RED)
 check(Manifest.new().material_probe_key(material) == first_binding, "Identical textures retain stable keys across resource instances")
 material.albedo_texture = null
 var shader_material := ShaderMaterial.new()
 var first_shader := Shader.new()
 first_shader.code = "shader_type spatial; void fragment() { ALBEDO = vec3(0.5); }"
 shader_material.shader = first_shader
 node.material_override = shader_material
 var shader_features := signatures(node)
 var second_shader := Shader.new()
 second_shader.code = first_shader.code
 shader_material.shader = second_shader
 check(signatures(node) == shader_features, "Shader identity uses source instead of resource instance IDs")
 second_shader.code = "shader_type spatial; render_mode unshaded; void fragment() { ALBEDO = vec3(0.5); }"
 check(signatures(node) != shader_features, "Different shader source retains a separate signature")
 node.material_override = material
 node.visible = false
 node.extra_cull_margin = 3.25
 var recipe := Recipe.new()
 recipe.capture(node)
 check(not recipe.has_warm_manifest(), "Unprepared recipes cannot enter normal disk playback")
 var manifest := Manifest.new()
 manifest.prepare(recipe)
 check(recipe.has_warm_manifest(), "Baked recipe contains complete warm-up metadata")
 check(recipe.records[0].warm_signatures == red, "Saved metadata matches final node material features")
 check(not recipe.records[0].warm_visible and recipe.records[0].warm_cull_margin == 3.25, "Warm-up metadata preserves original visibility and cull margin")
 var materials: Array[Material] = [material, material.duplicate()]
 var probes: Resource = manifest.build_probes(materials)
 check(probes.records.size() == 2, "Identical material bindings need one ordinary and one instanced probe")
 check(probes.has_warm_manifest(), "Probe recipe is prepared offline")
 check(probes.records[0].warm_signatures != probes.records[1].warm_signatures, "Ordinary and instanced probes retain separate feature signatures")
 var baked := Bake.new()
 baked.kind = "theme"
 baked.visual_recipe = recipe
 baked.preload_recipe = probes
 var path := "res://test-results/endless-manifest-test.res"
 check(ResourceSaver.save(baked, path, ResourceSaver.FLAG_COMPRESS) == OK, "Recipe and probe manifest save to disk")
 var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
 check(loaded.version == 5 and loaded.preload_recipe.has_warm_manifest(), "Version 5 reloads complete offline probes")
 check(loaded.visual_recipe.records[0].warm_signatures == red, "Feature signatures survive disk serialization unchanged")
 check(not loaded.visual_recipe.records[0].warm_visible and loaded.visual_recipe.records[0].warm_cull_margin == 3.25, "Original render state survives disk serialization")
 var parent := Node3D.new()
 var nodes: Array[Node] = []
 for index in loaded.preload_recipe.records.size(): loaded.preload_recipe.instantiate_one(index, nodes, parent)
 for index in nodes.size():
  check(signatures(nodes[index]) == loaded.preload_recipe.records[index].warm_signatures, "Reloaded nodes match their disk feature signatures")
 check(nodes[1] is MultiMeshInstance3D and nodes[1].multimesh.instance_count == 1, "Offline instanced probe restores its single transform")
 parent.free()
 var invalid: Resource = loaded.visual_recipe.duplicate(true)
 invalid.records[0].erase("warm_signatures")
 check(not invalid.has_warm_manifest(), "A partial manifest is rejected")
 var source := Node3D.new()
 for index in 4:
  var box := MeshInstance3D.new()
  box.mesh = BoxMesh.new()
  box.mesh.size = Vector3.ONE * 0.1
  box.material_override = material
  box.position = Vector3(index * 0.1, 0, 0)
  source.add_child(box)
 var batch_recipe := Recipe.new()
 batch_recipe.capture(source)
 var assets := Assets.new()
 assets.share(batch_recipe)
 var before := batch_recipe.records.size()
 var batches: Dictionary = Batcher.new().optimize(batch_recipe)
 manifest.prepare(batch_recipe)
 check(assets.error.is_empty() and batches.batches == 1 and batch_recipe.records.size() < before, "Fixture builds a shared spatial batch before creating metadata")
 check(batch_recipe.has_warm_manifest(), "Final batched recipe has complete metadata")
 var restored_root := Node3D.new()
 var restored: Array[Node] = []
 for index in batch_recipe.records.size(): batch_recipe.instantiate_one(index, restored, restored_root)
 var found := false
 for index in restored.size():
  if restored[index] is MultiMeshInstance3D:
   found = true
   check(signatures(restored[index]) == batch_recipe.records[index].warm_signatures, "Batch metadata describes the final instanced node, not its source meshes")
 check(found, "Final recipe contains the expected instanced draw path")
 restored_root.free()
 source.free()
 node.free()
 print("ENDLESS_MANIFEST_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
