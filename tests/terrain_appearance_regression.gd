extends SceneTree
## Exercise baked terrain and the machine-local shadow switch on the real
## Prototype. Held images include the full production Retro stack.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const Options = Review.Options
const Faces = preload("res://scripts/rendering/terrain_faces.gd")
var failures := PackedStringArray()
var output := "user://terrain-appearance-check"

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)

func image() -> Image:
 for i in 4: await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()

func capture_pan(game: Node, theme: String) -> void:
 var presenter: Node = game.presentation
 var start: Vector2 = game.ball.position
 for clean: bool in [false,true]:
  Options.update_quality({"clean_eight_shadows":clean},false)
  var folder := output.path_join(theme + ("-pan-clean8" if clean else "-pan-native"))
  DirAccess.make_dir_recursive_absolute(folder)
  for index in 90:
   var phase := index * TAU / 90.0
   presenter.reset_camera(start + Vector2(100,115) * (0.5 - 0.5*cos(phase)))
   presenter.ring_spin_phase = phase
   presenter._spin_rings(0.0)
   game._update_backgrounds()
   (await image()).save_png(folder.path_join("%03d.png" % index))
 Options.update_quality({"clean_eight_shadows":false},false)

func run() -> void:
 root.size = Vector2i(1280,900)
 Review.position_review_window(root)
 var theme := "rooftop_run"
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
  if arg.begins_with("--theme="): theme = arg.trim_prefix("--theme=")
 DirAccess.make_dir_recursive_absolute(output)
 Options.settings_path = output.path_join("isolated-graphics.cfg")
 var profile := Review.profile("quality")
 check(profile.authored_faces and not profile.clean_eight_shadows, "Default terrain faces and native shadows")
 Options.update_quality(profile,false)
 Engine.time_scale = 0.0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var fixture := Fixture.new()
 var began := Time.get_ticks_usec()
 if await fixture.open(self,Fixture.DEFAULT_ACT,theme,output,"default","production"):
  var startup := (Time.get_ticks_usec()-began)/1000.0
  var game: Node = fixture.game
  var retro = game.retro_filter
  check(retro.selected_effects == retro.settings.default_effects and not retro.selected_effects.is_empty(),"Full production Retro")
  check(fixture.authority_error().is_empty(),"Production disk recipe")
  var receivers := []
  for node: GeometryInstance3D in game.active.visual.find_children("*","GeometryInstance3D",true,false):
   var mat: Material = node.material_override
   if mat is ShaderMaterial and Faces.Surface.FACE_INCLUDE in mat.shader.code:
    receivers.append([node,mat,mat.shader])
    check(mat.shader.resource_path.begins_with("res://data/endless/assets.bake/"),"Face shader came from the baked program bank")
  check(not receivers.is_empty(),"Baked receivers")
  var authored := await image()
  authored.save_png(output.path_join(theme+"-authored.png"))
  Options.update_quality({"authored_faces":false},false)
  var original := await image()
  original.save_png(output.path_join(theme+"-original.png"))
  check(authored.get_data()!=original.get_data(),"Authored faces visible at gameplay distance")
  var before := Fixture.Report.pipelines()
  var tick := Time.get_ticks_usec()
  Options.update_quality({"authored_faces":true},false)
  var enable_ms := (Time.get_ticks_usec()-tick)/1000.0
  var intervals := []
  for i in 60:
   await process_frame
   var now := Time.get_ticks_usec()
   intervals.append((now-tick)/1000.0)
   tick = now
  check(before == Fixture.Report.pipelines(),"Authored face toggle reuses prepared pipelines")
  check((await image()).get_data()==authored.get_data(),"Exact authored restore")
  var clean_start := Time.get_ticks_usec()
  Options.update_quality({"clean_eight_shadows":true},false)
  var banded := await image()
  var first_clean_capture_ms := (Time.get_ticks_usec()-clean_start)/1000.0
  banded.save_png(output.path_join(theme+"-clean8.png"))
  check(banded.get_data()!=authored.get_data(),"Clean 8 changes the directional shadow")
  var overlays := 0
  for slot: Array in receivers:
   if slot[0].material_overlay: overlays += 1
   check(slot[0].material_override==slot[1] and slot[1].shader==slot[2],"Original baked material identity")
  check(overlays>0,"Clean 8 receiver overlay")
  Options.update_quality({"clean_eight_shadows":false},false)
  check((await image()).get_data()==authored.get_data(),"Exact native shadow restore")
  for slot: Array in receivers: check(slot[0].material_overlay==null,"Native shadow has no correction pass")
  # Compare the actual production rendering with the previously auditioned
  # treatment at the exact same pose, after measuring production-only timing.
  Options.update_quality({"authored_faces":false},false)
  var reference = preload("res://experiments/retro_ao_lab/receivers.gd").new()
  reference.apply({"face_study":true,"contact_strength":0.62})
  reference.sync(game,true)
  var lab_image := await image()
  var delta := authored.compute_image_metrics(lab_image,false)
  print("FACE_REFERENCE | ",theme," metrics=",delta)
  check(delta.max == 0.0,"Pixel match with the reviewed face treatment at the held pose")
  reference.clear()
  Options.update_quality({"authored_faces":true},false)
  if "--pan" in OS.get_cmdline_user_args(): await capture_pan(game,theme)
  print("TERRAIN_APPEARANCE | ",theme," receivers=",receivers.size()," clean8=",overlays," startup_ms=",startup,
   " face_toggle_ms=",enable_ms," first_clean_capture_ms=",first_clean_capture_ms," next60=",Fixture.Report.timing(intervals))
 else: check(false,fixture.error)
 await fixture.close()
 print("TERRAIN_APPEARANCE_RESULT | ",theme," failures=",failures)
 quit(0 if failures.is_empty() else 1)
