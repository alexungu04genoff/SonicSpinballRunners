extends SceneTree
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Assets = preload("res://scripts/endless/bake_assets.gd")
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const Library = preload("res://scripts/endless/template_library.gd")
const Flicky = preload("res://scripts/decor/island_flicky.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func run() -> void:
 var bird := Flicky.new()
 bird.phase = 0.2
 bird.pose = Node3D.new()
 bird.head = Node3D.new()
 bird.add_child(bird.pose)
 bird.pose.add_child(bird.head)
 for i in 2:
  var wing := Node3D.new()
  bird.pose.add_child(wing)
  bird.wings.append(wing)
 var recipe := Recipe.new()
 recipe.capture(bird)
 recipe.finish()
 var bake := Bake.new()
 bake.visual_recipe = recipe
 bake.kind = "theme"
 bake.theme_id = "green_hill"
 bake.pipeline_fingerprint = "fixture"
 bake.environment = Environment.new()
 bake.light = {"color": Color.WHITE, "energy": 1.0}
 var path := "res://test-results/endless-recipe-test.res"
 check(ResourceSaver.save(bake, path, ResourceSaver.FLAG_COMPRESS) == OK, "Complete visual bake saves")
 var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
 check(loaded.matches_pipeline("green_hill", "fixture"), "Theme metadata survives disk serialization")
 check(not loaded.matches_pipeline("green_hill", "changed"), "Stale visual recipes are rejected")
 check(loaded.visual_recipe.records.size() == recipe.records.size(), "Every node survives recipe serialization")
 var root_node := Node3D.new()
 var nodes: Array[Node] = []
 for i in loaded.visual_recipe.records.size(): loaded.visual_recipe.instantiate_one(i, nodes, root_node)
 loaded.visual_recipe.bind_animations(nodes, null)
 var restored: Node = nodes[0]
 check(restored.pose == nodes[1] and restored.head == nodes[2], "Animated references bind to the new scene nodes")
 check(restored.wings.size() == 2 and restored.wings[0] != bird.wings[0], "Animation arrays do not retain the authoring scene")
 restored.set_animation_time(0.1)
 check(restored.pose.position.y > 0.0 and is_zero_approx(bird.pose.position.y), "Loaded animation updates independently")
 check(loaded.environment != null and loaded.light.energy == 1.0, "Shared environment and lighting survive saving")
 var pixels := Image.create(2, 2, false, Image.FORMAT_RGBA8)
 pixels.fill(Color(0.125, 0.25, 0.5))
 pixels.resource_path = "res://test-results/source-image.png"
 var first := ImageTexture.create_from_image(pixels)
 var second := ImageTexture.create_from_image(pixels)
 var assets := Assets.new()
 var shared: Array = assets.share([first, second])
 check(assets.error.is_empty(), "Procedural textures save to the shared asset bank")
 check(shared[0] == shared[1] and FileAccess.file_exists(shared[0].resource_path), "Identical textures use one disk asset")
 check(load(shared[0].resource_path) == load(shared[1].resource_path), "ResourceLoader reuses the shared texture")
 check(shared[0].get_image().resource_path.is_empty(), "Shared textures embed pixels without editor-only Image paths")
 var library := Library.new()
 var mesh := MeshInstance3D.new()
 mesh.mesh = BoxMesh.new()
 var red := StandardMaterial3D.new()
 red.albedo_color = Color.RED
 mesh.material_override = red
 var red_signature: Array = library._shader_signatures(mesh)
 var blue := StandardMaterial3D.new()
 blue.albedo_color = Color.BLUE
 mesh.material_override = blue
 check(library._shader_signatures(mesh) == red_signature, "Different uniform colors share a warm-up shader signature")
 blue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 check(library._shader_signatures(mesh) != red_signature, "Different shader features keep distinct warm-up signatures")
 blue.albedo_texture = first
 var scene := PackedScene.new()
 scene.pack(mesh)
 assets.share(scene)
 var scene_path := "res://test-results/endless-shared-texture-test.res"
 check(ResourceSaver.save(scene, scene_path, ResourceSaver.FLAG_COMPRESS) == OK, "Recipe scene with shared texture saves")
 var loaded_scene: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE)
 var loaded_mesh: MeshInstance3D = loaded_scene.instantiate()
 check(loaded_mesh.material_override.albedo_texture == shared[0], "Saved scene references the shared external texture")
 loaded_mesh.free()
 var surface := SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 surface.set_material(blue)
 for vertex: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD]: surface.add_vertex(vertex)
 var triangle := surface.commit()
 var vertices: PackedVector3Array = triangle.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 assets.share(triangle)
 check(triangle.get_surface_count() == 1 and triangle.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == vertices, "Texture sharing preserves ArrayMesh surfaces and vertices")
 var cube := BoxMesh.new()
 var other_cube := BoxMesh.new()
 var shared_meshes: Array = assets.share([cube, other_cube])
 check(shared_meshes[0] is ArrayMesh, "Primitive mesh geometry is calculated offline")
 check(shared_meshes[0] == shared_meshes[1], "Identical primitive meshes share one disk resource")
 check(shared_meshes[0].surface_get_arrays(0) == cube.get_mesh_arrays(), "Baked primitive keeps vertices, normals, UVs and indices")
 mesh.free()
 library.free()
 root_node.free()
 bird.free()
 print("ENDLESS_CACHE_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)
