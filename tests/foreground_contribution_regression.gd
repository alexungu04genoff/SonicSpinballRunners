extends SceneTree
const Policy = preload("res://scripts/endless/foreground_contribution.gd")
const Run = preload("res://scripts/prototype/zone_run.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.position = Vector3(0, 10, 5)
 camera.look_at(Vector3.ZERO)
 camera.far = 100
 var light := DirectionalLight3D.new()
 world.add_child(light)
 light.rotation_degrees = Vector3(-15, -90, 0)
 light.shadow_enabled = true
 var policy := Policy.new()
 policy.valid = true
 policy.bounds = AABB(Vector3(-1, 0, -1), Vector3(2, 1, 2))
 check(policy.contributes(camera.get_frustum(), light, -1, camera), "Visible geometry intersects actual camera frustum")
 policy.bounds = AABB(Vector3(-20, 0, -1), Vector3(2, 10, 2))
 check(not Policy.intersects(policy.bounds, camera.get_frustum()), "Tall caster itself is outside camera")
 check(policy.contributes(camera.get_frustum(), light, -1, camera) and policy.reason == "shadow", "Low sun retains off-camera caster whose shadow crosses view")
 light.directional_shadow_max_distance = 1
 check(policy.contributes(camera.get_frustum(), light, -1, camera), "Shadow depth does not incorrectly truncate caster ray length")
 light.rotation_degrees = Vector3(0, 0, 0)
 check(policy.contributes(camera.get_frustum(), light, -1, camera), "Horizontal light fails open")
 light.shadow_enabled = false
 check(not policy.contributes(camera.get_frustum(), light, -1, camera), "Fully irrelevant bounds can be suppressed")
 policy.supported = false
 check(policy.contributes(camera.get_frustum(), light, -1, camera), "Unknown envelope fails open")
 policy.supported = true
 policy.bounds = AABB(Vector3(8, 0, -1), Vector3.ONE)
 camera.fov = 90
 check(policy.contributes(camera.get_frustum(), light, -1, camera), "Wide production projection includes peripheral geometry")
 camera.fov = 20
 check(not policy.contributes(camera.get_frustum(), light, -1, camera), "Zoomed projection rejects the same peripheral geometry")
 var geometry_act := Run.Act.new()
 world.add_child(geometry_act.visual)
 geometry_act.recipe = preload("res://scripts/endless/visual_recipe.gd").new()
 var pivot := Node3D.new()
 geometry_act.visual.add_child(pivot)
 var paddle := MeshInstance3D.new()
 paddle.mesh = BoxMesh.new()
 paddle.mesh.size = Vector3(2, 0.2, 0.2)
 paddle.position.x = 1
 pivot.add_child(paddle)
 geometry_act.nodes.append(pivot)
 geometry_act.recipe.flippers.append(0)
 var rail := MeshInstance3D.new()
 rail.mesh = BoxMesh.new()
 rail.mesh.size = Vector3(10, 0.2, 0.2)
 rail.position = Vector3(0, 4, -8)
 geometry_act.visual.add_child(rail)
 var endpoint := MeshInstance3D.new()
 endpoint.mesh = BoxMesh.new()
 endpoint.position.x = 50
 geometry_act.visual.add_child(endpoint)
 geometry_act.contribution.capture(geometry_act)
 var content_bounds: AABB = geometry_act.contribution.bounds
 check(content_bounds.has_point(Vector3(0, 0, 2)) and content_bounds.has_point(Vector3(0, 4, -8)) and content_bounds.has_point(Vector3(50, 0, 0)), "Actual meshes cover full flipper sweep, elevated geometry and distant endpoint")
 var deformation := ShaderMaterial.new()
 deformation.shader = Shader.new()
 deformation.shader.code = "shader_type spatial; void vertex() { VERTEX.x += sin(TIME); }"
 endpoint.material_override = deformation
 geometry_act.contribution.capture(geometry_act)
 check(not geometry_act.contribution.supported, "Unbounded vertex deformation retains rendering")
 geometry_act.root.free()
 world.free()
 var game := Run.new()
 game.practice_mode = true
 var config := Run.RunPlan.Configuration.new(["res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/Reverse C Spring.tres", "res://data/acts/Authored/Secret Entry.tres"])
 config.zone_count = 1
 config.selected_theme_ids = ["green_hill"]
 game.run_configuration = config
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 180000
 while (not game.started or game.resident.size() < 3 or game.building != null or game.library.busy) and Time.get_ticks_msec() < deadline:
  if not game.library.error.is_empty(): break
  await process_frame
 check(game.started and game.resident.size() == 3, "Three production Acts are resident: " + game.library.error)
 if game.started:
  for frame in 4: await process_frame
  game.controls.input_blocked = true
  game.set_physics_process(false)
  game.ball.freeze = true
  game.auto_launch_time = -1
  var p: Node = game.presentation
  p.set_process(false)
  var original: Transform3D = p.camera.transform
  var neighbor: RefCounted = game.resident.back()
  var runtime: Dictionary = neighbor.runtime
  var node_ids: Array = neighbor.nodes.map(func(node: Node): return node.get_instance_id())
  var modes := [neighbor.root.process_mode, neighbor.visual.process_mode, runtime.mechanics.process_mode]
  game.foreground_contribution_enabled = true
  game._update_foreground_contribution()
  check(game.active.visual.visible, "Active Act always contributes")
  check(not neighbor.visual.visible and neighbor.contribution.valid and neighbor.contribution.supported, "Irrelevant next Act is suppressed")
  check(game.resident.has(neighbor) and neighbor.ready and game.hub.runtimes.has(runtime.mechanics) and modes == [neighbor.root.process_mode, neighbor.visual.process_mode, runtime.mechanics.process_mode], "Suppression preserves residency, readiness and gameplay processing")
  p.reset_camera(neighbor.bounds().get_center())
  game._update_foreground_contribution()
  check(neighbor.visual.visible, "Looking toward adjacent Act restores its visuals")
  check(node_ids == neighbor.nodes.map(func(node: Node): return node.get_instance_id()) and runtime == neighbor.runtime, "Reactivation retains exact node identities and runtime")
  p.set_camera_follow(false)
  game._update_foreground_contribution()
  check(game.resident.all(func(act): return act.visual.visible), "Overview includes every resident Act in view")
  p.set_camera_follow(true)
  p.camera.transform = original
  game.drafting = true
  game.pending_act = neighbor
  game._update_foreground_contribution()
  check(game.resident.all(func(act): return act.visual.visible), "Draft/transition pins both sides")
  game.drafting = false
  game.pending_act = null
  game.transfer = Run.SpawnTransfer.new()
  game.add_child(game.transfer)
  game.transfer.set_process(false)
  game._update_foreground_contribution()
  check(neighbor.visual.visible, "Spawn transfer pins resident contributions")
  game.transfer.free()
  game.transfer = null
  game.foreground_contribution_enabled = false
  game._update_foreground_contribution()
  check(game.resident.all(func(act): return act.visual.visible), "Legacy toggle immediately restores all resident roots")
  var background_state: Array = game.backgrounds.values().map(func(bg): return [bg.layer.view.render_target_update_mode, bg.layer.modulate.a, bg.root.process_mode])
  game.foreground_contribution_enabled = true
  game._update_foreground_contribution()
  check(background_state == game.backgrounds.values().map(func(bg): return [bg.layer.view.render_target_update_mode, bg.layer.modulate.a, bg.root.process_mode]), "Contribution policy never changes background crossfade")
  check(game.score == 0 and game.act_score == 0 and game.ball.serve_pending, "Scoring and served Ball state unchanged")
  var old_score: int = game.score
  var old_masks: Array = runtime.terrain.map(func(item): return [item.body.get_instance_id(), item.body.collision_layer, item.body.collision_mask])
  game.foreground_contribution_enabled = false
  game._update_foreground_contribution()
  game.foreground_contribution_enabled = true
  game._update_foreground_contribution()
  check(old_masks == runtime.terrain.map(func(item): return [item.body.get_instance_id(), item.body.collision_layer, item.body.collision_mask]) and old_score == game.score, "A/B toggles preserve exact collision bodies, masks and score")
  paused = true
  var reused := Run.Act.new()
  var entry: Dictionary = neighbor.plan.duplicate(true)
  entry.sequence = 99
  reused.initialize(game, entry, game.library)
  while not reused.ready:
   for step in 100:
    if not reused.ready: reused.step()
   await process_frame
  check(reused.visual.visible and reused.contribution.valid and reused.visual != neighbor.visual, "Reusing recipe creates fresh visible root without stale hidden state")
  game._queue_retirement(reused.root)
  game._queue_retirement(reused.visual)
  game._queue_retirement(reused.background_visual)
  check(not reused.visual.visible and reused.visual.process_mode == Node.PROCESS_MODE_DISABLED, "Retirement retains existing hide/disable lifecycle")
  paused = false
  print("CONTRIBUTION_BOUNDS | ", game.resident.map(func(act): return {"title": act.document.title, "bounds": str(act.contribution.bounds), "reason": act.contribution.reason, "supported": act.contribution.supported}))
 await game.prepare_to_close()
 game.free()
 print("RESULT | foreground contribution | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
