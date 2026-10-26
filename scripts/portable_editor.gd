extends Node
## Exported release builds select their scene through application arguments.

func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	var scene := "res://scenes/act_geometry_editor.tscn"
	if "--portable-play" in arguments:
		scene = "res://experiments/visual_lab/visual_lab.tscn"
	elif "--portable-bake" in arguments:
		scene = "res://scenes/act_baker.tscn"
	elif "--portable-smoke" in arguments:
		scene = "res://tests/portable_editor_smoke.tscn"
	get_tree().call_deferred("change_scene_to_file", scene)
