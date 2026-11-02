extends Node
## Exported release builds select their scene through application arguments.

func _ready() -> void:
	var workspace = preload("res://scripts/portable_workspace.gd")
	var error: Error = workspace.prepare()
	if error != OK:
		push_error("Cannot prepare the portable workspace: " + error_string(error))
		var message := Label.new()
		message.position = Vector2(24, 24)
		message.text = "Cannot write Acts / Atmospheres beside the EXE.\nMove both tools into a writable folder and reopen.\n" + error_string(error)
		add_child(message)
		return
	var arguments := OS.get_cmdline_user_args()
	var scene := "res://scenes/act_geometry_editor.tscn"
	if ProjectSettings.get_setting("portable_tools/default_tool", "geometry") == "atmosphere":
		scene = "res://experiments/lighting_lab/lighting_lab.tscn"
	if "--portable-play" in arguments:
		scene = "res://experiments/visual_lab/visual_lab.tscn"
	elif "--portable-bake" in arguments:
		scene = "res://scenes/act_baker.tscn"
	elif "--portable-smoke" in arguments:
		scene = "res://tests/portable_editor_smoke.tscn"
	elif "--portable-atmosphere-smoke" in arguments:
		scene = "res://tests/portable_atmosphere_smoke.tscn"
	get_tree().call_deferred("change_scene_to_file", scene)
