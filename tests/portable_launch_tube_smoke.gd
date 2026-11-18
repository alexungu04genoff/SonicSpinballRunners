extends RefCounted
## Runs inside the actual exported EXE through --portable-smoke --launch-tube.
const WORKSHOP := "res://data/acts/Experiments/Launch Tube Workshop.tres"

static func wait_for(tree: SceneTree, condition: Callable, seconds := 15.0) -> bool:
 var deadline := Time.get_ticks_msec() + int(seconds * 1000)
 while Time.get_ticks_msec() < deadline:
  await tree.process_frame
  if condition.call(): return true
 return false

static func run(host: Node) -> bool:
 var tree := host.get_tree()
 var editor: Control = load("res://scenes/act_geometry_editor.tscn").instantiate()
 tree.root.add_child(editor)
 await tree.process_frame
 var okay: bool = editor.load_from(WORKSHOP)
 if not okay:
  editor.free()
  return false
 var original: String = editor.document.fingerprint()
 editor.canvas.select_gameplay(0)
 editor.set_gameplay_property("presentation", "tunnel")
 okay = okay and editor.document.gameplay_objects[0].properties.presentation == "tunnel"
 editor.undo()
 okay = okay and editor.document.fingerprint() == original
 editor.redo()
 editor.set_gameplay_property("feedback_strength", 0.5)
 var target := OS.get_user_data_dir().path_join("portable-launch-tube-%d.tres" % Time.get_ticks_usec())
 okay = okay and editor.save_to(target) and editor.load_from(target) and editor.document.gameplay_objects[0].properties.presentation == "tunnel"
 editor.free()
 var session: Control = load("res://scripts/prototype/session.gd").new()
 var source_mode := "--tube-source" in OS.get_cmdline_user_args()
 session.settings_path = "user://portable-launch-tube-unused.cfg"
 session.archive_directory = "user://telemetry/runs/_validation/portable_launch_tube"
 session.configure_act_test(target if source_mode else WORKSHOP)
 session.run_configuration.single_act_use_bakes = not source_mode
 session.run_configuration.selected_theme_ids = ["green_hill"]
 session.sound_enabled = false
 tree.root.add_child(session)
 await session.start_run()
 okay = await wait_for(tree, func(): return is_instance_valid(session.game) and session.game.started, 180.0) and okay
 var game: Node = session.game
 if not is_instance_valid(game) or not game.started:
  await session._close_run("validation_failed")
  session.free()
  return false
 var tube: Node = game.ball.launch_tube
 okay = okay and is_instance_valid(tube) and tube.contained
 okay = okay and (game._uses_authoring_builder() if source_mode else game.library.fallback_builds == 0)
 if is_instance_valid(tube):
  okay = okay and tube.properties.presentation == ("tunnel" if source_mode else "exposed")
  okay = okay and is_equal_approx(float(tube.properties.feedback_strength), 0.5 if source_mode else 1.0)
 if is_instance_valid(tube):
  game.controls.virtual_enabled = true
  game.controls.virtual_launch = false
  okay = await wait_for(tree, func(): return not tube.require_release) and okay
  game.controls.virtual_launch = true
  okay = await wait_for(tree, func(): return tube.charge >= 0.15) and okay
  game.controls.virtual_launch = false
  okay = await wait_for(tree, func(): return tube.phase == tube.Phase.RETURNING) and okay
  okay = await wait_for(tree, func(): return tube.phase == tube.Phase.DOCKED) and okay
  okay = await wait_for(tree, func(): return not tube.require_release) and okay
  game.controls.virtual_launch = true
  okay = await wait_for(tree, func(): return tube.charge >= 0.98) and okay
  game.controls.virtual_launch = false
  okay = await wait_for(tree, func(): return not tube.contained) and okay
  var identity: int = game.ball.get_instance_id()
  game.controls.virtual_launch = true
  game._on_ball_drained()
  okay = await wait_for(tree, func(): return not is_instance_valid(game.transfer) and tube.contained) and okay
  for frame in 90: await tree.physics_frame
  okay = okay and game.ball.get_instance_id() == identity and tube.charge == 0.0 and tube.require_release and game.auto_launch_time < 0.0
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   tree.root.get_texture().get_image().save_png(OS.get_user_data_dir().path_join("portable-launch-tube.png"))
 await session._close_run("validation")
 session.free()
 await tree.process_frame
 DirAccess.remove_absolute(target)
 print("PORTABLE_LAUNCH_TUBE_MODE: ", "external authored Tunnel source" if source_mode else "bundled Exposed disk recipe")
 return okay
