extends SceneTree
## Convenience close-up of the canonical playable scene; no private material swaps.
const Game = preload("res://experiments/visual_lab/visual_lab.gd")

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 root.size=Vector2i(1920,1080)
 var game=Game.new()
 game.theme_id="rooftop_run"
 game.authored_act_path="res://data/acts/Third complex.tres"
 root.add_child(game)
 for frame in 20: await process_frame
 game.rooftop_materials.set_mode(1)
 game.rooftop_materials.toggle_detail_camera()
 if "--save-preview" in OS.get_cmdline_user_args():
  for frame in 12: await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://experiments/rooftop_lighting/screenshots/refined-textures-close.png")
