extends SceneTree
## Rendered review of real disk-backed Prototype Zone transitions. No art-value contract.
const Session = preload("res://scripts/prototype/session.gd")
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Report = preload("res://tests/render_profile_support.gd")
const Options = preload("res://scripts/rendering_options.gd")
var checks := 0
var failures := 0
var output := "res://test-results/atmosphere-signatures/transitions"
var records: Array = []

func _initialize() -> void:
 Engine.time_scale = 0.0
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)

func frames(count: int) -> void:
 for index in count: await process_frame

func run() -> void:
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
 if DisplayServer.get_name() == "headless":
  push_error("Transition appearance review requires a graphical renderer.")
  quit(1)
  return
 root.size = Vector2i(1440, 1000)
 root.gui_disable_input = true
 DirAccess.make_dir_recursive_absolute(output)
 Options.settings_path = output.path_join("isolated-graphics.cfg")
 for pair: Array in [["green_hill", "casino_night"], ["chemical_plant", "rooftop_run"], ["chemical_plant", "casino_night"]]:
  await inspect_pair(pair)
 FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify({
  "complete": failures == 0, "checks": checks, "failures": failures, "records": records,
  "renderer": Report.metadata(), "note": "Frozen gameplay; evidence camera traverses the real distance-driven seam. Retro is the unmodified production stack."}, "  "))
 print("RESULT | Prototype atmosphere transitions | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)

func inspect_pair(pair: Array) -> void:
 var session := Session.new()
 session.settings_path = output.path_join("%s-%s-%d-settings.cfg" % [pair[0], pair[1], Time.get_ticks_usec()])
 session.archive_directory = output.path_join("isolated-telemetry")
 session.sound_enabled = false
 session.run_configuration = Session.Run.RunPlan.Configuration.new([
  Fixture.DEFAULT_ACT, "res://data/acts/Authored/RampMania.tres", "res://data/acts/Authored/SpringUp.tres"])
 session.run_configuration.selected_theme_ids = pair
 session.run_configuration.zone_count = 2
 for theme: String in pair: session.run_configuration.atmosphere_overrides[theme] = "default"
 root.add_child(session)
 while session.setup_menu.checking: await process_frame
 await session.start_run()
 var game: Node = session.game
 if not is_instance_valid(game):
  check(false, "Production session starts")
  session.free()
  return
 var deadline := Time.get_ticks_msec() + 180000
 while (not game.started or not game._zone_ready(1) or game.resident.size() < 6) and Time.get_ticks_msec() < deadline:
  await process_frame
 check(game.started and game._zone_ready(1) and game.resident.size() == 6, "Six real Acts and both Zone layers load")
 if not game._zone_ready(1):
  session.archive_attempted = true
  await session._close_run("transition_verification")
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
 var before = game.backgrounds[0].layer.atmosphere
 var after = game.backgrounds[1].layer.atmosphere
 var from: String = game.backgrounds[0].theme
 var to: String = game.backgrounds[1].theme
 var identity := [game.ball.get_instance_id(), game.presentation.camera.get_instance_id()]
 var gameplay := [game.ball.position, game.ball.linear_velocity, game.score, game.act_score, game.active_sequence]
 check(before.environment != after.environment, "Zones own distinct environments")
 check(before.environment != game.library.environments[from] and after.environment != game.library.environments[to], "Cached recipe environments remain private")
 if before.environment.sky != null and after.environment.sky != null:
  check(before.environment.sky != after.environment.sky and before.environment.sky.sky_material != after.environment.sky.sky_material, "Zones own private skies/materials")
 var private_materials := 0
 for material: Material in before.bindings.materials:
  if before.bindings.materials[material] != material:
   private_materials += 1
   if after.bindings.materials.has(material):
    check(before.bindings.materials[material] != after.bindings.materials[material], "Shared material sources have separate Zone copies")
 check(private_materials > 0, "Transition exercises private palette materials")
 var source_snapshots := {}
 for theme: String in pair:
  source_snapshots[theme] = {"exposure": game.library.environments[theme].tonemap_exposure,
   "ambient": game.library.environments[theme].ambient_light_color}
 var own_values: Array = [before.values.duplicate(true), after.values.duplicate(true)]
 var receipt := {"from": from, "to": to, "plan": game.course_snapshot(), "samples": [],
  "disk_acts": game.library.visual_bake_hits, "disk_themes": game.library.theme_bake_hits,
  "fallback_builds": game.library.fallback_builds, "bakes": []}
 for entry: Dictionary in game.run_plan:
  var path: String = game.source_paths[entry.id]
  var document: Resource = Fixture.Document.load_document(path).document
  var baked: Resource = load(Fixture.Bake.path_for(path, entry.theme))
  var background: Resource = load(Fixture.Bake.theme_path(entry.theme))
  var fingerprint: String = Fixture.Bake.pipeline_hash(entry.theme)
  check(baked.matches(document, entry.theme, fingerprint) and background.matches_pipeline(entry.theme, fingerprint), "Transition uses fresh disk recipes")
  receipt.bakes.append({"act": path, "theme": entry.theme, "pipeline": fingerprint,
   "act_sha256": FileAccess.get_sha256(Fixture.Bake.path_for(path, entry.theme)),
   "background_sha256": FileAccess.get_sha256(Fixture.Bake.theme_path(entry.theme))})
 for position_fraction: float in [0.0, 0.25, 0.49, 0.5, 0.51, 0.75, 1.0, 0.5, 0.0]:
  game._background_zone = 0
  game._last_atmosphere_blend = Vector3(-1, -1, -1)
  var focus := Vector2(game.resident[3].spawn().x, game.backgrounds[1].entrance_y + 200.0 - position_fraction * 450.0)
  # Use the existing tour camera target: reset_camera frames a hypothetical Ball
  # below the view center, so its input is not the camera-focus coordinate.
  game.presentation.touring = true
  game.presentation.tour_focus = focus
  game.presentation._update_camera(0.0)
  game._update_backgrounds()
  var weight: float = game.background_blend
  var environment: Environment = game.presentation._world_environment.environment
  check(is_equal_approx(weight, smoothstep(0.0, 1.0, position_fraction)), "Real camera-distance blend reaches expected weight")
  check(is_equal_approx(environment.tonemap_exposure, lerpf(before.environment.tonemap_exposure, after.environment.tonemap_exposure, weight)), "Exposure interpolates without a midpoint pop")
  check(environment.ambient_light_color.is_equal_approx(before.environment.ambient_light_color.lerp(after.environment.ambient_light_color, weight)), "Ambient color interpolates")
  check(not environment.fog_enabled, "Scoped clean-air Defaults do not create a fog wall")
  check(is_equal_approx(environment.glow_intensity, lerpf(before.environment.glow_intensity, after.environment.glow_intensity, weight)), "Glow intensity interpolates")
  check(before.values == own_values[0] and after.values == own_values[1], "Blending does not rewrite Zone palette values")
  await frames(12)
  await RenderingServer.frame_post_draw
  var filename := "%s-to-%s-%02d.png" % [from, to, receipt.samples.size()]
  check(root.get_texture().get_image().save_png(output.path_join(filename)) == OK, "Save transition frame")
  receipt.samples.append({"position_fraction": position_fraction, "blend": weight, "image": filename,
   "camera": str(game.presentation.camera.global_transform), "exposure": environment.tonemap_exposure,
   "glow": environment.glow_intensity, "retro": game.retro_filter.selected_effects.duplicate()})
 check(identity == [game.ball.get_instance_id(), game.presentation.camera.get_instance_id()], "Transition preserves gameplay identities")
 check(gameplay == [game.ball.position, game.ball.linear_velocity, game.score, game.act_score, game.active_sequence], "Evidence camera does not advance gameplay")
 check(game.library.fallback_builds == 0, "No source fallback in transitions")
 for theme: String in pair:
  check(source_snapshots[theme] == {"exposure": game.library.environments[theme].tonemap_exposure,
   "ambient": game.library.environments[theme].ambient_light_color}, "No cached environment leakage")
 records.append(receipt)
 session.archive_attempted = true
 await session._close_run("transition_verification")
 session.free()
