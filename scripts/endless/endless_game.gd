extends "res://scripts/game.gd"
## Endless is a playfield source for the existing engine, not a second physics loop.
const Plan = preload("res://scripts/endless/endless_plan.gd")
const Library = preload("res://scripts/endless/template_library.gd")
const Backdrop = preload("res://scripts/endless/zone_backdrop.gd")
const Act = preload("res://scripts/endless/streamed_act.gd")
const StreamPresentation = preload("res://scripts/endless/endless_presentation.gd")
const Hub = preload("res://scripts/endless/mechanics_hub.gd")
const Character = preload("res://experiments/visual_lab/sonic_presenter.gd")
const RetroFilter = preload("res://scripts/retro/retro_filter.gd")
const RetroControls = preload("res://scripts/retro/retro_controls.gd")
var retro_filter: RetroFilter
var retro_controls: CanvasLayer
var _composite_view: SubViewport
var run_seed := 18
var _opening_document: Resource
var planner: RefCounted
var library: Node
var hub: Node
var resident: Array = []
var pending: Array[Dictionary] = []
var building: RefCounted
var backgrounds := {}
var retire_nodes: Array[Node] = []
var active: RefCounted
var character: Node3D
var active_sequence := 0
var next_zone_to_plan := 0
var library_ready := false
var started := false
var loading_boundary := false
var touring := false
var tour_speed := 100.0
var build_budget_usec := 1500
var last_build_ms := 0.0
var max_build_ms := 0.0
var max_frame_ms := 0.0
var _frame_sample_count := 0
var _last_frame_usec := 0
var _background_zone := -1
var background_blend := 0.0
var _foreground_container: SubViewportContainer
var _retire_roots: Array[Node] = []
var hud: CanvasLayer
var heading: Label
var detail: Label
var diagnostics: Label
var loading_panel: ColorRect
var loading_label: Label
var tour_button: Button
var _startup_message := "Loading baked endless mode…"
var closing := false

func _source_paths() -> Array:
 return Plan.PATHS

func _next_planned_zone(documents: Array) -> Array[Dictionary]:
 return planner.next_zone(documents)

func _has_next_act() -> bool:
 return true

func _default_run_seed() -> int:
 return 18

func _pool_error(documents: Array) -> String:
 return Plan.pool_error(documents)

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 run_seed = _default_run_seed()
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--seed="): run_seed = int(argument.trim_prefix("--seed="))
 var documents: Array = []
 for path: String in _source_paths():
  var loaded := ActDocument.load_document(path)
  if loaded.document == null:
   _build_hud()
   _startup_error(loaded.error)
   return
  documents.append(loaded.document)
 var pool_error := _pool_error(documents)
 if not pool_error.is_empty():
  _build_hud()
  _startup_error(pool_error)
  return
 planner = Plan.new(run_seed)
 pending.assign(_next_planned_zone(documents))
 next_zone_to_plan = 1
 authored_act_path = _source_paths()[pending[0].id]
 _opening_document = documents[pending[0].id]
 super._ready()
 if playfield == null: return
 world.process_mode = Node.PROCESS_MODE_PAUSABLE
 ring_field.process_mode = Node.PROCESS_MODE_PAUSABLE
 loading_act = true
 controls.input_blocked = true
 get_tree().paused = true
 _build_hud()
 library = Library.new()
 # Construction is an explicit developer path; normal play loads only the
 # runtime library and cannot invoke the authoring builder.
 if "--no-bakes" in OS.get_cmdline_user_args():
  library.free()
  library = load("res://scripts/endless/template_builder.gd").new()
  library.bake_only = false
 add_child(library)
 library.progress.connect(func(message: String): _startup_message = message)
 library.prepare(self, _source_paths(), true, documents)
 if not library.error.is_empty():
  _startup_error(library.error)
  return
 hub = Hub.new()
 world.add_child(hub)
 ball.mechanics = hub
 library_ready = true
 pending.append_array(_next_planned_zone(library.documents))
 next_zone_to_plan = 2
 _startup_message = "Loading the opening Acts and warming graphics…"
 while resident.size() < 2 or not _zone_ready(0):
  if closing: return
  if not library.error.is_empty():
   _startup_error(library.error)
   return
  await get_tree().process_frame
 if closing: return
 active = resident[0]
 _activate(active, true)
 started = true
 loading_act = false
 controls.input_blocked = false
 get_tree().paused = false
 loading_panel.hide()
 reset_ball(false)
 print("ENDLESS_READY | seed=%d | Acts=%d | cached variants=%d | normal pinball controls" % [run_seed, resident.size(), library.visuals.size()])
 if "--tour" in OS.get_cmdline_user_args(): toggle_tour()

func _prepare_initial_act() -> Dictionary:
 # Only metadata is needed to start the shared engine. The library later loads
 # baked collisions once; no throwaway authored physics or presentation is built.
 ball.radius = _opening_document.cell_size * preload("res://scripts/act_dimensions.gd").BALL_RADIUS_CELLS
 return {"document": _opening_document, "runtime": {"terrain": [], "objects": []}, "error": ""}

func _populate_rings() -> void:
 pass # Streamed Acts populate rings when their recipes become ready.

func _build_debug_panel() -> void:
 pass # Endless owns its small HUD; the standalone Act tools are not instantiated.

func can_reload_act() -> bool:
 return false

func _build_view() -> void:
 # Compose both scenery layers and the transparent foreground before applying
 # the same world-only shader stack as normal gameplay. HUD stays outside.
 var output := SubViewportContainer.new()
 output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 output.stretch = true
 output.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(output)
 _composite_view = SubViewport.new()
 _composite_view.disable_3d = true
 _composite_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 output.add_child(_composite_view)
 var container := SubViewportContainer.new()
 _foreground_container = container
 container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 container.stretch = true
 container.mouse_filter = Control.MOUSE_FILTER_IGNORE
 camera_input_container = output
 _composite_view.add_child(container)
 view = SubViewport.new()
 view.size = get_viewport().get_visible_rect().size
 view.own_world_3d = true
 view.transparent_bg = true
 view.msaa_3d = Viewport.MSAA_4X
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 container.add_child(view)
 _build_presentation()
 retro_filter = RetroFilter.new()
 add_child(retro_filter)
 retro_filter.attach(output, _composite_view)

func _build_presentation() -> void:
 presentation = StreamPresentation.new()
 presentation.ball = ball
 presentation.ring_field = ring_field
 presentation.camera_preset = TablePresentation.CameraPreset.DRAMATIC_PINBALL
 presentation.camera_settings.zoom = 1.2
 view.add_child(presentation)
 presentation.build_authored(authored_runtime, playfield.bounds, authored_document.cell_size)
 presentation.reset_camera(ball.position)
 character = Character.new()
 character.ball = ball
 character.table = presentation
 character.specials = specials
 presentation.add_child(character)

func _process(delta: float) -> void:
 if closing: return
 if is_instance_valid(loading_label): loading_label.text = _startup_message
 if not library_ready: return
 var tick := Time.get_ticks_usec()
 var deadline := tick + build_budget_usec
 # Retiring trees get a slice even while later Acts are being prepared.
 var retire_deadline := tick + build_budget_usec / 3
 while not retire_nodes.is_empty() and Time.get_ticks_usec() < retire_deadline:
  var node: Node = retire_nodes.pop_back()
  var retire_started := Time.get_ticks_usec()
  if is_instance_valid(node): node.free()
  if library.profile_enabled: library._record_cpu("live.retire", retire_started)
 _prefetch_next_theme()
 var steps := 0
 while Time.get_ticks_usec() < deadline and steps < 128:
  steps += 1
  if building != null:
   var operation_started := Time.get_ticks_usec()
   var operation := "%d:%d" % [building.phase, building.index]
   var phase_label: String = ["colliders", "objects", "visuals", "activate", "ready"][building.phase]
   building.step()
   if library.profile_enabled: library._record_cpu("live." + phase_label, operation_started)
   var operation_ms := float(Time.get_ticks_usec() - operation_started) / 1000.0
   if started and operation_ms > 6.0: print("ENDLESS_SLOW_JOB | step=", operation, " ms=", operation_ms)
   if building.ready:
    resident.append(building)
    hub.runtimes.append(building.runtime.mechanics)
    var owner_id := "act:%d" % building.plan.sequence
    _wire_scoring_runtime(building.runtime, owner_id)
    _add_scoring_hardware(building.runtime, building.document, building.plan.offset, presentation, owner_id)
    building = null
    operation_started = Time.get_ticks_usec()
    _sync_resident()
    if library.profile_enabled: library._record_cpu("live.register", operation_started)
    operation_ms = float(Time.get_ticks_usec() - operation_started) / 1000.0
    if started and operation_ms > 6.0: print("ENDLESS_SLOW_JOB | register ms=", operation_ms)
  elif _step_background():
   pass
  elif not pending.is_empty():
   var entry: Dictionary = pending[0]
   # Startup waits for two Acts only. During play prepare the rest of this Zone and the next Zone.
   if entry.sequence > active_sequence + (5 if started else 1): break
   if not library.has_variant(entry.theme, entry.id):
    if not library.busy:
     var protected: Array = [entry]
     for act: RefCounted in resident: protected.append(act.plan)
     for index: int in backgrounds:
      if index >= _background_zone and index <= _background_zone + 1:
       protected.append({"theme": backgrounds[index].theme, "id": entry.id})
     if not library.trim(protected, 1, 0 if library.themes.has(entry.theme) else 1): break
    library.request(entry.theme, entry.id)
    break
   if not library.busy:
    var pinned: Array = [entry]
    for act: RefCounted in resident: pinned.append(act.plan)
    library.trim(pinned)
   pending.pop_front()
   _ensure_background(entry)
   building = Act.new()
   building.initialize(self, entry, library)
  elif not retire_nodes.is_empty():
   var node: Node = retire_nodes.pop_back()
   if is_instance_valid(node): node.free()
  else:
   break
 last_build_ms = float(Time.get_ticks_usec() - tick) / 1000.0
 if started:
  max_build_ms = maxf(max_build_ms, last_build_ms)
  if _last_frame_usec > 0:
   var elapsed_ms := float(tick - _last_frame_usec) / 1000.0
   max_frame_ms = maxf(max_frame_ms, elapsed_ms)
   if elapsed_ms > 100.0:
    print("ENDLESS_SLOW_FRAME | zone=", active.plan.zone + 1, " ms=", elapsed_ms, " build_ms=", last_build_ms, " | theme prefetch=", library.preparing_theme)
  _last_frame_usec = tick
  _frame_sample_count += 1
  if not library.error.is_empty() and not loading_boundary: _wait_for_next()
  if loading_boundary and _next_ready():
   loading_boundary = false
   loading_panel.hide()
   get_tree().paused = false
  if touring and not get_tree().paused: _tour_step(delta)
  _update_backgrounds()
  _retire_behind()
  heading.text = "ZONE %d · %s · ACT %d / 3" % [active.plan.zone + 1, library.themes[active.plan.theme].display_name.to_upper(), active.plan.act + 1]
  if loading_boundary:
   detail.text = "Waiting for the next Act to finish loading…" if library.error.is_empty() else library.error
  else:
   detail.text = "%s · %s\nACT SCORE  %s     TOTAL SCORE  %d     COMBO ×%d\n%s" % [active.document.title, "Camera tour — ball parked" if touring else "Unlimited checkpoint retries", act_score_text(), score, scorecraft.multiplier, status_message]
   if not scoring_feedback_text().is_empty(): detail.text += "\n" + scoring_feedback_text()
  diagnostics.text = "Seed %d | Resident %d | Queued %d | Build %.2f ms (max %.2f) | Frame max %.1f ms\nDisk Acts %d · Disk themes %d · Runtime rebuilds %d · Last prepare %.2f s" % [run_seed, resident.size(), pending.size() + int(building != null), last_build_ms, max_build_ms, max_frame_ms, library.visual_bake_hits, library.theme_bake_hits, library.fallback_builds, library.last_prepare_ms / 1000.0]
  diagnostics.text += "\nTheme preloads %d · Last %.2f s%s" % [library.theme_prefetches, library.last_theme_prepare_ms / 1000.0, " · Preparing " + library.preparing_theme if not library.preparing_theme.is_empty() else ""]
  diagnostics.text += "\n" + scoring_breakdown_text()

func _prefetch_next_theme() -> void:
 if not started or active == null: return
 for entry: Dictionary in pending:
  if entry.zone == active.plan.zone + 1:
   library.prime_theme(entry.theme)
   break
 if library.busy: return
 # The single preparation worker must finish this Zone's Acts before optional
 # next-theme work. Fast travel otherwise reaches Act 3 while a distant theme
 # monopolizes the worker, despite the immediate neighbor already being ready.
 if not pending.is_empty() and pending[0].zone <= active.plan.zone: return
 for entry: Dictionary in pending:
  if entry.zone != active.plan.zone + 1: continue
  if library.backgrounds.has(entry.theme):
   _ensure_background(entry)
  elif _next_ready():
   # Keep the immediate playable neighbor ready before doing optional theme work.
   var protected: Array = [entry]
   for act: RefCounted in resident: protected.append(act.plan)
   for index: int in backgrounds:
    if index >= _background_zone:
     protected.append({"theme": backgrounds[index].theme, "id": entry.id})
   if not library.trim(protected, 0, 1): return
   library.request_theme(entry.theme)
  return

func _physics_process(delta: float) -> void:
 if not started or touring or get_tree().paused: return
 if not _next_ready() and ball.position.y < active.bounds().position.y + maxf(100.0, absf(ball.linear_velocity.y) * 0.25):
  _wait_for_next()
  return
 super._physics_process(delta)

func _observe_authored_motion(start: Vector2, finish: Vector2) -> void:
 if not exit_unlocked: return
 for act: RefCounted in resident:
  if act.plan.sequence != active_sequence + 1: continue
  var events := ActLifecycle.crossings(act.document, start - Vector2(act.plan.offset), finish - Vector2(act.plan.offset))
  if events.activation: _activate(act)

func _at_playfield_drain() -> bool:
 return active != null and ball.position.y >= float(active.document.red_gutter_bounds().end.y) + active.plan.offset.y

func _activate(act: RefCounted, initial := false) -> void:
 if not initial and active == act: return
 active = act
 active_sequence = act.plan.sequence
 authored_document = act.document
 authored_runtime = act.runtime
 ball.serve_position = act.spawn()
 ring_field.collection_bounds = act.bounds()
 for resident_act: RefCounted in resident:
  resident_act.runtime.mechanics.scoring_active = resident_act == act
 _activate_scoring_context(act.document, act.runtime, "act:%d" % act.plan.sequence)
 if not initial:
  specials.act_advanced()
  scorecraft.reset("Act advanced", true)
 _sync_resident()
 _show_background(act.plan.zone, act.plan.theme, initial)
 if next_zone_to_plan <= act.plan.zone + 1:
  pending.append_array(_next_planned_zone(library.documents))
  next_zone_to_plan += 1
 print("ENDLESS_CHECKPOINT | zone=%d act=%d template=%s" % [act.plan.zone + 1, act.plan.act + 1, act.document.title])

func _sync_resident() -> void:
 presentation.ring_pickups.clear()
 presentation.flash_times.clear()
 flippers.clear()
 presentation.flipper_visuals.clear()
 presentation.flipper_retracted_visuals.clear()
 presentation.ring_visuals.clear()
 presentation.bumper_visuals.clear()
 ring_field.rings.clear()
 var field := PlayfieldData.new()
 field.source = "authored"
 field.document = authored_document
 field.authored_runtime = authored_runtime
 field.spawn = ball.serve_position
 var bounds := Rect2()
 for act: RefCounted in resident:
  bounds = bounds.merge(act.bounds()) if bounds.has_area() else act.bounds()
  flippers.append_array(act.runtime.flippers)
  for index: int in act.recipe.flippers: presentation.flipper_visuals.append(act.nodes[index])
  for index: int in act.recipe.retracted: presentation.flipper_retracted_visuals.append(act.nodes[index])
  for index: int in act.recipe.rings: presentation.ring_visuals.append(act.nodes[index])
  ring_field.rings.append_array(act.ring_data)
  for i: int in act.recipe.bumpers:
   var body: Node2D = act.runtime.objects[i].body
   presentation.bumper_visuals[body.get_instance_id()] = act.nodes[act.recipe.bumpers[i]]
   field._add_bumper(body, float(act.runtime.objects[i].get("radius", 0.0)))
  for terrain: Dictionary in act.runtime.terrain:
   field.terrain_bodies.append(terrain.body)
   field._glide_surfaces.append(terrain.body)
 field.bounds = bounds
 field.terrain_bounds = bounds
 playfield = field
 presentation.flippers = flippers
 presentation.table_bounds = bounds
 presentation.clear_ring_pickups()
 _apply_tuning()

func _ensure_background(entry: Dictionary) -> void:
 if backgrounds.has(entry.zone): return
 var backdrop := Backdrop.new()
 backdrop.name = "Zone%dBackdrop" % entry.zone
 _composite_view.add_child(backdrop)
 _composite_view.move_child(backdrop, _foreground_container.get_index())
 backdrop.configure(self, entry, library)
 backgrounds[entry.zone] = {"root": backdrop.scenery, "layer": backdrop, "theme": entry.theme,
  "entrance_y": float(entry.offset.y) + library.documents[entry.id].terrain_bounds().size.y,
  "recipe": library.backgrounds[entry.theme], "nodes": [], "index": 0, "warm_until": -1, "ready": false}

func _step_background() -> bool:
 var started_at := Time.get_ticks_usec()
 for background: Dictionary in backgrounds.values():
  if background.ready: continue
  if background.index < background.recipe.records.size():
   var nodes: Array[Node] = []
   nodes.assign(background.nodes)
   background.recipe.instantiate_one(background.index, nodes, background.root)
   background.nodes = nodes
   background.index += 1
  elif background.warm_until < 0:
   background.recipe.bind_animations(background.nodes, presentation)
   for animation: Dictionary in background.recipe.animations:
    background.nodes[animation.index].process_mode = Node.PROCESS_MODE_INHERIT
   background.layer.follow(presentation.camera, view.size, 0.0, true)
   background.warm_until = Engine.get_process_frames() + 3
  elif Engine.get_process_frames() >= background.warm_until:
   background.ready = true
   background.layer.view.render_target_update_mode = SubViewport.UPDATE_DISABLED
  if library.profile_enabled: library._record_cpu("live.background", started_at)
  return true
 return false

func _show_background(zone_index: int, theme_id: String, initial := false) -> void:
 if not initial: return # Travel distance, not checkpoint activation, owns the fade.
 _background_zone = zone_index
 var environment: Environment = library.environments[theme_id].duplicate()
 environment.background_mode = Environment.BG_COLOR
 environment.background_color = Color(0, 0, 0, 0)
 environment.sky = null
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
 presentation._world_environment.environment = environment
 _blend_lighting(theme_id, theme_id, 0.0)

func _update_backgrounds() -> void:
 if _background_zone < 0: return
 var current: Dictionary = backgrounds[_background_zone]
 var following: Dictionary = backgrounds.get(_background_zone + 1, {})
 background_blend = 0.0
 if not following.is_empty() and following.ready:
  # Begin in the last Act, finish inside the next Zone. Moving backwards before
  # completion reverses the blend naturally; no timer or scene switch is involved.
  var position_y: float = presentation.camera_focus.y
  background_blend = smoothstep(0.0, 1.0, clampf((following.entrance_y + 200.0 - position_y) / 450.0, 0.0, 1.0))
  _blend_lighting(current.theme, following.theme, background_blend)
 for index: int in backgrounds:
  var weight := 0.0
  if index == _background_zone: weight = 1.0
  elif index == _background_zone + 1: weight = background_blend
  var warming: bool = not backgrounds[index].ready and backgrounds[index].warm_until >= 0
  backgrounds[index].layer.follow(presentation.camera, view.size, weight, warming)
 if background_blend >= 1.0:
  current.layer.follow(presentation.camera, view.size, 0.0)
  _background_zone += 1

func _blend_lighting(from_theme: String, to_theme: String, weight: float) -> void:
 var from_light: Dictionary = library.lights[from_theme]
 var to_light: Dictionary = library.lights[to_theme]
 presentation._key_light.quaternion = Quaternion.from_euler(from_light.rotation).slerp(Quaternion.from_euler(to_light.rotation), weight)
 presentation._key_light.light_color = from_light.color.lerp(to_light.color, weight)
 presentation._key_light.light_energy = lerpf(from_light.energy, to_light.energy, weight)
 presentation._key_light.shadow_normal_bias = lerpf(from_light.bias, to_light.bias, weight)
 var before: Environment = library.environments[from_theme]
 var after: Environment = library.environments[to_theme]
 var target: Environment = presentation._world_environment.environment
 target.ambient_light_color = before.ambient_light_color.lerp(after.ambient_light_color, weight)
 target.ambient_light_energy = lerpf(before.ambient_light_energy, after.ambient_light_energy, weight)
 target.tonemap_exposure = lerpf(before.tonemap_exposure, after.tonemap_exposure, weight)

func _zone_ready(index: int) -> bool:
 return backgrounds.has(index) and backgrounds[index].ready

func _next_ready() -> bool:
 if not _has_next_act(): return true
 for act: RefCounted in resident:
  if act.plan.sequence == active_sequence + 1: return _zone_ready(act.plan.zone)
 return false

func _wait_for_next() -> void:
 loading_boundary = true
 _startup_message = "Preparing the next Act…"
 # Keep the continuous course visible if preparation falls behind.
 get_tree().paused = true

func _retire_behind() -> void:
 var changed := false
 for i in range(resident.size() - 1, -1, -1):
  var act: RefCounted = resident[i]
  if act.plan.sequence >= active_sequence - 1: continue
  if act.bounds().position.y < presentation.camera_focus.y + 500.0: continue
  hub.runtimes.erase(act.runtime.mechanics)
  _queue_retirement(act.root)
  _queue_retirement(act.visual)
  if is_instance_valid(act.background_visual):
   # Keep the retiring tree owned if shutdown interrupts gradual cleanup, but
   # outside the Zone backdrop so retiring that layer cannot enqueue it twice.
   act.background_visual.reparent(self, false)
   _queue_retirement(act.background_visual)
  resident.remove_at(i)
  changed = true
 if changed: _sync_resident()
 if changed:
  for id: int in _target_awards.keys():
   if not playfield._bumper_radii.has(id): _target_awards.erase(id)
 for index: int in backgrounds.keys():
  if index >= mini(active.plan.zone - 1, _background_zone): continue
  backgrounds[index].layer.hide()
  _queue_retirement(backgrounds[index].layer)
  backgrounds.erase(index)

func _queue_retirement(root: Node) -> void:
 root.process_mode = Node.PROCESS_MODE_DISABLED
 if root is Node3D: root.hide()
 # Post-order frees ensure no individual free recursively destroys an Act.
 retire_nodes.append(root)
 for child: Node in root.get_children(): _queue_retirement(child)

func toggle_tour() -> void:
 if not started or loading_boundary: return
 touring = not touring
 presentation.touring = touring
 controls.input_blocked = touring
 presentation.tour_focus = ball.position if touring else active.spawn()
 world.process_mode = Node.PROCESS_MODE_DISABLED if touring else Node.PROCESS_MODE_PAUSABLE
 ring_field.set_physics_process(not touring)
 specials.process_mode = Node.PROCESS_MODE_DISABLED if touring else Node.PROCESS_MODE_PAUSABLE
 character.visible = not touring
 tour_button.text = "Resume pinball [T]" if touring else "Camera tour [T]"
 if not touring: reset_ball(false)

func toggle_pause() -> void:
 if not started or loading_boundary: return
 super.toggle_pause()

func reset_ball(relaunch := false) -> void:
 if not started or touring or loading_boundary: return
 super.reset_ball(relaunch)

func launch_ball() -> void:
 if not started or touring or loading_boundary: return
 super.launch_ball()

func _tour_step(delta: float) -> void:
 if not _next_ready() and presentation.tour_focus.y < active.bounds().position.y + 120.0:
  _wait_for_next()
  return
 var before: Vector2 = presentation.tour_focus
 var after := before + Vector2.UP * tour_speed * minf(delta, 0.05)
 var center: float = active.bounds().get_center().x
 for act: RefCounted in resident:
  if act.plan.sequence == active_sequence + 1 and after.y < active.bounds().position.y + 160.0:
   center = act.bounds().get_center().x
 after.x = move_toward(after.x, center, tour_speed * delta * 2.0)
 presentation.tour_focus = after
 for act: RefCounted in resident:
  if act.plan.sequence == active_sequence + 1 and after.y < act.plan.offset.y + float(act.document.activation_y):
   _activate(act)
   break

func jump_tour_boundary() -> void:
 if not touring or not _next_ready(): return
 for act: RefCounted in resident:
  if act.plan.sequence == active_sequence + 1:
   presentation.tour_focus = act.bounds().get_center()
   _activate(act)
   return

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode == KEY_T: toggle_tour()
 elif event.keycode == KEY_N: jump_tour_boundary()
 elif event.keycode == KEY_F3: diagnostics.visible = not diagnostics.visible
 elif event.keycode == KEY_F11:
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func request_authored_act(_path: String, _settings: Dictionary = {}) -> bool:
 return false

func _build_hud() -> void:
 hud = CanvasLayer.new()
 hud.layer = 20
 add_child(hud)
 var backing := PanelContainer.new()
 backing.position = Vector2(16, 12)
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.025, 0.055, 0.09, 0.88)
 style.set_content_margin_all(10)
 style.set_corner_radius_all(6)
 backing.add_theme_stylebox_override("panel", style)
 hud.add_child(backing)
 var panel := VBoxContainer.new()
 backing.add_child(panel)
 heading = Label.new()
 heading.add_theme_font_size_override("font_size", 25)
 panel.add_child(heading)
 detail = Label.new()
 panel.add_child(detail)
 var buttons := HBoxContainer.new()
 panel.add_child(buttons)
 tour_button = _button("Camera tour [T]", toggle_tour, buttons)
 _button("Tour jump [N]", jump_tour_boundary, buttons)
 _button("Tour speed", func(): tour_speed = 400.0 if tour_speed == 100.0 else 100.0, buttons)
 _button("Pause [Esc]", toggle_pause, buttons)
 _button("Checkpoint [R]", func():
  if started and not touring: reset_ball(false), buttons)
 if retro_filter != null:
  retro_controls = RetroControls.new()
  add_child(retro_controls)
  retro_controls.install(retro_filter, buttons, buttons)
 var hint := Label.new()
 hint.text = "Enter: roll in · Q/E: flippers · Arrows: steer · Space: special · F3: stats · F4: filters · F11: fullscreen"
 panel.add_child(hint)
 diagnostics = Label.new()
 diagnostics.visible = "--frame-timing" in OS.get_cmdline_user_args()
 panel.add_child(diagnostics)
 loading_panel = ColorRect.new()
 loading_panel.color = Color("101b2c")
 loading_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.add_child(loading_panel)
 loading_label = Label.new()
 loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 loading_label.add_theme_font_size_override("font_size", 23)
 loading_panel.add_child(loading_label)

func _button(label: String, action: Callable, parent: Node) -> Button:
 var button := Button.new()
 button.text = label
 button.focus_mode = Control.FOCUS_NONE
 button.pressed.connect(action)
 parent.add_child(button)
 return button

func _startup_error(message: String) -> void:
 last_source_error = message
 _startup_message = "Endless mode could not start:\n" + message
 loading_label.text = _startup_message
 push_error(message)

func prepare_to_close() -> void:
 # Let any in-flight library coroutine finish before its owner is freed.
 closing = true
 set_process(false)
 set_physics_process(false)
 if is_instance_valid(controls): controls.input_blocked = true
 if is_instance_valid(world): world.process_mode = Node.PROCESS_MODE_DISABLED
 if is_instance_valid(ring_field): ring_field.scoring_enabled = false
 await get_tree().process_frame
 while is_instance_valid(library) and library.busy:
  await get_tree().process_frame
