extends SceneTree
## CPU lifecycle/bake checks; graphical runs compare real Standard/shader pixels.
const Spin = preload("res://scripts/ring_spin.gd")
const Recipe = preload("res://scripts/endless/visual_recipe.gd")
const Assets = preload("res://scripts/endless/bake_assets.gd")
const StaticBatches = preload("res://scripts/endless/static_batches.gd")
const Manifest = preload("res://scripts/endless/warm_manifest.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
const Presentation = preload("res://scripts/endless/endless_presentation.gd")
const Policy = preload("res://scripts/endless/foreground_contribution.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func rings(parent: Node3D, material: Material) -> Array[MeshInstance3D]:
 var mesh := TorusMesh.new()
 mesh.inner_radius = 0.066
 mesh.outer_radius = 0.12
 mesh.rings = 12
 mesh.ring_segments = 6
 var result: Array[MeshInstance3D] = []
 for i in 35:
  var node := MeshInstance3D.new()
  node.mesh = mesh
  node.material_override = material
  node.position = Vector3(0.15 + (i % 7) * 0.25, 0.23 + (i % 3) * 0.15, 0.15 + (i / 7) * 0.25)
  parent.add_child(node)
  result.append(node)
 return result

func lifecycle() -> void:
 var p := Presentation.new()
 root.add_child(p)
 p.set_process(false)
 p.ring_field = RingField.new()
 p.add_child(p.ring_field)
 p.ring_field.set_physics_process(false)
 p.ring_field.pickup_claimed.connect(p._on_ring_claimed)
 p.ring_field.rack_reset.connect(p.clear_ring_pickups)
 p.ring_visuals = rings(p, Registry.create("green_hill").material(Color("ffd568"), 0.08))
 var special: MeshInstance3D = p.ring_visuals[0].duplicate()
 special.material_override = special.material_override.duplicate()
 special.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 p.add_child(special)
 p.ring_visuals.append(special)
 check(Spin.prepare(p.ring_visuals) == 35 and special.material_override is StandardMaterial3D, "Ordinary Rings share GPU spin; unsupported surfaces retain their Standard path")
 var recipe := Recipe.new()
 for node: MeshInstance3D in p.ring_visuals: recipe.capture(node)
 recipe.finish(p)
 var assets := Assets.new()
 assets.share(recipe)
 StaticBatches.new().optimize(recipe)
 Manifest.new().prepare(recipe)
 check(recipe.error.is_empty() and assets.error.is_empty() and recipe.has_warm_manifest(), "Canonical assets, static batching and warm manifests preserve individual Ring bindings")
 var material_list: Array[Material] = []
 material_list.assign(assets.materials.values())
 var probes: Resource = Manifest.new().build_probes(material_list)
 var signatures := PackedStringArray()
 for record: Dictionary in probes.records: signatures.append_array(record.warm_signatures)
 var covered := true
 for index: int in recipe.rings:
  for signature: String in recipe.records[index].warm_signatures: covered = covered and signature in signatures
 check(covered, "Offline probes cover the exact live Ring material and geometry features")
 var saved := "user://ring-spin-regression.res"
 check(ResourceSaver.save(recipe, saved) == OK, "GPU Ring recipe saves to disk")
 var loaded: Resource = ResourceLoader.load(saved, "", ResourceLoader.CACHE_MODE_IGNORE)
 check(loaded.has_warm_manifest() and loaded.rings.size() == 36, "Disk reload retains every original Ring binding")
 for node: MeshInstance3D in p.ring_visuals: node.free()
 p.ring_visuals.clear()
 var live := Node3D.new()
 live.position = Vector3(3, 0, -40)
 p.add_child(live)
 var nodes: Array[Node] = []
 for i in loaded.records.size(): loaded.instantiate_one(i, nodes, live)
 for index: int in loaded.rings:
  var node: MeshInstance3D = nodes[index]
  p.ring_visuals.append(node)
  p.ring_spin.append(node)
  var at := TablePresentation.unmap_point(node.global_position)
  p.ring_field.rings.append({"home": at, "position": at, "active": true, "height": (node.global_position.y - TablePresentation.RING_HEIGHT) / TablePresentation.SCALE})
 check(p.ring_spin.materials.size() == 1 and p.ring_spin.fallback_indices == [35], "Resident registration deduplicates actual shared materials and identifies CPU fallbacks")
 var unchanged := true
 p._update_ring_visuals(0.1)
 for i in 35: unchanged = unchanged and p.ring_visuals[i].basis.is_equal_approx(Basis.IDENTITY)
 check(unchanged and not p.ring_visuals[35].basis.is_equal_approx(Basis.IDENTITY), "Resting GPU Rings need zero CPU transform writes while unsupported Rings still spin")
 check((p.ring_spin.materials[0].get_shader_parameter("ring_rotation") as Basis).is_equal_approx(Spin.spin_basis(p.ring_spin_phase)), "Shared GPU basis matches legacy Euler spin")
 var bounds_valid := true
 for i in 35:
  var node := p.ring_visuals[i]
  bounds_valid = bounds_valid and Spin.bound(node)
  var vertices: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  for phase in [0.0, 0.37, PI * 0.5, PI, TAU - 0.01]:
   for vertex: Vector3 in vertices: bounds_valid = bounds_valid and node.custom_aabb.grow(0.00001).has_point(Spin.spin_basis(phase) * vertex)
 check(bounds_valid, "Every saved Ring has native all-angle bounds enclosing every sampled vertex")
 p.ball_visual = MeshInstance3D.new()
 p.add_child(p.ball_visual)
 p.ball_visual.position = Vector3(5, 0.2, -38)
 check(p.ring_field.claim_ring(4) and not p.ring_field.claim_ring(4), "Collection remains atomic through the real RingField signal")
 p._update_ring_visuals(0.1)
 var flight := p.ring_visuals[4]
 check(flight.visible and flight.global_position.is_equal_approx((p.ring_pickups[4].start as Vector3).lerp(p.ball_visual.global_position, 0.25)), "GPU pickup retains the existing accelerating flight at streamed world coordinates")
 var frozen := flight.transform
 p._update_ring_visuals(0)
 check(flight.transform.is_equal_approx(frozen), "Zero-delta pause freezes pickup movement, shrink and spin")
 p._update_ring_visuals(0.1)
 check(not flight.visible and p.ring_pickups.is_empty(), "Pickup hides exactly once at the existing 0.20-second duration")
 p.clear_ring_pickups()
 check(not flight.visible, "Clearing flights respects inactive Ring state")
 p.ring_field.reset_rings()
 check(flight.visible and flight.scale.is_equal_approx(Vector3.ONE) and flight.global_position.is_equal_approx(TablePresentation.map_point(p.ring_field.rings[4].home, flight.position.y)), "Rack reset restores visibility, home and unit scale")
 # Streaming rebuilds register existing nodes without resetting phase or IDs.
 var ids: Array = p.ring_visuals.map(func(node): return node.get_instance_id())
 p.ring_spin.clear()
 for node: MeshInstance3D in p.ring_visuals: p.ring_spin.append(node)
 p._update_ring_visuals(0)
 check(p.ring_visuals.map(func(node): return node.get_instance_id()) == ids and p.ring_spin.materials.size() == 1, "Re-registration preserves nodes and refreshes the current material phase")
 var policy := Policy.new()
 policy._collect(live)
 check(policy.supported, "Exact shared Ring shader keeps foreground contribution culling enabled")
 var rogue := MultiMeshInstance3D.new()
 rogue.material_override = p.ring_visuals[0].material_override
 live.add_child(rogue)
 policy._collect(live)
 check(not policy.supported, "The shader on geometry without a proven mesh envelope fails open")
 p.ring_spin.clear()
 p.ring_spin.enabled = false
 for node: MeshInstance3D in p.ring_visuals: p.ring_spin.append(node)
 p._update_ring_visuals(0.1)
 check(p.ring_spin.materials.is_empty() and p.ring_spin.fallback_indices.size() == 36 and p.ring_visuals[0].material_override is StandardMaterial3D and p.ring_visuals[0].basis.is_equal_approx(Spin.spin_basis(p.ring_spin_phase)), "Same-bake legacy A/B restores original material, CPU spin and automatic instancing")
 p.ring_field.claim_ring(4)
 p._update_ring_visuals(0.1)
 check(p.ring_visuals[4].visible and p.ring_pickups.has(4), "Legacy/fallback pickups stay visible throughout flight")
 p._update_ring_visuals(0.1)
 check(not p.ring_visuals[4].visible and p.ring_pickups.is_empty(), "Legacy/fallback pickups complete normally")
 p.ring_spin.clear()
 p.free()

func appearance() -> void:
 var view := SubViewport.new()
 view.size = Vector2i(384, 320)
 view.msaa_3d = Viewport.MSAA_4X
 view.own_world_3d = true
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 2.8
 view.add_child(camera)
 camera.position = Vector3(2.4, 3.4, 3.2)
 camera.look_at(Vector3(0.9, 0.25, 0.65))
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-55, -25, 0)
 light.shadow_enabled = true
 view.add_child(light)
 for theme_id: String in Registry.IDS:
  var source: StandardMaterial3D = Registry.create(theme_id).material(Color("ffd568"), 0.08)
  var holder := Node3D.new()
  view.add_child(holder)
  var visuals := rings(holder, source)
  check(Spin.prepare(visuals) == 35, theme_id + " supports GPU Ring rotation")
  var material := visuals[0].material_override as ShaderMaterial
  if material == null: holder.free(); continue
  check(material.get_shader_parameter("paint") == source.albedo_color and material.get_shader_parameter("surface_roughness") == source.roughness and material.get_shader_parameter("surface_specular") == source.metallic_specular and material.get_shader_parameter("emission_scale") == source.emission_energy_multiplier, theme_id + " preserves surface and glow values")
  if DisplayServer.get_name() != "headless":
   for phase in [0.0, 0.7, 2.1]:
    for node: MeshInstance3D in visuals: node.basis = Spin.spin_basis(phase); node.material_override = source
    await process_frame
    await RenderingServer.frame_post_draw
    var before := view.get_texture().get_image()
    var blank := before.duplicate()
    blank.fill(before.get_pixel(0, 0))
    check(before.compute_image_metrics(blank, false).mean > 0.005, theme_id + " comparison contains visible Rings")
    var legacy_draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
    for node: MeshInstance3D in visuals: node.basis = Basis.IDENTITY; node.material_override = material
    material.set_shader_parameter("ring_rotation", Spin.spin_basis(phase))
    await process_frame
    await RenderingServer.frame_post_draw
    var after := view.get_texture().get_image()
    var metrics := before.compute_image_metrics(after, false)
    var gpu_draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
    print("RING_PIXELS | %s phase=%.2f mean=%s max=%s draws=%d->%d" % [theme_id, phase, metrics.mean, metrics.max, legacy_draws, gpu_draws])
    check(metrics.mean < 0.002, theme_id + " rendered Standard/GPU appearance remains equivalent")
    check(gpu_draws <= legacy_draws, "GPU spin preserves automatic instancing without extra submissions")
    if phase == 0.0 and OS.get_cmdline_user_args().has("--capture"):
     DirAccess.make_dir_recursive_absolute("res://test-results")
     before.save_png("res://test-results/ring-" + theme_id + "-legacy.png")
     after.save_png("res://test-results/ring-" + theme_id + "-gpu.png")
  holder.free()
 view.free()

func run() -> void:
 if not OS.get_cmdline_user_args().has("--appearance-only"): lifecycle()
 await appearance()
 print("RESULT | Ring spin | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
