extends SceneTree
## A matched Green Hill camera sweep. Readbacks and warm-up stay outside timings.
const Fixture := preload("res://tests/prototype_appearance_fixture.gd")
const Review := preload("res://scripts/diagnostics/shadow_review.gd")
const Report := preload("res://tests/render_profile_support.gd")
const Contact := preload("res://scripts/atmosphere/native_ssao.gd")
const OUTPUT := "res://test-results/retro-contact-profile"
const SAMPLES := 120
const CASES := [
 ["Native shadows, SSAO off", 0.0, 10.0, 1.08, 0, 0],
 ["Approved default", 8.0, 10.0, 1.08, 0, 0],
 ["Harder native fades", 8.0, 3.0, 4.0, 0, 0],
 ["Continuous cast, matched contrast", 8.0, 10.0, 4.0, 0, 0],
 ["Five cast tones", 8.0, 10.0, 4.0, 5, 0],
 ["Four cast tones", 8.0, 10.0, 4.0, 4, 0],
 ["Four contact tones", 8.0, 10.0, 4.0, 0, 4],
 ["Four cast and four contact tones", 8.0, 10.0, 4.0, 4, 4],
 ["Five cast and five contact tones", 8.0, 10.0, 4.0, 5, 5],
]

func _initialize() -> void: run.call_deferred()

func run() -> void:
 if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
  push_error("Run the contact comparison with a graphical Forward+ renderer.")
  quit(1)
  return
 root.size = Vector2i(1280, 900)
 Review.position_review_window(root)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps = 0
 Engine.time_scale = 0.0
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 Review.Options.update_quality(Review.Options.defaults(), false)
 var fixture := Fixture.new()
 if not await fixture.open(self, Fixture.DEFAULT_ACT, "green_hill", OUTPUT, "default", "production"):
  push_error(fixture.error)
  quit(1)
  return
 var game: Node = fixture.game
 var atmosphere = game.backgrounds[0].layer.atmosphere
 var focus: Vector2 = game.ball.position
 var view: RID = game.view.get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(view, true)
 var rows: Array[Dictionary] = []
 for pass_index in 2:
  var order := CASES.duplicate()
  if pass_index == 1: order.reverse()
  for entry: Array in order:
   atmosphere.values[Contact.KEY] = entry[1]
   atmosphere.values[Contact.CONTRAST_KEY] = entry[3]
   atmosphere.values["shadow/levels"] = entry[4]
   atmosphere.values[Contact.LEVELS_KEY] = entry[5]
   atmosphere.lighting.shadow_blur = entry[2]
   game._last_atmosphere_blend = Vector3(-1, -1, -1)
   game._blend_lighting(0, 0, 0.0)
   game.presentation.reset_camera(focus)
   for frame in 45: await process_frame
   var surface = game.terrain_shadows
   var native_active: bool = game.presentation._world_environment.environment.ssao_enabled
   var receivers := 0
   if surface.contact: receivers = surface.contact.receivers.inventory().receivers
   var applied: bool = surface.cast_levels == entry[4] and native_active == (entry[1] > 0 and entry[5] == 0)
   if entry[4] > 0:
    applied = applied and surface.bands and surface.bands.LEVEL_COUNTS[surface.bands.mode] == entry[4]
   if entry[5] > 0:
    applied = applied and surface.contact and surface.contact.levels == entry[5] and surface.contact.depth.depth != null and receivers > 0
   else:
    applied = applied and surface.contact == null
   var gpu: Array = []
   var wall: Array = []
   var draws: Array[int] = []
   var previous := Time.get_ticks_usec()
   for frame in SAMPLES:
    game.presentation.reset_camera(focus + Vector2(90.0 * sin(TAU * frame / SAMPLES), 0))
    game._update_backgrounds()
    await process_frame
    var now := Time.get_ticks_usec()
    wall.append((now - previous) / 1000.0)
    previous = now
    gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(view))
    draws.append(game.view.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
   draws.sort()
   var row := {"setting": entry[0], "pass": pass_index + 1, "foreground_gpu": Report.timing(gpu),
    "frame": Report.timing(wall), "foreground_draws_median": draws[SAMPLES / 2],
    "applied": applied, "contact_receivers": receivers}
   rows.append(row)
   print("CONTACT_PROFILE | ", JSON.stringify(row))
 var report := {"device": RenderingServer.get_video_adapter_name(), "settings": Review.Options.defaults(),
  "retro": game.retro_filter.selected_effects, "samples_per_case": SAMPLES, "rows": rows}
 var file := FileAccess.open(OUTPUT.path_join("report.json"), FileAccess.WRITE)
 var valid := file != null and rows.all(func(row: Dictionary): return row.applied and row.foreground_gpu.median_ms > 0.0)
 if file: file.store_string(JSON.stringify(report, "  "))
 await fixture.close()
 quit(0 if valid else 1)
