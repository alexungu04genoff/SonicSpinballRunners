extends SceneTree
## Production appearance only. Run via tools/capture_prototype_appearance.ps1.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
var failures := 0
var captures: Array[Dictionary] = []
var output := "res://test-results/prototype-appearance"

func _initialize() -> void:
 Engine.time_scale = 0.0
 run.call_deferred()

func check(value: bool, label: String) -> void:
 if not value:
  failures += 1
  push_error(label)

func run() -> void:
 var act := Fixture.DEFAULT_ACT
 var themes: Array = Fixture.Registry.IDS.duplicate()
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--act="): act = argument.trim_prefix("--act=")
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
  if argument.begins_with("--theme="): themes = [argument.trim_prefix("--theme=")]
  if argument.begins_with("--themes="): themes = Array(argument.trim_prefix("--themes=").split(","))
 if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
  push_error("Canonical captures require Forward+/Vulkan with a graphical display.")
  quit(1)
  return
 root.mode = Window.MODE_WINDOWED
 root.size = Vector2i(1440, 1000)
 root.gui_disable_input = true
 DirAccess.make_dir_recursive_absolute(output)
 # Appearance comparisons must not inherit a player's device-quality experiment.
 var options := preload("res://scripts/rendering_options.gd")
 options.settings_path = output.path_join("isolated-graphics.cfg")
 check(options.pixel_profile().msaa == 4 and options.pixel_profile().scale_percent == 100, "Canonical identity captures retain 4x MSAA and 100% native scale")
 # Freeze shader animation time as well as gameplay for matched review frames.
 var expected := {}
 for theme: String in themes:
  var fixture := Fixture.new()
  if not await fixture.open(self, act, theme, output):
   check(false, fixture.error)
   await fixture.close()
   break
  var before := fixture.state()
  if expected.is_empty(): expected = before
  check(before == expected, "Theme changed the matched Act state/camera: " + theme)
  for frame in 12: await process_frame
  await RenderingServer.frame_post_draw
  check(fixture.state() == before, "Capture advanced gameplay/camera: " + theme)
  check(fixture.still_current(), "Source/bake changed during capture: " + theme)
  check(fixture.authority_error().is_empty(), "Production authority changed: " + theme)
  check(not fixture.session.overlay_root.visible and not fixture.game.loading_panel.visible, "Menu/loading overlay obscures the capture: " + theme)
  var image := root.get_texture().get_image()
  check(image.save_png(output.path_join(theme + ".png")) == OK, "Could not save " + theme)
  var receipt: Dictionary = fixture.receipt.duplicate(true)
  receipt["current_texture_matches"] = fixture.texture_evidence()
  check(fixture.error.is_empty(), fixture.error)
  check(not receipt.current_texture_matches.is_empty(), "No current source pixels found in loaded bake: " + theme)
  receipt["state"] = before
  receipt["graphics"] = {"window_size": str(root.size), "world_size": str(fixture.game.view.size),
   "msaa_3d": fixture.game.view.msaa_3d, "scale_3d": fixture.game.view.scaling_3d_scale,
   "fxaa": fixture.game.view.screen_space_aa, "retro": fixture.game.retro_filter.selected_effects.duplicate(),
   "shadow_atlas": options.shadow_resolution(), "shadow_cascades": options.shadow_cascades(),
   "smooth_shadows": options.smooth_shadows_enabled(),
   "project_shadow_filter": ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality")}
  receipt["image"] = theme + ".png"
  captures.append(receipt)
  print("PROTOTYPE_APPEARANCE | ", theme, " | ", JSON.stringify(before))
  await fixture.close()
 var file := FileAccess.open(output.path_join("manifest.json"), FileAccess.WRITE)
 if file:
  file.store_string(JSON.stringify({"authority": "Prototype", "complete": failures == 0 and captures.size() == themes.size(), "captures": captures}, "  "))
 else: check(false, "Cannot write capture manifest")
 print("RESULT | Prototype appearance | %d captures | %d failures" % [captures.size(), failures])
 quit(1 if failures else 0)
