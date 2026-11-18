extends "res://tests/prototype_act_playtest_regression.gd"
## Exercises the pause picker, gameplay shortcut and preferences across sessions.
const ACT := "res://data/acts/Experiments/Side to Side.tres"

func run() -> void:
 var settings_path := "user://camera-picker-%d.cfg" % Time.get_ticks_usec()
 var settings := ConfigFile.new()
 settings.set_value("player", "sound", false)
 settings.set_value("player", "camera_preset", "obsolete")
 settings.save(settings_path)
 session = Session.new()
 session.settings_path = settings_path
 root.add_child(session)
 check(session._read_play_camera() == TablePresentation.CameraPreset.DRAMATIC_PINBALL, "Unknown saved view falls back to Dramatic")
 session._save_play_camera(TablePresentation.CameraPreset.REAL_PINBALL)
 settings.load(settings_path)
 check(session._read_play_camera() == TablePresentation.CameraPreset.REAL_PINBALL and settings.get_value("player", "sound") == false, "Normal runs remember the preset and retain other settings")
 session.configure_act_test(ACT)
 # The test menu uses the authored Act instead of the ordinary baked roster.
 session._show_menu()
 await session.start_run()
 if not await wait_started():
  push_error("Could not start camera picker test")
  quit(1)
  return
 check(session.game.presentation.camera_preset == TablePresentation.CameraPreset.DRAMATIC_PINBALL, "A new editor preview starts with its own default")
 var key := InputEventKey.new()
 key.keycode = KEY_C
 key.pressed = true
 root.push_input(key, true)
 session.game.toggle_pause()
 await process_frame
 await process_frame
 var picker: OptionButton = session.pause_camera_picker
 check(paused and picker.get_selected_id() == TablePresentation.CameraPreset.WIDE_PINBALL and picker.item_count == 4, "Pause shows the live shortcut selection and all four views")
 var top_down := picker.get_item_index(TablePresentation.CameraPreset.TOP_DOWN)
 picker.select(top_down)
 picker.item_selected.emit(top_down)
 check(paused and session.game.presentation.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Choosing by name applies Top-down while paused")
 session.game.toggle_pause()
 await process_frame
 root.push_input(key, true)
 check(session.game.presentation.camera_preset == TablePresentation.CameraPreset.DRAMATIC_PINBALL, "C continues from the menu selection")
 root.push_input(key, true)
 check(session._read_play_camera() == TablePresentation.CameraPreset.WIDE_PINBALL, "The live shortcut saves its selection")
 await session._close_run("finished")
 session.free()
 session = Session.new()
 session.settings_path = settings_path
 session.configure_act_test(ACT)
 root.add_child(session)
 await session.start_run()
 var started := await wait_started()
 check(started and session.game.presentation.camera_preset == TablePresentation.CameraPreset.WIDE_PINBALL, "Fresh preview restores Wide Pinball")
 settings.load(settings_path)
 check(settings.get_value("player", "camera_preset") == TablePresentation.CameraPreset.REAL_PINBALL, "Playtest choices preserve the normal run's camera")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(session._camera_settings_path()))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
 await session._close_run("finished")
 session.free()
 paused = false
 print("RESULT | Camera picker | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
