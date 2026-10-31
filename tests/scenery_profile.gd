extends "res://tests/atmosphere_profile.gd"
## Local scenery is captured and optimized through the production bake path.
## Generated terrain/shared far scenery stay matched across density samples.
const Recipe := preload("res://scripts/endless/visual_recipe.gd")
const Batches := preload("res://scripts/endless/static_batches.gd")

func run() -> void:
 if DisplayServer.get_name() == "headless":
  quit(1)
  return
 output = "res://test-results/scenery-authoring/profile"
 var reverse := "--scenery-reverse" in OS.get_cmdline_user_args()
 if reverse: output += "-reverse"
 samples = 360 if reverse else 120
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 root.size = Vector2i(1280, 900)
 seed(18)
 game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 game.authored_act_path = "res://data/acts/Authored/Reverse C Spring.tres"
 root.add_child(game)
 game.view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 game.development_footer.hide()
 game.debug_panel.hide()
 game.development_subtitle.hide()
 paused = true
 root.gui_disable_input = true
 Report.disable_native_input(game)
 await frames(120)
 _views(root)
 var panel = game.lighting_controls
 panel.saved = ConfigFile.new()
 panel.drafts.clear()
 panel.reset_values()
 panel.panel.hide()
 panel.fps_overlay.hide()
 panel.reopen.hide()
 game.presentation.set_process(false)
 for theme_id: String in ["green_hill", "chemical_plant", "sky_sanctuary", "ice_cap", "casino_night", "rooftop_run"]:
  game.set_theme(theme_id)
  panel.reset_values()
  game.presentation.set_process(false)
  await frames(60)
  for density: float in ([1.5, 1.0, 0.5] if reverse else [0.5, 1.0, 1.5]):
   var start := Time.get_ticks_usec()
   panel.scenery.change({"seed": 183742, "density": density})
   await frames(3)
   var stats := _bake_local()
   preparation.append({"theme": theme_id, "density": density, "generation_and_bake_ms": (Time.get_ticks_usec() - start) / 1000.0, "batch_stats": stats})
   await frames(90)
   for side: int in [-1, 1]:
    panel.scenery.frame_edge(side)
    game.retro_controls.toast.hide()
    await frames(60)
    var label := theme_id + "-" + str(density) + ("-left" if side < 0 else "-right")
    var result := await sample(theme_id, label, 0)
    result.density = density
    result.side = side
    result.local_groups = game.presentation.scenery_group_count
    results.append(result)
    if not reverse: await capture(label)
  # Additional deterministic compositions in both approved views.
  for seed_value: int in ([] if reverse else [0, 9127]):
   panel.scenery.change({"seed": seed_value, "density": 1.0})
   await frames(3)
   _bake_local()
   await frames(30)
   for side: int in [-1, 1]:
    panel.scenery.frame_edge(side)
    await frames(10)
    await capture(theme_id + "-seed" + str(seed_value) + ("-left" if side < 0 else "-right"))
 panel.panel.show()
 panel.tabs.current_tab = panel.tabs.get_tab_count() - 1
 panel.scenery.update_diagnostics()
 await frames(5)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("scenery-controls.png"))
 var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
 file.store_string(JSON.stringify({"metadata": Report.metadata(), "samples": samples, "results": results, "preparation": preparation, "note": "One paused Reverse C Spring Act, optimized baked local scenery, matched generated terrain/shared far scenery, 1280x900 window, existing retro stack. GPU values sum active viewport timings. Not a whole-run benchmark."}, "  "))
 file.close()
 game.free()
 print("SCENERY_PROFILE_COMPLETE | ", output)
 quit()

func _bake_local() -> Dictionary:
 var root_node: Node3D = game.presentation.scenery_root
 var recipe := Recipe.new()
 for child: Node in root_node.get_children():
  if child.get_meta("atmosphere_scenery", "") != "local": continue
  var before := recipe.records.size()
  recipe.capture(child)
  for index in range(before, recipe.records.size()): recipe.records[index].background = true
  root_node.remove_child(child)
  child.free()
 recipe.finish()
 assert(recipe.error.is_empty(), recipe.error)
 var stats: Dictionary = Batches.new().optimize(recipe)
 var baked := Node3D.new()
 baked.name = "BakedLocalScenery"
 baked.set_meta("atmosphere_scenery", "local")
 root_node.add_child(baked)
 var nodes: Array[Node] = []
 for index in recipe.records.size(): recipe.instantiate_one(index, nodes, baked)
 return stats
