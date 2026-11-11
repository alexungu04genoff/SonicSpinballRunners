extends SceneTree
## Check the actual generated, atmosphere-adapted and baked grass programs.
const Maps = preload("res://scripts/themes/rooftop_material_maps.gd")
const Policy = preload("res://scripts/endless/foreground_contribution.gd")
const Act = preload("res://scripts/endless/streamed_act.gd")
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func enclosed(act: RefCounted, meshes: Array[MeshInstance3D]) -> bool:
 for mesh: MeshInstance3D in meshes:
  for corner in 8:
   for offset: float in [-Maps.GrassBounds.MAX_OFFSET, 0.0, Maps.GrassBounds.MAX_OFFSET]:
    var point := mesh.global_transform * (mesh.get_aabb().get_endpoint(corner) + Vector3.UP * offset)
    if not act.contribution.bounds.grow(0.0001).has_point(point): return false
 return true

func run() -> void:
 var maps := Maps.new()
 var materials := maps.grass_shells()
 var act := Act.new()
 act.recipe = Recipe.new()
 root.add_child(act.visual)
 var parent := Node3D.new()
 parent.transform = Transform3D(Basis.from_euler(Vector3(0.4, 0.6, -0.2)).scaled(Vector3(2.0, 0.7, 1.3)), Vector3(4, 2, -3))
 act.visual.add_child(parent)
 var meshes: Array[MeshInstance3D] = []
 for index in materials.size() + 1:
  var mesh := MeshInstance3D.new()
  mesh.mesh = BoxMesh.new()
  mesh.position = Vector3(index * 3.0, index * 0.1, -index * 2.0)
  if index == materials.size(): mesh.scale = Vector3(-1.0, 2.0, 0.6)
  mesh.material_override = materials[index % materials.size()]
  if index == 0: mesh.extra_cull_margin = 0.7
  parent.add_child(mesh)
  meshes.append(mesh)
 var original_margin: float = meshes[0].extra_cull_margin
 for material: ShaderMaterial in materials:
  var height: float = material.get_shader_parameter("shell_height")
  check(height == clampf(height, -Maps.GrassBounds.MAX_OFFSET, Maps.GrassBounds.MAX_OFFSET), "Approved shell height is unchanged by the bounded vertex program")
 act.contribution.capture(act)
 check(act.contribution.valid and act.contribution.supported and enclosed(act, meshes), "Generated grass encloses all signed offsets through rotated, nonuniform and mirrored transforms")
 check(meshes.all(func(mesh): return mesh.extra_cull_margin >= Maps.GrassBounds.MAX_OFFSET) and meshes[0].extra_cull_margin == original_margin, "Native mesh culling receives the bound and preserves larger authored margins, including shared materials")
 var bindings := preload("res://scripts/atmosphere/material_bindings.gd").new()
 bindings.collect(act.visual, "rooftop_run")
 act.contribution.capture(act)
 check(act.contribution.supported and enclosed(act, meshes), "Private atmosphere shaders retain the recognized displacement envelope")
 var recipe := Recipe.new()
 recipe.capture(act.visual)
 recipe.finish()
 var assets := preload("res://scripts/endless/bake_assets.gd").new()
 assets.share(recipe)
 check(recipe.error.is_empty() and assets.error.is_empty(), "Real grass recipe passes normal bake material conversion")
 var baked := Act.new()
 baked.recipe = recipe
 root.add_child(baked.visual)
 for index in recipe.records.size(): recipe.instantiate_one(index, baked.nodes, baked.visual)
 baked.contribution.capture(baked)
 check(baked.contribution.valid and baked.contribution.supported and baked.contribution.bounds == act.contribution.bounds, "Baked grass retains exact cached bounds and native culling margins")
 var unknown := materials[0].duplicate() as ShaderMaterial
 unknown.shader = Shader.new()
 unknown.shader.code = materials[0].shader.code.replace(Maps.GrassBounds.vertex_code(), "void vertex() { VERTEX.y+=shell_height; }")
 meshes[0].material_override = unknown
 act.contribution.capture(act)
 check(not act.contribution.supported, "A grass tag cannot authorize an unbounded or stale vertex program")
 unknown.shader.code = materials[0].shader.code.replace("VERTEX.y+=", "VERTEX.x+=")
 act.contribution.capture(act)
 check(not act.contribution.supported, "An unrecognized vertex direction fails open")
 meshes[0].material_override = materials[0]
 var next := ShaderMaterial.new()
 next.shader = Shader.new()
 next.shader.code = "shader_type spatial; void vertex() { VERTEX.x+=sin(TIME); }"
 materials[0].next_pass = next
 act.contribution.capture(act)
 check(not act.contribution.supported, "A bounded grass pass cannot hide unknown deformation in a next pass")
 materials[0].next_pass = null
 bindings.restore()
 act.root.free()
 act.visual.free()
 baked.root.free()
 baked.visual.free()
 print("ROOFTOP_GRASS_BOUNDS | ", checks, " checks | ", failures, " failures")
 quit(1 if failures else 0)
