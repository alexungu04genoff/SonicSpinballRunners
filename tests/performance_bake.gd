extends SceneTree
## Build matched diagnostic recipes with the same source and pipeline receipt.
func _initialize() -> void:
 preload("res://scripts/pinball_mesh_batch.gd").shadow_batch_enabled = not "--profile-original-shadows" in OS.get_cmdline_user_args()
 preload("res://scripts/endless/bake_assets.gd").share_generated_shaders = not "--profile-embedded-shaders" in OS.get_cmdline_user_args()
 print("PERFORMANCE_BAKE | combined_shadows=%s shared_shaders=%s" % [
  preload("res://scripts/pinball_mesh_batch.gd").shadow_batch_enabled,
  preload("res://scripts/endless/bake_assets.gd").share_generated_shaders])
 call_deferred("run")

func run() -> void:
 root.add_child(load("res://scenes/act_baker.tscn").instantiate())
