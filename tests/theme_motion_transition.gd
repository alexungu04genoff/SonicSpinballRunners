extends SceneTree
## Real disk-loaded Zone seams, including adjacent instances of one theme.
const Session = preload("res://scripts/prototype/session.gd")
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Report = preload("res://tests/render_profile_support.gd")
var failures := 0
var checks := 0
var output := "res://test-results/theme-motion/transitions"
var records: Array = []

func _initialize() -> void:
 Engine.time_scale = 0.0
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)

func run() -> void:
 root.size = Vector2i(1440, 1000)
 root.position = Vector2i(-1900, 30)
 DirAccess.make_dir_recursive_absolute(output)
 preload("res://scripts/rendering_options.gd").settings_path = output.path_join("graphics.cfg")
 for pair: Array in [["green_hill", "chemical_plant"], ["rooftop_run", "casino_night"], ["sky_sanctuary", "aquarium_park"], ["ice_cap", "ice_cap"], ["rooftop_run", "rooftop_run"]]:
  await inspect_pair(pair)
 FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"renderer":Report.metadata()}, "  "))
 print("RESULT | Theme motion transitions | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func inspect_pair(pair: Array) -> void:
 paused = false
 var session := Session.new()
 session.settings_path = output.path_join("settings-%d.cfg" % Time.get_ticks_usec())
 session.archive_directory = output.path_join("telemetry")
 session.sound_enabled = false
 session.run_configuration = Session.Run.RunPlan.Configuration.new([Fixture.DEFAULT_ACT, "res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/SpringUp.tres"])
 session.run_configuration.selected_theme_ids = [pair[0]] if pair[0] == pair[1] else pair
 session.run_configuration.zone_count = 2
 for theme: String in pair: session.run_configuration.atmosphere_overrides[theme] = "default"
 root.add_child(session)
 while session.setup_menu.checking: await process_frame
 var selected_seed := 18
 if pair == ["rooftop_run", "rooftop_run"]:
  session.run_configuration.atmosphere_overrides.clear()
  var variants := preload("res://scripts/atmosphere/variants.gd").new()
  for trial in 100:
   if variants.choose("rooftop_run", trial, 0).id != variants.choose("rooftop_run", trial, 1).id:
    selected_seed = trial
    break
 await session._start_configured_run(session.run_configuration, "sonic", false, selected_seed)
 var game: Node = session.game
 if not is_instance_valid(game):
  check(false, "Session starts: " + str(pair))
  session.free()
  return
 var deadline := Time.get_ticks_msec() + 180000
 while (not game.started or not game._zone_ready(1) or game.resident.size() < 6) and Time.get_ticks_msec() < deadline:
  await process_frame
 check(game.started and game._zone_ready(1), "Both disk-backed Zones become ready: " + str(pair))
 if not game._zone_ready(1):
  session.archive_attempted = true
  await session._close_run("motion_test")
  session.free()
  return
 paused = true
 session.set_process(false)
 session.overlay_root.hide()
 game.set_process(false)
 game.set_physics_process(false)
 game.presentation.set_process(false)
 game.ball.freeze = true
 game.auto_launch_time = -1.0
 game.fps_label.hide()
 Report.disable_native_input(session)
 var layer_a: Node = game.backgrounds[0].layer
 var layer_b: Node = game.backgrounds[1].layer
 var motion_a: RefCounted = layer_a.motion
 var motion_b: RefCounted = layer_b.motion
 check(motion_a != motion_b, "One distinct motion owner per resident Zone")
 motion_a.select("A", "FULL")
 motion_b.select("B", "FULL")
 motion_a.seek(7.25)
 motion_b.seek(11.75)
 if pair == ["rooftop_run", "rooftop_run"]:
  check(game.run_plan[0].atmosphere.id != game.run_plan[3].atmosphere.id, "Same-theme seam uses two real authored atmosphere variants")
 var materials_a: Dictionary = layer_a.atmosphere.bindings.materials
 var materials_b: Dictionary = layer_b.atmosphere.bindings.materials
 for source: Material in materials_a:
  if materials_b.has(source) and materials_a[source] != source:
   check(materials_a[source] != materials_b[source], "Private material ownership survives same-theme residency")
 var gameplay := [game.ball.position, game.ball.linear_velocity, game.score, game.active_sequence]
 var receipt := {"pair":pair,"samples":[],"fallback_builds":game.library.fallback_builds,"atmospheres":[game.run_plan[0].atmosphere.id,game.run_plan[3].atmosphere.id]}
 for fraction: float in [0.0, 0.25, 0.49, 0.51, 0.75, 1.0, 0.5, 0.0]:
  game._background_zone = 0
  game._last_atmosphere_blend = Vector3(-1,-1,-1)
  game.presentation.touring = true
  game.presentation.tour_focus = Vector2(game.resident[3].spawn().x, game.backgrounds[1].entrance_y + 200.0 - fraction * 450.0)
  game.presentation._update_camera(0.0)
  game._update_backgrounds()
  check(is_equal_approx(game.background_blend, smoothstep(0.0,1.0,fraction)), "Real distance-driven crossfade")
  if fraction == 1.0:
   check(layer_a.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Zero-weight outgoing viewport disables")
  if fraction == 0.0:
   check(layer_b.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Zero-weight incoming viewport disables")
  for frame in 3: await process_frame
  await RenderingServer.frame_post_draw
  var file := "%s-%s-%02d.jpg" % [pair[0], pair[1], receipt.samples.size()]
  root.get_texture().get_image().save_jpg(output.path_join(file), 0.88)
  receipt.samples.append({"fraction":fraction,"a":motion_a.stats(),"b":motion_b.stats(),"image":file})
 check(gameplay == [game.ball.position, game.ball.linear_velocity, game.score, game.active_sequence], "Motion review leaves gameplay unchanged")
 check(game.library.fallback_builds == 0, "Zero runtime fallback geometry")
 var weak_a: WeakRef = weakref(layer_a)
 var weak_b: WeakRef = weakref(layer_b)
 records.append(receipt)
 session.archive_attempted = true
 await session._close_run("motion_test")
 session.free()
 for frame in 3: await process_frame
 check(weak_a.get_ref() == null and weak_b.get_ref() == null, "Zone scene close releases both animated owners")
 motion_a = null
 motion_b = null
