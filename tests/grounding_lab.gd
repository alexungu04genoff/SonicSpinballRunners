extends SceneTree
## Explicit --script entry point for the portable diagnostics and visual lab.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Endless = preload("res://scripts/diagnostics/grounding_endless.gd")
const Controls = preload("res://scripts/diagnostics/grounding_control.gd")
const Audit = preload("res://scripts/diagnostics/render_audit.gd")
const Sampler = preload("res://scripts/diagnostics/render_sampler.gd")
const THEMES := ["green_hill", "chemical_plant", "rooftop_run", "casino_night", "sky_sanctuary", "ice_cap", "aquarium_park"]
var output := "res://test-results/grounding-lab"
var task := "interactive"
var theme := "rooftop_run"
var runtime := "prototype"
var quality := "production"
var duration := 3.0
var fixture: RefCounted
var game: Node
var controls: CanvasLayer
var sampler := Sampler.new()
var captures: Array[Dictionary] = []
var comparison := "C"
var failures: Array[String] = []
var camera_index := 0
var initial_state := {}
var initial_settings := {}
var startup_ms := 0.0
var initial_mode := 0
var initial_direction := 2
var fresh_defaults := {}
var zone_preparation := {}
var cache_pass := "unspecified"
var reference_digest := ""
var camera_states := {}
var native_camera_far := 0.0
var next_lifecycle_update := 0
var restoration_checks: Array[Dictionary] = []
var capturing := false
var finishing := false
var changing_theme := false
var close_after_theme := false
var lifecycle_checks: Array[Dictionary] = []
var initial_integrity := {}
var integrity_checks := {}
var initial_node_count := 0
var detailed := "--grounding-detailed" in OS.get_cmdline_user_args()

func _initialize() -> void:
 initial_node_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 Engine.time_scale = 0.0
 run.call_deferred()

func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
  if arg.begins_with("--cache-pass="): cache_pass = arg.trim_prefix("--cache-pass=")
  if arg.begins_with("--grounding-task="): task = arg.trim_prefix("--grounding-task=")
  if arg.begins_with("--theme="): theme = arg.trim_prefix("--theme=")
  if arg.begins_with("--grounding-runtime="): runtime = arg.trim_prefix("--grounding-runtime=")
  if arg.begins_with("--grounding-quality="): quality = arg.trim_prefix("--grounding-quality=")
  if arg.begins_with("--grounding-seconds="): duration = clampf(float(arg.trim_prefix("--grounding-seconds=")), 0.5, 15.0)
  if arg.begins_with("--grounding-mode="): initial_mode = int(arg.trim_prefix("--grounding-mode="))
  if arg.begins_with("--grounding-direction="): initial_direction = int(arg.trim_prefix("--grounding-direction="))
  if arg == "--grounding-verbose": sampler.verbose = true
 if theme not in THEMES or task not in ["interactive", "audit", "visual", "matrix", "tour", "smoke", "lifecycle", "controls", "proxy-sweep", "shadow-bench", "ring-study"] or runtime not in ["prototype", "endless"]:
  push_error("Unsupported grounding argument. Lava Reef is excluded.")
  quit(1)
  return
 if quality not in Controls.Review.CASES and quality not in ["shadow-light", "balanced", "balanced-no-retro", "reduced-retro"]:
  push_error("Unknown grounding quality profile.")
  quit(1)
  return
 if DisplayServer.get_name() == "headless":
  push_error("Grounding measurements require a graphical renderer.")
  quit(1)
  return
 root.mode = Window.MODE_WINDOWED
 initial_node_count = get_node_count()
 root.close_requested.connect(finish)
 auto_accept_quit = false
 root.size = Vector2i(1440, 1000) if task in ["interactive", "visual", "audit", "proxy-sweep", "controls"] else Vector2i(1280, 900)
 if task == "interactive": root.size = root.size.min(DisplayServer.screen_get_usable_rect().size - Vector2i(40, 80))
 if task in ["shadow-bench", "ring-study"]: Controls.Review.position_review_window(root)
 Engine.max_fps = 0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 DirAccess.make_dir_recursive_absolute(output)
 Audit.Options.settings_path = output.path_join("isolated-graphics.cfg")
 if FileAccess.file_exists(Audit.Options.settings_path):
  fail("Use a new result folder; fresh-install diagnostics must not inherit settings.")
  quit(1)
  return
 fresh_defaults = Audit.Options.quality()
 Controls.apply_quality(quality, fresh_defaults)
 if not await open_game():
  var partial := {"metadata": Audit.Report.metadata(), "runtime": runtime, "quality": quality,
   "settings_submitted": Audit.Options.quality(), "cache_pass": cache_pass, "failures": failures,
   "timing_by_phase_and_work": sampler.summary(), "elapsed_ms": Time.get_ticks_msec()}
  FileAccess.open(output.path_join("startup-failed.json"), FileAccess.WRITE).store_string(JSON.stringify(partial, "  "))
  quit(1)
  return
 if task == "interactive":
  controls.visible = true
  return
 controls.visible = false
 if task == "shadow-bench":
  await sample("first_stationary_settled", duration)
  if runtime == "endless": await tour_experiments()
  else: await prototype_camera_sweep()
 elif task == "ring-study": await ring_study()
 elif task == "visual": await visual_experiments()
 elif task == "proxy-sweep": await proxy_direction_experiments()
 elif task == "controls": await controls_experiments()
 elif task in ["matrix", "smoke"]: await matrix_experiments(task == "smoke")
 elif task in ["tour", "lifecycle"]: await tour_experiments()
 else:
  await sample("first_stationary_settled", duration)
  await capture("command_line_mode%d" % controls.mode)
 await finish()

func open_game() -> bool:
 sampler.checkpoint_directory = output
 var began := Time.get_ticks_usec()
 if runtime == "prototype":
  fixture = Fixture.new()
  process_frame.connect(startup_tick)
  if not await fixture.open(self, Fixture.DEFAULT_ACT, theme, output):
   process_frame.disconnect(startup_tick)
   fail(fixture.error)
   return false
  process_frame.disconnect(startup_tick)
  game = fixture.game
 else:
  game = Endless.new()
  game.diagnostic_theme = theme
  game.next_theme = "chemical_plant" if theme != "chemical_plant" else "rooftop_run"
  root.add_child(game)
  var deadline := Time.get_ticks_msec() + 180000
  sampler.begin(game)
  while not game.started and game.library.error.is_empty() and Time.get_ticks_msec() < deadline:
   await process_frame
   sampler.tick()
  if not game.started:
   fail("Endless startup failed: " + game.library.error)
   return false
  Audit.Report.disable_native_input(game)
 startup_ms = (Time.get_ticks_usec() - began) / 1000.0
 sampler.begin(game)
 game.controls.input_blocked = true
 if runtime == "prototype": game.fps_label.hide()
 game.auto_launch_time = -1.0
 game.ball.freeze = true
 game.set_physics_process(false)
 game.world.process_mode = Node.PROCESS_MODE_DISABLED
 game.ring_field.process_mode = Node.PROCESS_MODE_DISABLED
 game.presentation.set_process(false)
 paused = true
 if fixture != null:
  fixture.session.set_process(false)
  fixture.session.overlay_root.hide()
 game.retro_filter.set_effects(game.retro_filter.settings.default_effects)
 native_camera_far = game.presentation.camera.far
 if runtime == "endless" and task != "shadow-bench":
  # Matched projection for the A-E experiment; native far coverage is recorded
  # separately and restored for the normal continuous tour.
  game.presentation.camera.far = game.presentation._camera_offset.length() + game.active.document.terrain_bounds().size.length() * TablePresentation.SCALE + 10.0
 remember_camera(0)
 if runtime == "prototype" and task == "visual" and quality == "production":
  for frame in 12: await process_frame
  await RenderingServer.frame_post_draw
  var reference := root.get_texture().get_image()
  reference_digest = Fixture.image_digest(reference)
  reference.save_png(output.path_join("production_reference.png"))
 controls = Controls.new()
 root.add_child(controls)
 controls.configure(game, fresh_defaults)
 controls.set_quality(quality)
 controls.direction = posmod(initial_direction, Controls.DIRECTIONS.size())
 controls.apply_mode(initial_mode)
 controls.capture_requested.connect(func(): capture("interactive_%d" % captures.size()))
 controls.camera_requested.connect(set_camera)
 controls.theme_requested.connect(next_theme, CONNECT_DEFERRED)
 controls.close_requested.connect(finish, CONNECT_DEFERRED)
 RenderingServer.frame_pre_draw.connect(apply_comparison)
 if task == "shadow-bench" and runtime == "endless":
  # Observe the real scheduler. Opening-room frame rate cannot excuse a missed deadline.
  sampler.phase = "zone_preparation"
  var started := Time.get_ticks_msec()
  var ready := false
  while Time.get_ticks_msec() - started < 180000:
   await process_frame
   sampler.tick()
   if game._zone_ready(1) and game.resident.any(func(act): return act.plan.sequence == 3):
    ready = true
    break
   if not game.library.error.is_empty(): break
  zone_preparation = {"next_zone": 1, "backdrop_and_entry_ready": ready, "after_startup_ms": Time.get_ticks_msec() - started,
   "deadline_ms": 180000, "library_error": game.library.error}
  if not ready: fail("Next Zone backdrop and entry Act missed preparation deadline or failed to load.")
 await settle()
 set_camera(0)
 if task in ["matrix", "smoke", "audit", "lifecycle", "tour"]:
  # Offline recipes can contain a pose captured before live camera binding.
  # Resolve the same zero-time presentation in BOTH controlled runtimes, after
  # setting their identical camera. Physics and enemy lifecycle remain frozen.
  for act: RefCounted in game.resident:
   for animation: Dictionary in act.recipe.animations:
    var node: Node = act.nodes[animation.index]
    if animation.script == preload("res://scripts/authored_act/mechanics_presentation.gd"):
     node.elapsed = 0.0
     node._process(0.0)
    elif animation.script == preload("res://scripts/decor/island_flicky.gd"):
     node.set_animation_time(0.0)
 initial_state = state()
 initial_settings = Audit.settings(game)
 var inventory := Audit.inventory(game)
 initial_integrity = integrity_state()
 FileAccess.open(output.path_join("inventory.json"), FileAccess.WRITE).store_string(JSON.stringify(inventory, "  "))
 var casting := 0
 var proxies := 0
 for row: Dictionary in inventory.meshes:
  if row.cast_shadow != 0: casting += row.surfaces
  if row.cast_shadow == 3: proxies += 1
 sampler.inventory_counts = {"caster_surfaces": casting, "shadow_only_meshes": proxies, "inventory_at": "settled_opening"}
 print("GROUNDING_READY | ", theme, " | ", runtime, " | ", quality, " | startup_ms=", startup_ms)
 return true

func startup_tick() -> void:
 if fixture == null or not is_instance_valid(fixture.session) or not is_instance_valid(fixture.session.game): return
 var starting_game: Node = fixture.session.game
 if sampler.game != starting_game: sampler.begin(starting_game)
 sampler.tick()

func settle() -> void:
 var quiet := 0
 var deadline := Time.get_ticks_msec() + 180000
 sampler.phase = "preparation"
 while quiet < 12 and Time.get_ticks_msec() < deadline:
  await process_frame
  sampler.tick()
  if sampler.work_phase() == "settled": quiet += 1
  else: quiet = 0
 if quiet < 12: fail("Preparation did not settle before its deadline.")

func set_camera(index: int) -> void:
 camera_index = index
 if camera_states.has(index):
  var saved: Dictionary = camera_states[index]
  var camera: Camera3D = game.presentation.camera
  camera.transform = saved.transform
  camera.far = saved.far
  camera.fov = saved.fov
  camera.size = saved.size
  camera.projection = saved.projection
  game.presentation.camera_focus = saved.focus
  game.presentation.camera_target = saved.target
  game.presentation.camera_settings.zoom = saved.zoom
  game.presentation._camera_offset = saved.offset
  game._update_backgrounds()
  if is_instance_valid(controls): controls.set_overlay(controls.overlay)
  return
 var target: Vector2 = game.ball.position
 if index == 1: target = Vector2(570, 500)
 if index == 2: target = Vector2(570, 240)
 game.presentation.camera_settings.zoom = 1.3 if index == 0 else 0.8
 game.presentation.reset_camera(target)
 remember_camera(index)
 game._update_backgrounds()
 if is_instance_valid(controls): controls.set_overlay(controls.overlay)

func remember_camera(index: int) -> void:
 var camera: Camera3D = game.presentation.camera
 camera_states[index] = {"transform": camera.transform, "far": camera.far, "fov": camera.fov, "size": camera.size,
  "projection": camera.projection, "focus": game.presentation.camera_focus, "target": game.presentation.camera_target,
  "zoom": game.presentation.camera_settings.zoom, "offset": game.presentation._camera_offset}

func state() -> Dictionary:
 var enemies: Array[Dictionary] = []
 for item: Dictionary in game.active.runtime.mechanics.by_id.values():
  if item.type == "buzz_bomber": enemies.append({"id": item.object_id, "position": str(item.position), "alive": item.alive, "direction": item.direction})
 return {"act_fingerprint": game.active.document.fingerprint(), "act_path": game.library.paths[game.active.plan.id],
  "enemies": enemies,
  "ball": str(game.ball.position), "velocity": str(game.ball.linear_velocity), "score": game.score, "rings": game.rings_collected,
  "camera_transform": var_to_str(game.presentation.camera.global_transform), "camera_projection": game.presentation.camera.projection,
  "camera_fov": game.presentation.camera.fov, "camera_size": game.presentation.camera.size,
  "camera_far": game.presentation.camera.far, "world_size": str(game.view.size), "window": str(root.size),
  "atmosphere": game.active.plan.atmosphere.duplicate(true)}

func sample(label: String, seconds: float) -> void:
 sampler.phase = label + "_settling"
 for frame in 8:
  await process_frame
  sampler.tick()
 sampler.phase = label
 var until := Time.get_ticks_msec() + int(seconds * 1000.0)
 while Time.get_ticks_msec() < until:
  await process_frame
  sampler.tick()
 print("GROUNDING_SAMPLE | ", label, " | ", JSON.stringify(sampler.summary().get(label + "/settled", {})))

func capture(label: String) -> void:
 capturing = true
 var was_visible: bool = controls.visible
 controls.hide()
 for frame in 4: await process_frame
 await RenderingServer.frame_post_draw
 var file := label.validate_filename() + ".png"
 var image := root.get_texture().get_image()
 if image.save_png(output.path_join(file)) != OK: fail("Could not save " + file)
 captures.append({"image": file, "label": label, "mode": controls.mode, "direction": controls.direction, "direction_label": controls.DIRECTIONS[controls.direction],
  "quality": controls.quality, "proxy_method": controls.proxy_method, "proxy_receipt": controls.proxy.receipt.duplicate(true),
  "state": state(), "settings": Audit.settings(game), "image_digest": Fixture.image_digest(image)})
 controls.visible = was_visible
 FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE).store_string(JSON.stringify(captures, "  "))
 if task == "interactive": sampler.write(output, {"captures": captures, "interactive": true, "theme": theme})
 sampler.previous = Time.get_ticks_usec()
 capturing = false

func visual_experiments() -> void:
 for retro: String in ["production", "off"]:
  game.retro_filter.set_effects(controls.production_retro if retro == "production" else [])
  game._update_backgrounds()
  set_camera(0)
  for index in Controls.DIRECTIONS.size():
   controls.direction = index
   controls.apply_mode(0 if index == 0 else 1)
   if index in [0, 1]: await sample("sweep_%s_%d" % [retro, index], duration)
   await capture("sweep_%s_%d" % [retro, index])
   if retro == "production" and index == 0 and not reference_digest.is_empty() and captures[-1].image_digest != reference_digest:
    fail("Mode 0 differs from the untouched production reference.")
  if theme in controls.Proxy.THEMES:
   set_camera(1)
   controls.direction = initial_direction
   for method: String in ["source", "hull"]:
    controls.proxy_method = method
    for index in 6:
     if method == "hull" and index not in [2, 3]: continue
     controls.apply_mode(index)
     await sample("visual_%s_%s_mode%d" % [retro, method, index], duration)
     await capture("grounding_%s_%s_%d" % [retro, method, index])
   controls.apply_mode(3)
   controls.reveal = true
   controls.proxy.set_visible(game, true, true)
   await capture("alignment_%s" % retro)
   controls.reveal = false
  controls.apply_mode(0)
  set_camera(0)
  await capture("restored_%s" % retro)
  var original := captures.filter(func(item): return item.label == "sweep_%s_0" % retro)
  if not original.is_empty():
   var exact: bool = original[0].image_digest == captures[-1].image_digest
   restoration_checks.append({"retro": retro, "exact_pixels": exact, "exact_state": original[0].state == captures[-1].state,
    "exact_settings": original[0].settings == captures[-1].settings, "before": original[0].image, "after": captures[-1].image})
   # Keep the exact result as evidence. Mode 0 versus the untouched reference
   # remains a strict parity check. After changing shadow maps, tiny GPU rounding
   # differences are reported separately from exact state/material restoration;
   # no permanent image-error threshold is invented here.
   if not exact: print("GROUNDING_PIXEL_DIFFERENCE | ", retro, " restoration; compare saved images and exact-state receipts")
 controls.set_overlay(1)
 await capture("ownership_casters")
 controls.set_overlay(3)
 await capture("ownership_shadowless")
 controls.set_overlay(0)

func matrix_experiments(short: bool) -> void:
 controls.apply_mode(0)
 await sample("first_stationary_settled", duration)
 await capture("stationary_baseline")
 if runtime == "endless":
  game.presentation.camera.far = native_camera_far
  game._update_backgrounds()
  await sample("endless_native_far", duration)
  await capture("endless_native_far")
  set_camera(0)
 var cases := ["A"] if runtime == "prototype" else (["B", "C", "D", "E", "C"] if detailed or short else [])
 for index in cases.size():
  comparison = cases[index]
  await sample("architecture_%s_%d" % [comparison, index], duration)
  await capture("architecture_%s_%d" % [comparison, index])
 comparison = "C"
 if not short:
  if detailed:
   var production_divisor: float = game.retro_filter.settings.n64_resolution_divisor
   for matched: bool in [false, true]:
    for effect: int in [0, 1, 2, 3, 4, -1]:
     game.retro_filter.set_effects(controls.production_retro if effect == -1 else ([] if effect == 0 else [effect]))
     if matched:
      game.retro_filter._resolution_divisor = production_divisor
      game.retro_filter._refresh_output()
     game._update_backgrounds()
     var label := "retro_%s_%d" % ["matched_pixels" if matched else "native_preset", effect]
     await sample(label, duration)
     await capture(label)
   controls.set_quality(quality)
  if runtime == "endless": await tour_experiments()

func proxy_direction_experiments() -> void:
 game.retro_filter.set_effects([])
 game._update_backgrounds()
 set_camera(1)
 controls.proxy_method = "source"
 for index in Controls.DIRECTIONS.size():
  controls.direction = index
  for enabled: bool in [false, true]:
   controls.apply_mode(3 if enabled else 1)
   await capture("proxy_direction_%d_%d" % [index, int(enabled)])
 controls.apply_mode(0)
 set_camera(0)

func prototype_camera_sweep() -> void:
 # A single authored Act has no Zone crossing. Move its normal camera through a fixed path.
 var start: Vector2 = game.ball.position
 var target := Vector2(570, 240)
 var began := Time.get_ticks_usec()
 sampler.phase = "prototype_camera_sweep"
 sampler.previous = began
 while Time.get_ticks_usec() - began < duration * 1000000.0:
  var t := clampf((Time.get_ticks_usec() - began) / (duration * 1000000.0), 0.0, 1.0)
  game.presentation.reset_camera(start.lerp(target, t))
  game._update_backgrounds()
  await process_frame
  sampler.tick()

func ring_study() -> void:
 # Same baked Ring, camera and phase on both sides of each pair. Full Retro stays active.
 var presentation: Node = game.presentation
 var ring: MeshInstance3D
 for candidate: MeshInstance3D in presentation.ring_visuals:
  if candidate.is_visible_in_tree():
   ring = candidate
   break
 if ring == null:
  fail("Ring study needs a visible collectible.")
  return
 var target := TablePresentation.unmap_point(ring.global_position)
 presentation.reset_camera(target)
 game._update_backgrounds()
 await settle()
 var study := {"settings": Audit.settings(game), "ring": str(ring.get_path()), "frames": []}
 for index in 24:
  var phase := index * PI / 24.0
  presentation.ring_spin.spin(phase)
  for slot: int in presentation.ring_spin.fallback_indices:
   presentation.ring_visuals[slot].rotation = Vector3(PI * 0.5, phase, 0)
  for enabled: bool in [true, false]:
   Controls.Review.show_ring_shadows(presentation.ring_visuals, enabled)
   for frame in 3: await process_frame
   await RenderingServer.frame_post_draw
   var img := root.get_texture().get_image()
   var file := "ring_%02d_%s.png" % [index, "on" if enabled else "off"]
   if img.save_png(output.path_join(file)) != OK: fail("Cannot save " + file)
   study.frames.append({"image": file, "phase_rad": phase, "ring_shadows": enabled})
 Controls.Review.show_ring_shadows(presentation.ring_visuals, true)
 FileAccess.open(output.path_join("ring-study.json"), FileAccess.WRITE).store_string(JSON.stringify(study, "  "))

func overlap_comparison() -> void:
 var last_act: RefCounted
 for act: RefCounted in game.resident:
  if act.plan.sequence == 2: last_act = act
 if last_act == null or not game.backgrounds.has(1):
  fail("Overlap comparison needs the prepared next Zone.")
  return
 if not game.touring: game.toggle_tour()
 game.tour_speed = 0.0
 game._activate(last_act)
 game.presentation.tour_focus = Vector2(last_act.bounds().get_center().x, game.backgrounds[1].entrance_y - 25.0)
 game.presentation._update_camera(0.0)
 game._update_backgrounds()
 for index in 4:
  comparison = ["C", "D", "E", "B"][index]
  await sample("overlap_architecture_" + comparison, duration)
  await capture("overlap_architecture_" + comparison)
 comparison = "C"

func apply_comparison() -> void:
 if not is_instance_valid(game) or not game.started: return
 if is_instance_valid(controls): controls.proxy.update_visibility(game, controls.mode in [2, 3, 4])
 if comparison == "B":
  for act: RefCounted in game.resident:
   act.visual.visible = act == game.active
   act.background_visual.visible = act == game.active
 else:
  for act: RefCounted in game.resident: act.background_visual.visible = true
 for zone: int in game.backgrounds:
  var layer: SubViewportContainer = game.backgrounds[zone].layer
  var hide: bool = comparison == "E" or (comparison in ["B", "D"] and zone != game._background_zone)
  layer.visible = not hide
  if hide: layer.view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func tour_experiments() -> void:
 if runtime != "endless": return
 controls.apply_mode(0)
 controls.set_quality(quality)
 comparison = "C"
 paused = false
 Engine.time_scale = 1.0
 game.presentation.set_process(true)
 game.presentation.camera.far = native_camera_far
 if not game.touring: game.toggle_tour()
 game.tour_speed = 100.0
 await sample("tour_100px_s", duration)
 await capture("tour_100")
 game.tour_speed = 400.0
 await sample("tour_400px_s", duration)
 # Relocation is excluded from measured phases. The following crossing uses
 # the normal tour code and real scheduler; no readiness or residency shortcut.
 await settle()
 if detailed: await overlap_comparison()
 var last_act: RefCounted
 for act: RefCounted in game.resident:
  if act.plan.sequence == 2: last_act = act
 if last_act == null or not game.backgrounds.has(1):
  fail("Transition fixture could not find the first Zone's final Act.")
  return
 game._activate(last_act)
 var entrance: float = game.backgrounds[1].entrance_y
 game.presentation.tour_focus = Vector2(last_act.bounds().get_center().x, entrance + 260.0)
 var previous_proxies: Array[WeakRef] = []
 if task == "lifecycle":
  controls.apply_mode(3)
  for node: Node3D in controls.proxy.roots: previous_proxies.append(weakref(node))
 game.tour_speed = 100.0
 sampler.phase = "transition_relocation_excluded"
 for frame in 8: await process_frame; sampler.tick()
 sampler.phase = "zone_transition"
 var deadline := Time.get_ticks_msec() + 35000
 var captured := false
 while game._background_zone < 1 and Time.get_ticks_msec() < deadline:
  await process_frame
  sampler.tick()
  if task == "lifecycle":
   controls.update_lifecycle()
   if game.background_blend > 0.0:
    for node: Node3D in controls.proxy.roots:
     if is_instance_valid(node) and node.visible: fail("Proxy remained visible during Zone crossfade: blend=%s zone=%d owner=%s" % [game.background_blend, game._background_zone, node.get_meta("grounding_zone")])
  if game.background_blend > 0.3 and not captured:
   await capture("zone_overlap")
   captured = true
 game.tour_speed = 0.0
 if game._background_zone < 1: fail("Transition timed out; preserve partial counters and logs.")
 await settle()
 await sample("post_transition_settled", duration)
 await capture("post_transition")
 Engine.time_scale = 0.0
 paused = true
 game.presentation.set_process(false)
 if task == "lifecycle":
  controls.update_lifecycle()
  var retired := true
  for reference: WeakRef in previous_proxies: retired = retired and reference.get_ref() == null
  if not retired: fail("Old Zone proxy survived ownership change.")
  lifecycle_checks.append({"old_zone_proxies_retired": retired, "transition_completed": game._background_zone >= 1})
 if detailed or task == "lifecycle": await verify_proxy_lifecycle()

func verify_proxy_lifecycle() -> void:
 # Exercise ownership at a real retired/prepared Zone boundary, outside timing.
 sampler.phase = "proxy_lifecycle_excluded"
 controls.apply_mode(3)
 controls.update_lifecycle()
 var owners: Array[WeakRef] = []
 for node: Node3D in controls.proxy.roots:
  owners.append(weakref(node))
  var valid_zone: bool = not node.visible or int(node.get_meta("grounding_zone")) == game._background_zone
  if not valid_zone: fail("Proxy escaped its Zone ownership.")
 var before := Audit.inventory(game)
 var light_count: int = before.lights.size()
 var proxy_count: int = controls.proxy.geometry.size()
 controls.apply_mode(0)
 await process_frame
 var removed := true
 for owner: WeakRef in owners: removed = removed and owner.get_ref() == null
 var after := Audit.inventory(game)
 if not removed: fail("Proxy nodes survived mode restoration.")
 if after.lights.size() != light_count: fail("Proxy trial changed light ownership.")
 lifecycle_checks.append({"zone": game._background_zone, "created_proxy_meshes": proxy_count, "removed_on_restore": removed,
  "light_count_unchanged": after.lights.size() == light_count, "backgrounds": Audit.settings(game).viewports})

func next_theme() -> void:
 if changing_theme or task not in ["interactive", "controls"] or runtime != "prototype": return
 changing_theme = true
 var next: String = THEMES[(THEMES.find(theme) + 1) % THEMES.size()]
 write_report()
 controls.restore()
 controls.free()
 RenderingServer.frame_pre_draw.disconnect(apply_comparison)
 await fixture.close()
 sampler = Sampler.new()
 captures.clear()
 theme = next
 camera_states.clear()
 output = output.get_base_dir().path_join("lab_" + theme + "_" + str(Time.get_ticks_msec()))
 DirAccess.make_dir_recursive_absolute(output)
 var opened := await open_game()
 changing_theme = false
 if not opened: quit(1)
 elif close_after_theme: await finish()

func press_key(key: Key) -> void:
 var event := InputEventKey.new()
 event.keycode = key
 event.pressed = true
 root.push_input(event)
 for frame in 8: await process_frame

func controls_experiments() -> void:
 controls.show()
 for index in 6:
  await press_key(KEY_F1)
  if controls.mode != (index + 1) % 6: fail("F1 mode routing failed.")
 var sun: int = controls.direction
 await press_key(KEY_F2)
 if controls.direction != (sun + 1) % Controls.DIRECTIONS.size(): fail("F2 sun routing failed.")
 await press_key(KEY_F3)
 if controls.overlays.is_empty(): fail("F3 ownership overlay did not create bounds.")
 await press_key(KEY_F4)
 if not game.retro_filter.selected_effects.is_empty(): fail("F4 Retro routing failed.")
 await press_key(KEY_F5)
 if not controls.reveal: fail("F5 reveal routing failed.")
 await press_key(KEY_F6)
 if controls.proxy_method != "hull": fail("F6 hull routing failed.")
 await press_key(KEY_F7)
 if camera_index != 1: fail("F7 camera routing failed.")
 await press_key(KEY_F10)
 if controls.quality != "shadow-light": fail("F10 quality routing failed.")
 await press_key(KEY_F9)
 while capturing: await process_frame
 if captures.is_empty(): fail("F9 capture routing failed.")
 var before := theme
 await press_key(KEY_F8)
 var deadline := Time.get_ticks_msec() + 180000
 while (changing_theme or theme == before or not is_instance_valid(controls) or not is_instance_valid(game) or not game.started) and Time.get_ticks_msec() < deadline:
  await process_frame
 if theme == before: fail("F8 theme routing failed.")
 await settle()
 controls.show()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("interactive-controls.png"))
 print("GROUNDING_CONTROLS | F1-F10 input routes checked; Escape/window close use the same verified finish handler")

func _process(_delta: float) -> bool:
 if task == "interactive" and is_instance_valid(controls) and is_instance_valid(game) and game.started:
  sampler.phase = "capture_excluded" if capturing else "interactive_mode%d_camera%d_%s" % [controls.mode, camera_index, controls.quality]
  sampler.tick()
  if Time.get_ticks_msec() >= next_lifecycle_update:
   next_lifecycle_update = Time.get_ticks_msec() + 250
   controls.update_lifecycle()
 return false

func fail(message: String) -> void:
 failures.append(message)
 push_error(message)

func integrity_state() -> Dictionary:
 # Only at the beginning/end of frozen visual trials, never in a frame sampler.
 var physics := {}
 var materials := {}
 var lights := {}
 var nodes: Array[Node] = [game]
 while not nodes.is_empty():
  var node: Node = nodes.pop_back()
  nodes.append_array(node.get_children())
  if node is CollisionObject2D:
   physics[node.get_instance_id()] = [str(node.transform), node.collision_layer, node.collision_mask]
  if node is CollisionShape2D:
   physics[node.get_instance_id()] = [str(node.transform), node.disabled, str(node.shape)]
  if node is Light3D:
   lights[node.get_instance_id()] = [var_to_str(node.transform), node.light_energy, str(node.light_color), node.shadow_enabled, node.light_cull_mask]
  var mesh := Audit.mesh_of(node)
  if mesh == null: continue
  for surface in mesh.get_surface_count():
   var material: Material = node.get_active_material(surface) if node is MeshInstance3D else (node.material_override if node.material_override != null else mesh.surface_get_material(surface))
   if material == null or materials.has(material.get_instance_id()): continue
   var properties := {}
   for property: Dictionary in material.get_property_list():
    if int(property.usage) & PROPERTY_USAGE_STORAGE: properties[str(property.name)] = str(material.get(property.name))
   materials[material.get_instance_id()] = properties
 return {"physics": physics, "materials": materials, "lights": lights}

func finish() -> void:
 if changing_theme:
  close_after_theme = true
  return
 if finishing: return
 finishing = true
 var watched := watch_owners()
 var measured_settings := Audit.settings(game)
 controls.restore()
 comparison = "C"
 game._update_backgrounds()
 if task in ["visual", "proxy-sweep"]:
  var restored := integrity_state()
  for field: String in ["physics", "materials", "lights"]:
   integrity_checks[field] = initial_integrity[field] == restored[field]
   if not integrity_checks[field]: fail("Visual trial changed production " + field + ".")
 if FileAccess.file_exists(Audit.Options.settings_path): fail("Diagnostic wrote persistent graphics preferences.")
 if game.library.fallback_builds != 0: fail("Runtime geometry regeneration occurred.")
 write_report(measured_settings)
 print("GROUNDING_COMPLETE | ", output, " | failures=", failures.size())
 RenderingServer.frame_pre_draw.disconnect(apply_comparison)
 controls.free()
 Engine.time_scale = 1.0
 paused = false
 if fixture != null: await fixture.close()
 else:
  await game.prepare_to_close()
  game.free()
 for frame in 4: await process_frame
 var remaining: Array[String] = []
 for key: String in watched:
  if watched[key].get_ref() != null: remaining.append(key)
 var teardown := {"remaining_project_owners": remaining, "nodes_before": initial_node_count,
  "nodes_after": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}
 FileAccess.open(output.path_join("teardown.json"), FileAccess.WRITE).store_string(JSON.stringify(teardown, "  "))
 if not remaining.is_empty(): fail("Diagnostic retained project owners: " + str(remaining))
 quit(0 if failures.is_empty() else 1)

func write_report(measured_settings: Dictionary = {}) -> void:
 sampler.write(output, {"cache_pass": cache_pass, "zone_preparation": zone_preparation, "task": task, "theme": theme, "runtime": runtime, "quality": quality, "startup_ms": startup_ms,
  "initial_state": initial_state, "native_camera_far": native_camera_far, "initial_settings": initial_settings, "captures": captures, "failures": failures,
  "restoration_checks": restoration_checks, "lifecycle_checks": lifecycle_checks,
  "integrity_checks": integrity_checks,
  "production_defaults_changed": false, "user_settings_written": FileAccess.file_exists(Audit.Options.settings_path)}, measured_settings)

func watch_owners() -> Dictionary:
 var watched := {"game": weakref(game), "presentation": weakref(game.presentation), "library": weakref(game.library), "controls": weakref(controls)}
 for act: RefCounted in game.resident: watched["act_%d" % act.plan.sequence] = weakref(act)
 for zone: int in game.backgrounds: watched["backdrop_%d" % zone] = weakref(game.backgrounds[zone].layer)
 for index in controls.proxy.roots.size(): watched["proxy_%d" % index] = weakref(controls.proxy.roots[index])
 return watched
