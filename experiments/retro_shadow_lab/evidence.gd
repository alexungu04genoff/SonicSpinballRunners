extends RefCounted
## Runs through the same scene, controls, renderer and teardown as live review.
const Audit = preload("res://scripts/diagnostics/render_audit.gd")
const Report = preload("res://tests/render_profile_support.gd")
var lab: Node
var rows: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var out: String

func run(owner: Node) -> void:
 lab = owner
 out = lab.output
 var args := OS.get_cmdline_user_args()
 await check_curve()
 var themes: Array = lab.Fixture.Registry.IDS
 if "--quick" in args: themes = [lab.theme]
 for theme: String in themes:
  lab.theme = theme
  if not await lab.open_game(): break
  await study(theme, "--quick" in args)
  await close_case()
 await penumbra()
 if "--quick" not in args:
  await motion_fixtures()
  await crossing()
 lab.busy = true
 await lab.release()
 await frames(5)
 check(lab.receivers.owners.is_empty(), "Teardown released all receiver owners")
 write_report(true)
 print("RETRO_SHADOW_RESULT | rows=", rows.size(), " failures=", lab.failures)
 lab.get_tree().quit(0 if lab.failures.is_empty() else 1)

func frames(count: int) -> void:
 for i in count: await lab.get_tree().process_frame

func curve_shader() -> String:
 return """shader_type canvas_item;
#include "res://experiments/retro_shadow_lab/response_curve.gdshaderinc"
void fragment() {
 const int counts[6] = {8, 5, 4, 3, 2, 0};
 float input_value = mix(0.25, 1.0, floor(FRAGCOORD.x) / 256.0);
 float value = lab_response(input_value, 0.5, counts[int(FRAGCOORD.y)], true, 0.75, vec4(1.0), 0.0);
 COLOR = vec4(vec3(value), 1.0);
}"""

func check_curve() -> void:
 var view := SubViewport.new()
 view.size = Vector2i(257, 6)
 view.disable_3d = true
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 lab.add_child(view)
 var strip := ColorRect.new()
 var material := ShaderMaterial.new()
 var program := Shader.new()
 program.code = curve_shader()
 material.shader = program
 strip.material = material
 strip.size = view.size
 view.add_child(strip)
 await frames(4)
 await RenderingServer.frame_post_draw
 var ramp := view.get_texture().get_image()
 for row in 5:
  var bands := {}
  var monotone := true
  var previous := -1
  for x in 257:
   var value := ramp.get_pixel(x, row).r8
   bands[value] = true
   monotone = monotone and value >= previous
   previous = value
  var endpoints := ramp.get_pixel(0, row) == ramp.get_pixel(0, 5) and ramp.get_pixel(256, row) == ramp.get_pixel(256, 5)
  var expected: int = [8, 5, 4, 3, 2][row]
  check(bands.size() == expected and monotone and endpoints, "GPU scalar ramp: exactly %d ordered levels, both native endpoints" % expected)
 view.free()

func watch_owners() -> Dictionary:
 var watched := {}
 if lab.game:
  for object: Object in [lab.game, lab.game.library, lab.game.presentation, lab.game.active.visual]:
   watched[str(object)] = weakref(object)
 for owner: Dictionary in lab.receivers.owners.values():
  for overlay: ShaderMaterial in owner.materials.values(): watched["overlay_%d" % overlay.get_instance_id()] = weakref(overlay)
 return watched

func close_case() -> void:
 var watched := watch_owners()
 await lab.release()
 await frames(4)
 var surviving := watched.keys().filter(func(id): return watched[id].get_ref() != null)
 check(surviving.is_empty(), "Released runtime and Lab materials for %s: survivors %s" % [lab.theme, surviving])

func image() -> Image:
 await frames(4)
 await RenderingServer.frame_post_draw
 if not lab.full_retro_active(): check(false, "Full Retro required for every captured frame")
 return lab.get_window().get_texture().get_image()

func shot(name: String) -> Image:
 var result := await image()
 check(result.save_png(out.path_join(name + ".png")) == OK, "Capture " + name)
 return result

func check(ok: bool, label: String) -> void:
 checks.append({"check": label, "pass": ok})
 if not ok:
  lab.failures.append(label)
  push_error(label)

func write_report(finished: bool) -> void:
 var file := FileAccess.open(out.path_join("report.json"), FileAccess.WRITE)
 file.store_string(JSON.stringify({"complete": finished and lab.failures.is_empty(), "metadata": Report.metadata(), "rows": rows, "checks": checks, "failures": lab.failures, "orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}, "  "))

func zero_overlay() -> void:
 lab.receivers.mode = 0
 lab.receivers.sync(lab.game)
 lab.receivers.update()

func study(theme: String, quick: bool) -> void:
 var game: Node = lab.game
 var start: Dictionary = lab.fixture.state()
 lab.set_native_range()
 check(lab.fixture.authority_error().is_empty(), theme + " disk-backed Prototype")
 lab.set_mode(0)
 check(lab.full_retro_active(), theme + " full production Retro stack")
 var native := await shot(theme + "-normal")
 var key: DirectionalLight3D = game.presentation._key_light
 var ring_modes := []
 for node: MeshInstance3D in game.presentation.ring_visuals: ring_modes.append(node.cast_shadow)
 var labels := ["normal", "zero_overlay", "clean2", "clean4", "ordered4", "clean3", "clean8"]
 for setting in labels.size():
  var before := Report.pipelines()
  var began := Time.get_ticks_usec()
  if setting == 1: zero_overlay()
  else: lab.set_mode(maxi(0, setting - 1))
  var attach_ms := (Time.get_ticks_usec() - began) / 1000.0
  var warm_start := Time.get_ticks_usec()
  await frames(24)
  var warm_ms := (Time.get_ticks_usec() - warm_start) / 1000.0
  var img := await shot(theme + "-" + str(labels[setting])) if setting > 0 else native
  if setting == 1: check(img.get_data() == native.get_data(), theme + " zero-delta overlay identity")
  if setting == 4:
   check(lab.receivers.stats().receivers > 0, theme + " eligible receivers exist")
   if key.shadow_enabled: check(img.get_data() != native.get_data(), theme + " visible treatment")
   if theme == "aquarium_park": audit_exclusions()
  var row := await bench(90 if quick else 180, false)
  row.merge({"theme": theme, "mode": labels[setting], "startup_ms": lab.open_ms, "attach_ms": attach_ms, "warm24_ms": warm_ms, "pipelines_before": before, "pipelines_after": Report.pipelines(), "receiver_inventory": lab.receivers.stats()})
  rows.append(row)
  if theme in ["green_hill", "rooftop_run"]:
   rows[-1]["pan"] = await bench(120, true)
   lab.camera(lab.start_focus)
  write_report(false)
 lab.set_mode(0)
 var restored := await image()
 check(restored.get_data() == native.get_data(), theme + " OFF restores native pixels")
 check(lab.fixture.state() == start, theme + " gameplay and camera preserved")
 check(not FileAccess.file_exists(lab.Review.Options.settings_path), theme + " graphics preferences isolated")
 if quick:
  lab.layer.show()
  lab.mode_choice.item_selected.emit(lab.MENU_ORDER.find(5))
  check(lab.mode == 5 and not lab.pattern_row.visible, "Native Lab menu selected eight clean levels")
  lab.mode_choice.item_selected.emit(lab.MENU_ORDER.find(3))
  check(lab.mode == 3 and lab.receivers.stats().receivers > 0, "Native Lab menu selected D")
  await shot("lab-controls")
  lab.mode_choice.select(0)
  lab.mode_choice.item_selected.emit(0)
  lab.layer.hide()
  return
 if theme in ["green_hill", "rooftop_run", "casino_night", "ice_cap", "aquarium_park"]:
  lab.camera(Vector2(570, 500))
  for mode in 4:
   lab.set_mode(mode)
   await shot("%s-raised-%d" % [theme, mode])
 if theme == "green_hill":
  await ring_motion()
  await anchors()
 if theme in ["green_hill", "rooftop_run", "casino_night", "ice_cap"]:
  lab.camera(lab.start_focus)
  lab.spin(0.0)
  lab.set_tones(true)
  for mode in [1, 2, 3]:
   lab.set_mode(mode)
   await shot("%s-deeper-%d" % [theme, mode])
  lab.set_tones(false)
  if theme == "green_hill":
   for mode in [1, 2, 3]:
    lab.set_mode(mode)
    await shot("green_hill-original-tones-%d" % mode)
  lab.set_native_range()
 if theme in ["green_hill", "ice_cap"]:
  lab.camera(lab.start_focus)
  var saved := Vector2(key.shadow_blur, key.light_angular_distance)
  for study_light: Vector2 in [Vector2(0.5, 0), Vector2(2, 0), Vector2(1, 3)]:
   key.shadow_blur = study_light.x
   key.light_angular_distance = study_light.y
   for mode in [0, 2, 3]:
    lab.set_mode(mode)
    await shot("%s-light-%.1f-%.1f-%d" % [theme, study_light.x, study_light.y, mode])
  key.shadow_blur = saved.x
  key.light_angular_distance = saved.y
 if theme in ["green_hill", "casino_night", "aquarium_park"]:
  lab.camera(lab.start_focus)
  lab.set_mode(3)
  # With the primary light disconnected its correction must disappear.
  var energy := key.light_energy
  key.light_energy = 0
  var control := await image()
  lab.set_mode(0)
  check(control.get_data() == (await image()).get_data(), theme + " local/emission-only native parity")
  key.light_energy = energy
  if theme == "green_hill":
   # A lit endpoint below one requires a negative HDR correction. This
   # catches unsigned blending or a renderer that clamps negative light.
   var bright := await image()
   lab.set_tones(false)
   lab.receivers.levels.w = 0.5
   lab.set_mode(2)
   var dim := await image()
   var point := Vector2i(550, 570)
   check(dim.get_pixelv(point).get_luminance() < bright.get_pixelv(point).get_luminance(), "Signed negative key correction in linear HDR")
   lab.receivers.levels.w = 1.0
   await calibrate_key()
   lab.set_native_range()
 lab.set_rings(true)
 for i in ring_modes.size(): check(game.presentation.ring_visuals[i].cast_shadow == ring_modes[i], theme + " Ring restoration")
 lab.set_mode(0)

func penumbra() -> void:
 lab.theme = "green_hill"
 lab.study_card = true
 lab.act_index = 0
 if not await lab.open_game(): return
 lab.set_native_range()
 var images := {}
 for mode in lab.MENU_ORDER:
  lab.set_mode(mode)
  var img := await shot("penumbra-retro-%d" % mode)
  images[mode] = img
  if mode in [1, 2, 4, 5]:
   # No spatial phase, scale, matrix or transition width may enter clean bands.
   lab.receivers.anchor = 0
   lab.receivers.matrix = 2
   lab.receivers.cell = 0.14
   lab.receivers.width = 0.1
   lab.receivers.update()
   check(img.get_data() == (await image()).get_data(), "Clean %d levels independent of pattern controls under full Retro" % lab.Receivers.LEVEL_COUNTS[mode])
   lab.receivers.anchor = 2
   lab.receivers.matrix = 4
   lab.receivers.cell = 0.035
   lab.receivers.width = 0.7
   lab.receivers.update()
 for pair in [[0, 5], [5, 2], [2, 4], [4, 1], [2, 3]]:
  check(images[pair[0]].get_data() != images[pair[1]].get_data(), "Distinct soft-edge treatments %s under full Retro" % [pair])
 if "--quick" not in OS.get_cmdline_user_args(): await pan_study("edge-pan", 0.30)
 lab.study_card = false
 await close_case()

func calibrate_key() -> void:
 lab.set_focus(1)
 lab.spin(0.25)
 var crop := Rect2i(620, 350, 380, 170)
 var saved: Vector4 = lab.receivers.levels
 lab.receivers.levels = Vector4.ONE
 var contrasts: Array[float] = []
 for mode in [0, 2]:
  lab.set_mode(mode)
  lab.set_rings(false)
  var lit := (await image()).get_region(crop)
  lab.set_rings(true)
  var cast := (await image()).get_region(crop)
  var total := 0.0
  for y in crop.size.y:
   for x in crop.size.x:
    total += absf(lit.get_pixel(x, y).get_luminance() - cast.get_pixel(x, y).get_luminance())
  contrasts.append(total)
 lab.receivers.levels = saved
 lab.receivers.update()
 var residual := contrasts[1] / maxf(contrasts[0], 0.001)
 check(contrasts[0] > 1.0 and residual < 0.15, "Unshadowed diffuse calibration: Ring ON/OFF residual %.4f of native contrast" % residual)
 lab.set_focus(0)

func bench(count: int, pan: bool) -> Dictionary:
 var intervals := []
 var previous := Time.get_ticks_usec()
 for i in count:
  if pan: lab.camera(lab.start_focus + Vector2(sin(TAU * i / count) * 150, 0))
  await lab.get_tree().process_frame
  var now := Time.get_ticks_usec()
  intervals.append((now - previous) / 1000.0)
  previous = now
 var state := Audit.viewport_state(lab.game.view, "foreground", true)
 return {"frame": Report.timing(intervals), "visible": state.visible, "shadow": state.shadow,
  "video_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
  "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}

func audit_exclusions() -> void:
 var transparent := 0
 var touched := 0
 var backdrop_overlays := 0
 for entry: Dictionary in Audit.viewports(lab.game):
  if entry.role in ["output", "composite", "warmup"]: continue
  for node: Node in entry.node.find_children("*", "GeometryInstance3D", true, false):
   var mesh := Audit.mesh_of(node)
   if not mesh: continue
   if node.material_overlay and entry.node != lab.game.view: backdrop_overlays += 1
   for index in mesh.get_surface_count():
    var material: Material = node.material_override
    if material == null and node is MeshInstance3D: material = node.get_active_material(index)
    if material == null: material = mesh.surface_get_material(index)
    if Audit.material_state(material).transparent:
     transparent += 1
     if node.material_overlay: touched += 1
 check(transparent > 0 and touched == 0 and backdrop_overlays == 0,
  "Aquarium: %d alpha slots inspected, %d treated, %d backdrop overlays" % [transparent, touched, backdrop_overlays])

func ring_motion() -> void:
 var presentation: Node = lab.game.presentation
 var ring: MeshInstance3D
 for candidate: MeshInstance3D in presentation.ring_visuals:
  if candidate.is_visible_in_tree(): ring = candidate; break
 if not ring: check(false, "Visible collectible for motion review"); return
 lab.camera(TablePresentation.unmap_point(ring.global_position))
 for profile in [1, 2]:
  lab.set_profile(profile)
  for mode in [0, 5, 2, 3]:
   lab.set_mode(mode)
   var poses := {}
   for i in 16:
    lab.spin(i * PI / 16)
    for enabled in [true, false]:
     lab.set_rings(enabled)
     var img := await image()
     var crop := img.get_region(Rect2i(620, 350, 380, 170))
     crop.save_png(out.path_join("ring-%d-%d-%02d-%d.png" % [profile, mode, i, int(enabled)]))
     if enabled: poses[crop.get_data().hex_encode().sha256_text()] = true
   check(poses.size() == 16, "16 distinct Ring poses at profile %d mode %d" % [profile, mode])
 lab.set_rings(true)
 lab.set_profile(1)

func anchors() -> void:
 await pan_study("pan", 1.0)

func pan_study(prefix: String, travel: float) -> void:
 var original_zoom: float = lab.game.presentation.camera_settings.zoom
 for index in 8:
  lab.set_mode([3, 3, 3, 0, 2, 5, 4, 1][index])
  lab.receivers.anchor = mini(index, 2)
  lab.receivers.update()
  for i in 24:
   var t := i / 23.0
   lab.game.presentation.camera_settings.zoom = lerpf(original_zoom, minf(2.5, original_zoom * 1.25), t)
   lab.camera(lab.start_focus + Vector2(150 * t * t, -90 * t) * travel)
   lab.spin(t * PI)
   var img := await image()
   img.get_region(Rect2i(360, 260, 600, 388)).save_png(out.path_join("%s-%d-%02d.png" % [prefix, index, i]))
 lab.receivers.anchor = 2
 lab.game.presentation.camera_settings.zoom = original_zoom
 lab.camera(lab.start_focus)

func motion_fixtures() -> void:
 lab.theme = "rooftop_run"
 for act in [1, 2, 3]:
  lab.act_index = act
  if not await lab.open_game(): return
  set_fixture_treatment()
  for preset: int in lab.game.PLAY_CAMERAS:
   lab.game.select_play_camera(preset)
   lab.game.presentation.camera_settings.zoom = 1.8
   lab.camera(lab.start_focus)
   await shot("act-%d-camera-%d" % [act, preset])
  if act == 3:
   # The raised barrel casts a broad shadow beside its dock. Use a single
   # native camera pose to separate the tube's own screen-door art from ours.
   lab.game.select_play_camera(lab.game.PLAY_CAMERAS[0])
   lab.camera(lab.start_focus)
   await tube_study()
  var bumper: Dictionary = {}
  var chute: Dictionary = {}
  var start_bumper := Vector2.ZERO
  if act == 2:
   for item: Dictionary in lab.game.active.runtime.mechanics.items:
    if item.type == "moving_bumper": bumper = item
    if item.type == "score_chute": chute = item
   check(not bumper.is_empty() and not chute.is_empty(), "Side to Side bumper and score chute loaded")
   if not bumper.is_empty(): start_bumper = bumper.body.position
   if not chute.is_empty(): lab.camera(chute.position); await shot("score-chute")
  lab.set_motion(2)
  var ball_start: Vector2 = lab.game.ball.position
  var life: RefCounted = lab.game.backgrounds[lab.game.active.plan.zone].layer.motion
  var life_age: float = life._age
  var controls: Node = lab.game.controls
  controls.virtual_enabled = true
  controls.virtual_left = true
  if act == 3:
   var tube: Node = lab.game.ball.launch_tube
   check(is_instance_valid(tube), "Workshop ball docked in a real Launch Tube")
   if tube:
    for tick in 6: await lab.get_tree().physics_frame
    controls.virtual_launch = true
    for tick in ceili(tube.properties.charge_seconds * Engine.physics_ticks_per_second) + 6: await lab.get_tree().physics_frame
    controls.virtual_launch = false
    for tick in 18: await lab.get_tree().physics_frame
    check(tube.distance > 0.0 or not tube.contained, "Release moved the real Workshop ball")
  else:
   for tick in 55: await lab.get_tree().physics_frame
  check(lab.game.ball.position.distance_to(ball_start) > 0.5, "Ball moved in fixture %d" % act)
  check(life._age > life_age and life.candidate == "C", "Native Theme Life advanced in fixture %d" % act)
  if act == 1:
   check(lab.game.flippers.any(func(paddle): return paddle.held), "Held flipper reached its active pose")
  if not bumper.is_empty(): check(bumper.body.position.distance_to(start_bumper) > 1.0, "Horizontal bumper moved across its receiver")
  await shot("act-%d-moving" % act)
  check(lab.game.library.fallback_builds == 0, "Moving fixture %d disk-only" % act)
  lab.set_motion(0)
  await close_case()

func set_fixture_treatment() -> void:
 lab.set_mode(3)

func tube_study() -> void:
 for mode in lab.MENU_ORDER:
  lab.set_mode(mode)
  await shot("tube-shadow-%d" % mode)
 set_fixture_treatment()

func crossing_modes() -> Array:
 return [0,3]

func set_crossing_mode(mode: int) -> void:
 lab.set_mode(mode)

func crossing_extras() -> Dictionary:
 return {}

func crossing() -> void:
 lab.endless = true
 for mode: int in crossing_modes():
  set_crossing_mode(mode)
  if not await lab.open_game(): return
  var game: Node = lab.game
  lab.set_motion(2)
  game.tour_speed = 0.0
  var began := Time.get_ticks_msec()
  var deadline := began + 180000
  while not (game._zone_ready(1) and game.resident.any(func(a): return a.ready and a.plan.sequence == 3)) and Time.get_ticks_msec() < deadline: await frames(1)
  var prep := Time.get_ticks_msec() - began
  var last: RefCounted
  for a: RefCounted in game.resident:
   if a.plan.sequence == 2: last = a
  if not last or Time.get_ticks_msec() >= deadline: check(false, "Endless Zone preparation"); return
  game._activate(last)
  game.presentation.tour_focus = Vector2(last.bounds().get_center().x, game.backgrounds[1].entrance_y + 260.0)
  game.tour_speed = 100.0
  var intervals := []
  var previous := Time.get_ticks_usec()
  deadline = Time.get_ticks_msec() + 30000
  var overlap := false
  var boundary_wait := 0
  while game._background_zone < 1 and Time.get_ticks_msec() < deadline:
   await frames(1)
   var now := Time.get_ticks_usec()
   intervals.append((now - previous) / 1000.0)
   previous = now
   overlap = overlap or game.background_blend > 0.01
   if game.loading_boundary: boundary_wait += 1
  check(overlap and game._background_zone >= 1 and game.library.fallback_builds == 0, "Endless crossfade, disk-only, mode %d" % mode)
  check(lab.full_retro_active(), "Full Retro at the streamed Zone boundary, mode %d" % mode)
  rows.append({"runtime": "Endless", "mode": mode, "startup_ms": lab.open_ms, "prep_ms": prep, "crossing": Report.timing(intervals), "boundary_wait_frames": boundary_wait, "fallback": game.library.fallback_builds, "receiver_inventory": lab.receivers.stats()})
  rows[-1].merge(crossing_extras())
  lab.set_motion(0)
  await close_case()
