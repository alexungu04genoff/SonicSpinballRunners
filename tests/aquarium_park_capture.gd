extends SceneTree
## Production same-Act comparisons; fixed camera, ball and document throughout.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Filter = preload("res://scripts/retro/retro_filter.gd")
var output := "res://test-results/aquarium-review"
var game: Node
var failures := 0
var manifest: Array[Dictionary] = []

func _initialize() -> void:
 call_deferred("run")

func frames(count := 8) -> void:
 for i in count: await process_frame

func capture(label: String, framing: String) -> void:
 await frames(12)
 await RenderingServer.frame_post_draw
 var path := output+"/"+label+".png"
 if root.get_texture().get_image().save_png(path) != OK: failures += 1
 manifest.append({"path":path,"theme":game.theme_id,"act":game.authored_act_path,"fingerprint":game.authored_document.fingerprint(),"camera":str(game.presentation.camera.global_transform),"ball":str(game.ball.position),"filter":game.retro_filter.display_name(),"framing":framing,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
 if game.theme_id == "aquarium_park": game.view.get_texture().get_image().save_png(output+"/"+label+"-world.png")
 print("CAPTURE | ",path)

func run() -> void:
 if OS.get_cmdline_user_args().has("--sheet-only"):
  comparison_sheet()
  quit(0 if failures == 0 else 1)
  return
 if DisplayServer.get_name() == "headless":
  push_error("Captures require a graphical renderer.")
  quit(1)
  return
 root.size = Vector2i(1440,1000)
 var act := "res://data/acts/decor_terraces.tres"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--act="): act = argument.trim_prefix("--act=")
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 game = Game.new()

 game.authored_act_path = act
 root.add_child(game)
 await frames(20)
 paused = true
 if game.authored_document == null:
  push_error("Authored Act failed to load")
  game.free()
  quit(1)
  return
 var original := FileAccess.get_file_as_bytes(act)
 for framing: String in ["overview","follow"]:
  game.presentation.set_camera_follow(framing == "follow")
  game.retro_filter.set_preset(Filter.Preset.OFF)
  var ids: Array = ["aquarium_park"] if OS.get_cmdline_user_args().has("--aquarium-only") else Themes.IDS
  for id: String in ids:
   if not game.set_theme(id): failures += 1
   await capture(id+"-"+framing+"-off",framing)
  game.set_theme("aquarium_park")
  game.retro_filter.set_effects([Filter.Preset.N64])
  await capture("aquarium_park-"+framing+"-n64",framing)
  game.retro_filter.set_effects([Filter.Preset.N64,Filter.Preset.VHS,Filter.Preset.CRT])
  await capture("aquarium_park-"+framing+"-retro",framing)
 game.retro_filter.set_preset(Filter.Preset.OFF)
 game.presentation.set_camera_follow(false)
 await frames(8)
 var center: Vector3 = game.presentation.map_point(game.presentation.table_bounds.get_center())
 game.presentation.camera.position = center+Vector3(9,5,13)
 game.presentation.camera.look_at(center+Vector3(0,-1,-5))
 await capture("park-study","study")
 var water: ShaderMaterial = game.presentation.theme_definition._library.materials.water
 water.set_shader_parameter("time_override",0.0)
 await capture("water-t0","animation")
 var before: PackedByteArray = game.view.get_texture().get_image().get_data()
 water.set_shader_parameter("time_override",2.5)
 await capture("water-t2_5","animation")
 if before == game.view.get_texture().get_image().get_data():
  push_error("Water did not animate between controlled times")
  failures += 1
 water.set_shader_parameter("time_override",-1.0)
 if original != FileAccess.get_file_as_bytes(act): failures += 1
 for entry: Dictionary in manifest:
  if entry.framing not in ["overview","follow"]: continue
  for other: Dictionary in manifest:
   if entry.framing != other.framing: continue
   if entry.camera != other.camera or entry.ball != other.ball or entry.fingerprint != other.fingerprint:
    push_error("Comparison changed camera, ball or authored layout")
    failures += 1
 var file := FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  "))
 file.close()
 if not OS.get_cmdline_user_args().has("--aquarium-only"): comparison_sheet()
 game.free()
 print("RESULT | Aquarium Park captures | %d captures | %d failures" % [manifest.size(),failures])
 quit(0 if failures == 0 else 1)

func comparison_sheet() -> void:
 var sheet := Image.create(1440,2000,false,Image.FORMAT_RGB8)
 sheet.fill(Color("0d1c2c"))
 for i in Themes.IDS.size():
  var path := output+"/"+str(Themes.IDS[i])+"-overview-off.png"
  var panel := Image.load_from_file(path)
  if panel == null or panel.is_empty():
   failures += 1
   continue
  panel.convert(Image.FORMAT_RGB8)
  panel.resize(720,500,Image.INTERPOLATE_LANCZOS)
  sheet.blit_rect(panel,Rect2i(0,0,720,500),Vector2i((i%2)*720,(i/2)*500))
 if sheet.save_png(output+"/eight-themes.png") != OK: failures += 1
