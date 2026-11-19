extends SceneTree
## Frozen rendering diagnostic. Oversized displays stay embedded on monitor 2.
const Session = preload("res://scripts/prototype/session.gd")
const Report = preload("res://tests/render_profile_support.gd")
const ACT := "res://data/acts/Authored/First Try Smooth Decor.tres"
const SIZES := [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160),Vector2i(2560,1080),Vector2i(3440,1440),Vector2i(1600,1200),Vector2i(1280,900)]
var output := "res://test-results/display-framing/before"
var expect_fixed := false
var legacy_layout := false
var failures := 0
var checks := 0
var records: Array = []
var window: Window

class Stream extends "res://scripts/endless/endless_game.gd":
 func _next_planned_zone(documents: Array) -> Array[Dictionary]:
  if planner.sequence == 0: planner.themes = ["casino_night", "green_hill"]
  return planner.next_zone(documents)

func _initialize() -> void:
 Engine.time_scale = 0.0
 run.call_deferred()

func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)

func frames(count := 5) -> void:
 for index in count: await process_frame

func wait_started(game: Node) -> bool:
 var end := Time.get_ticks_msec() + 180000
 while not game.started and Time.get_ticks_msec() < end:
  if not game.last_source_error.is_empty(): break
  await process_frame
 return game.started

func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
  if arg == "--expect-fixed": expect_fixed = true
  if arg == "--legacy-layout": legacy_layout = true
 root.size = Vector2i(960,540)
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.gui_embed_subwindows = true
 DirAccess.make_dir_recursive_absolute(output)
 preload("res://scripts/rendering_options.gd").settings_path = output.path_join("isolated-graphics.cfg")
 for mode: String in ["prototype", "endless"]: await inspect_mode(mode)
 check(records.size() == SIZES.size()*4*2*2,"Complete matrix in both modes")
 FileAccess.open(output.path_join("matrix.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"fixed":expect_fixed,"records":records,"renderer":Report.metadata(),"capture_method":"Embedded Window: production Canvas Items layout measured first; VIEWPORT used only for complete logical-canvas readback, then uniformly fitted to requested physical output. No native 4K/ultrawide monitor or performance claim."},"  "))
 print("RESULT | Display framing matrix | %d checks | %d failures | %d records" % [checks,failures,records.size()])
 quit(1 if failures else 0)

func inspect_mode(mode: String) -> void:
 paused = false
 window = Window.new()
 window.name = "FramingDiagnostic"
 window.size = SIZES[0]
 window.content_scale_size = Vector2i(1280,900)
 window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
 root.add_child(window)
 window.show()
 var session: Control
 var game: Node
 if mode == "prototype":
  session = Session.new()
  session.settings_path = output.path_join("isolated-session.cfg")
  session.archive_directory = output.path_join("isolated-telemetry")
  session.configure_act_test(ACT)
  session.run_configuration.single_act_use_bakes = true
  session.run_configuration.atmosphere_overrides = {"green_hill":"default"}
  session.sound_enabled = false
  window.add_child(session)
  await session._start_configured_run(session.run_configuration,session.selected_character,session.practice_mode,18)
  game = session.game
 else:
  game = Stream.new()
  window.add_child(game)
 check(await wait_started(game), mode+" starts")
 if not game.started: return
 game._update_hud(0.0)
 if legacy_layout:
  var guard := game.get_node_or_null("GameplayDisplayContract")
  if guard != null: guard.free()
  window.content_scale_size = Vector2i(1280,900)
  window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
  window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
 paused = true
 if session != null:
  session.set_process(false)
  session.overlay_root.hide()
 game.set_process(false)
 game.set_physics_process(false)
 game.presentation.set_process(false)
 game.ball.freeze = true
 game.auto_launch_time = -1.0
 if game.get("fps_label") != null: game.fps_label.hide()
 if game.get("diagnostics") != null: game.diagnostics.hide()
 Report.disable_native_input(game)
 var frozen := [game.ball.position,game.ball.linear_velocity,game.score,game.active_sequence,game.active.document.fingerprint()]
 var original_settings: Dictionary = game.retro_filter.settings.get_property_list().reduce(func(acc: Dictionary, property: Dictionary):
  if property.usage & PROPERTY_USAGE_STORAGE: acc[property.name] = game.retro_filter.settings.get(property.name)
  return acc, {})
 var default_effects: Array = game.retro_filter.selected_effects.duplicate()
 var references := {}
 for size: Vector2i in SIZES:
  window.size = size
  await frames()
  for preset: int in game.PLAY_CAMERAS:
   for retro_on: bool in [true,false]:
    game.retro_filter.set_effects(default_effects if retro_on else [])
    await frames(3)
    game.presentation.set_camera_preset(preset)
    game.presentation.reset_camera(game.ball.position)
    game._update_backgrounds()
    await frames(3)
    var row := measure(game, mode, size, preset, retro_on)
    var key := "%d-%s" % [preset,retro_on]
    if not references.has(key): references[key] = row
    var reference: Dictionary = references[key]
    row["max_landmark_delta"] = landmark_delta(reference.landmarks, row.landmarks)
    if expect_fixed:
     check(row.max_landmark_delta < 0.00001, "Fixed normalized framing: "+mode+" / "+str(size)+" / "+key)
     check(row.logical == Vector2(1600,900), "Fixed logical gameplay extent")
    check(game._composite_view.size == game.view.size, "Composite and foreground align")
    for background: Dictionary in game.backgrounds.values():
     if background.layer.modulate.a <= 0.0: continue
     check(background.layer.view.size == game.view.size and background.layer.camera.global_transform.is_equal_approx(game.presentation.camera.global_transform), "Active backdrop aligns")
    check(frozen == [game.ball.position,game.ball.linear_velocity,game.score,game.active_sequence,game.active.document.fingerprint()], "Frozen gameplay remains identical")
    check(game.library.fallback_builds == 0, "Required disk authority")
    if retro_on and (preset == game.PLAY_CAMERAS[0] or size == SIZES[0]):
     row["image"] = "%s-%dx%d-camera%d.jpg" % [mode,size.x,size.y,preset]
     await capture(row.image,size)
    records.append(row)
    print("DISPLAY_ROW | ", mode, " | ", size, " | camera=",preset," retro=",retro_on," logical=",row.logical," world=",row.world," delta=",row.max_landmark_delta)
 game.retro_filter.set_effects(default_effects)
 for key: String in original_settings: check(game.retro_filter.settings.get(key) == original_settings[key], "Retro art setting retained: "+key)
 check(not FileAccess.file_exists(session.settings_path) if session != null else true,"No player preferences written")
 if session != null:
  session.archive_attempted = true
  await session._close_run("framing_diagnostic")
  session.free()
 else:
  await game.prepare_to_close()
  game.free()
 window.free()
 paused = false
 await frames(2)

func measure(game: Node, mode: String, size: Vector2i, preset: int, retro_on: bool) -> Dictionary:
 var camera: Camera3D = game.presentation.camera
 var points := []
 var center: Vector2 = game.ball.position
 for offset: Vector2 in [Vector2.ZERO,Vector2(-200,-200),Vector2(200,-200),Vector2(-200,200),Vector2(200,200)]:
  points.append(camera.unproject_position(TablePresentation.map_point(center+offset))/Vector2(game.view.size))
 var floor_corners := []
 for uv: Vector2 in [Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)]:
  var origin := camera.project_ray_origin(uv*Vector2(game.view.size))
  var ray := camera.project_ray_normal(uv*Vector2(game.view.size))
  floor_corners.append(origin-ray*(origin.y/ray.y))
 return {"mode":mode,"requested_size":size,"logical":window.get_visible_rect().size,"canvas_transform":str(window.get_final_transform()),"preset":preset,"retro":retro_on,"world":game.view.size,"composite":game._composite_view.size,"projection":camera.projection,"fov":camera.fov,"ortho_size":camera.size,"camera":str(camera.global_transform),"landmarks":points,"floor_corners":floor_corners,"hud_heading":game.heading.get_global_rect(),"msaa":game.view.msaa_3d,"world_scale":game.view.scaling_3d_scale,"divisor":game.retro_filter._resolution_divisor,"seed":game.run_seed,"ball":game.ball.position,"velocity":game.ball.linear_velocity,"score":game.score,"act":game.active.document.fingerprint(),"theme":game.active.plan.theme,"atmosphere":game.active.plan.atmosphere.duplicate(true)}

func landmark_delta(a: Array, b: Array) -> float:
 var largest := 0.0
 for index in a.size(): largest = maxf(largest,Vector2(a[index]).distance_to(Vector2(b[index])))
 return largest

func capture(filename: String, size: Vector2i) -> void:
 # Embedded Canvas Items readback omits its final window stretch. VIEWPORT
 # captures the complete same logical canvas; this is a framing image, not a
 # claim about native-resolution HUD raster quality or GPU timing.
 var logical := window.get_visible_rect().size
 window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
 await frames(3)
 await RenderingServer.frame_post_draw
 var source := window.get_texture().get_image()
 check(window.get_visible_rect().size == logical,"Capture leaves logical layout unchanged")
 var fit := minf(float(size.x)/source.get_width(),float(size.y)/source.get_height())
 var fitted := Vector2i(Vector2(source.get_size())*fit)
 source.resize(fitted.x,fitted.y,Image.INTERPOLATE_LANCZOS)
 var pixels := Image.create(size.x,size.y,false,source.get_format())
 pixels.fill(Color.BLACK)
 pixels.blit_rect(source,Rect2i(Vector2i.ZERO,fitted),(size-fitted)/2)
 check(pixels.save_jpg(output.path_join(filename),0.87)==OK,"Save framing capture")
 window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 await frames(3)
