extends SceneTree
## Include the exact bundled engine's license notices in a portable distribution.
func _initialize() -> void:
	var output := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(Engine.get_license_text())
	output.store_string("\n\nThird-party licenses\n")
	var licenses := Engine.get_license_info()
	for name in licenses:
		output.store_string("\n" + name + "\n" + str(licenses[name]) + "\n")
	output.close()
	quit()
