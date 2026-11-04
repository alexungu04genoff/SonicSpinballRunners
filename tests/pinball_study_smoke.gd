extends "res://tests/authored_gimmick_regression.gd"
func run() -> void:
 root.size = Vector2i(1280, 900)
 game = ObservedGame.new()
 game.authored_act_path = "res://experiments/pinball_vocabulary/study_16.tres"
 root.add_child(game)
 await frames(30)
 check(game.playfield.source == "authored", "Study starts in the normal game", game.last_source_error)
 await move_in_run(Vector2(500, 600), Vector2.ZERO)
 var hardware := visuals()
 var slings := 0
 var banks := 0
 for entry: Dictionary in hardware.gimmicks:
  if entry.kind == "slingshot": slings += 1
  if entry.kind == "drop_target_bank":
   banks += 1
   check(entry.pads.size() == 5, "Five independent target visuals")
   game.ball.mechanics.drop_target(entry.item, entry.item.targets[0])
 await frames(24)
 for entry: Dictionary in hardware.gimmicks:
  if entry.kind == "drop_target_bank": check(entry.pads[0].scale.y < 0.1 and entry.pads[1].scale.y == 1.0, "Independent drop animation")
 check(slings == 2 and banks == 1, "Paired slingshots and bank presented")
 var recipe := preload("res://scripts/endless/visual_recipe.gd").new()
 recipe.capture(hardware)
 recipe.finish()
 preload("res://scripts/endless/static_batches.gd").new().optimize(recipe)
 var restored := Node3D.new()
 root.add_child(restored)
 var nodes: Array[Node] = []
 for i in recipe.records.size(): recipe.instantiate_one(i, nodes, restored)
 recipe.bind_animations(nodes, game.presentation, game.ball.mechanics)
 await frames(2)
 for entry: Dictionary in nodes[0].gimmicks:
  if entry.kind == "drop_target_bank": check(entry.pads[0].scale.y < 0.1 and entry.pads[1].scale.y == 1.0, "Baked animation binding preserves independent target state")
 restored.free()
 if DisplayServer.get_name() != "headless":
  game._toggle_overview()
  await frames(8)
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
  root.get_texture().get_image().save_png("res://test-results/pinball-study.png")
 game.free()
 quit(1 if failures else 0)
