extends SceneTree
## Matched captures of the real main engine, with optional local authored files.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Filter = preload("res://scripts/retro/retro_filter.gd")
const OUTPUT := "res://test-results/lava-review"
var game: Node
var failures := 0
var manifest: Array[Dictionary] = []
var effect_results: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func frames(count := 8) -> void:
 for i in count: await process_frame

func capture(label: String, framing: String) -> void:
 await frames(10)
 await RenderingServer.frame_post_draw
 var path := OUTPUT + "/" + label + ".png"
 if root.get_texture().get_image().save_png(path) != OK: failures += 1
 manifest.append({"path": path, "theme": game.theme_id, "act": game.authored_act_path if game.level_source == "authored" else game.layout.signature, "fingerprint": game.authored_document.fingerprint() if game.authored_document != null else "generated", "camera": str(game.presentation.camera.global_transform), "ball": str(game.ball.position), "filter": game.retro_filter.display_name(), "framing": framing, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
 if game.theme_id == "lava_reef":
  game.view.get_texture().get_image().save_png(OUTPUT + "/" + label + "-world.png")
 print("CAPTURE | ", path)

func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Captures require a graphical renderer.")
  quit(1)
  return
 root.size = Vector2i(1440, 1000)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var acts := ["res://data/acts/decor_terraces.tres", "res://data/acts/decor_curve_relay.tres"]
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--act="): acts = [argument.trim_prefix("--act=")]
 game = Game.new()
 game.authored_act_path = acts[0]
 root.add_child(game)
 await frames(20)
 paused = true
 for path: String in acts:
  if not game.request_authored_act(path):
   failures += 1
   continue
  for i in 120:
   await frames(1)
   if not game.generation_pending: break
  if game.generation_pending or not game.last_source_error.is_empty():
   failures += 1
   continue
  var original := FileAccess.get_file_as_bytes(path)
  var stem := path.get_file().get_basename().to_snake_case().replace(" ", "_")
  for framing: String in ["overview", "follow"]:
   game.presentation.set_camera_follow(framing == "follow")
   game.retro_filter.set_preset(Filter.Preset.OFF)
   var ids: Array = ["lava_reef"] if OS.get_cmdline_user_args().has("--lava-only") else Themes.IDS
   for theme_id: String in ids:
    if not game.set_theme(theme_id): failures += 1
    await capture(stem + "-" + theme_id + "-" + framing + "-off", framing)
   game.set_theme("lava_reef")
   game.retro_filter.set_effects([Filter.Preset.N64])
   await capture(stem + "-lava_reef-" + framing + "-n64", framing)
   # Exactly the preferred production stack, including VHS.
   game.retro_filter.set_effects([Filter.Preset.N64, Filter.Preset.VHS, Filter.Preset.CRT])
   await capture(stem + "-lava_reef-" + framing + "-retro", framing)
  if OS.get_cmdline_user_args().has("--cavern-study"):
   game.retro_filter.set_preset(Filter.Preset.OFF)
   game.presentation.set_camera_follow(false)
   await frames(12)
   var center: Vector3 = game.presentation.map_point(game.presentation.table_bounds.get_center())
   game.presentation.camera.position = center + Vector3(6, 5, 11)
   game.presentation.camera.look_at(center + Vector3(0, -1.0, -4))
   await capture(stem + "-lava_reef-cavern-study", "cavern study; review camera only")
  if OS.get_cmdline_user_args().has("--effects-study"):
   await effects_study(stem)
  if original != FileAccess.get_file_as_bytes(path): failures += 1
 if OS.get_cmdline_user_args().has("--generated-study"):
  await generated_study()
 # Each normal comparison group must share camera, ball and Act state.
 for entry: Dictionary in manifest:
  if entry.framing not in ["overview", "follow"]: continue
  for other: Dictionary in manifest:
   if entry.act != other.act or entry.framing != other.framing: continue
   if entry.camera != other.camera or entry.ball != other.ball or entry.fingerprint != other.fingerprint:
    push_error("Comparison changed camera, ball or authored layout")
    failures += 1
 var suffix := "-lava-only" if OS.get_cmdline_user_args().has("--lava-only") else ""
 var file := FileAccess.open(OUTPUT + "/manifest-" + str(acts[0].get_file().get_basename()).replace(" ", "_") + suffix + ".json", FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest, "  "))
 file.close()
 if not effect_results.is_empty():
  var effects_file := FileAccess.open(OUTPUT + "/effects.json", FileAccess.WRITE)
  effects_file.store_string(JSON.stringify(effect_results, "  "))
  effects_file.close()
 game.free()
 print("RESULT | Lava Reef captures | %d captures | %d failures" % [manifest.size(), failures])
 quit(0 if failures == 0 else 1)

func shader_time(time: float) -> void:
 for node: Node in game.presentation.find_children("*", "GeometryInstance3D", true, false):
  var mat: Material = node.material_override
  if mat is ShaderMaterial and mat.shader.resource_path.get_file() in ["lava_molten.gdshader", "lava_embers.gdshader", "lava_heat.gdshader"]:
   mat.set_shader_parameter("review_time", time)

func effects_study(stem: String) -> void:
 game.presentation.set_camera_follow(false)
 game.retro_filter.set_preset(Filter.Preset.OFF)
 var camera_before: Transform3D = game.presentation.camera.global_transform
 var ball_before: Transform2D = game.ball.global_transform
 var heat: Array[Node] = game.presentation.find_children("OptionalLocalHeatHaze*", "MeshInstance3D", true, false)
 if heat.is_empty():
  for fall: Node3D in game.presentation.find_children("DistantLavaFall*", "MeshInstance3D", true, false):
   game.presentation.theme_definition._heat(fall.get_parent(), fall.position + Vector3(0,0,0.12))
  heat = game.presentation.find_children("OptionalLocalHeatHaze*", "MeshInstance3D", true, false)
 shader_time(0.0)
 for enabled: bool in [false, true]:
  for node: Node3D in heat: node.visible = enabled
  for preset: int in [Filter.Preset.OFF, Filter.Preset.N64]:
   game.retro_filter.set_preset(preset)
   await frames(20)
   var start := Time.get_ticks_usec()
   await frames(60)
   var milliseconds := float(Time.get_ticks_usec()-start)/60000.0
   var label := stem+"-heat-"+("on" if enabled else "off")+"-"+("off" if preset == Filter.Preset.OFF else "n64")
   await capture(label, "effects study")
   effect_results.append({"heat":enabled,"filter":game.retro_filter.display_name(),"mean_frame_ms":milliseconds,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"note":"60 presented frames after 20 warmup frames; desktop workload and frame pacing included"})
 for node: Node3D in heat: node.hide()
 game.retro_filter.set_preset(Filter.Preset.OFF)
 shader_time(0.0)
 await capture(stem+"-molten-t0", "animation study")
 var before: PackedByteArray = game.view.get_texture().get_image().get_data()
 shader_time(2.5)
 await capture(stem+"-molten-t2_5", "animation study")
 if before == game.view.get_texture().get_image().get_data():
  push_error("Molten shader did not animate between controlled times")
  failures += 1
 if game.presentation.camera.global_transform != camera_before or game.ball.global_transform != ball_before:
  push_error("Effects study changed the camera or physics ball")
  failures += 1
 shader_time(-1.0)

func generated_study() -> void:
 if not game.request_generated_source():
  failures += 1
  return
 for i in 180:
  await frames(1)
  if not game.generation_pending: break
 if game.generation_pending or game.level_source != "generated":
  failures += 1
  return
 game.set_theme("lava_reef")
 game.retro_filter.set_preset(Filter.Preset.OFF)
 for zone: bool in [false,true]:
  if zone:
   if not game.request_generation(18,0,0,{"zone":true,"enabled":false}):
    failures += 1
    continue
   for i in 240:
    await frames(1)
    if not game.generation_pending: break
   if game.generation_pending or not game.zone_enabled:
    failures += 1
    continue
  game.presentation.set_camera_follow(false)
  for preset in 3:
   game.presentation.set_camera_preset(preset)
   await capture(("zone" if zone else "generated")+"-lava_reef-camera-"+str(preset),"generated camera study")
