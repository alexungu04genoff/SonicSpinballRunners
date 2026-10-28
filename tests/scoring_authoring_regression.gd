extends "res://tests/pinball_editor_regression.gd"
const Rings = preload("res://scripts/act_editor/ring_trails.gd")
const SCORING_PATH := "res://test-results/scoring-authoring.tres"
const LEGACY_PATH := "res://test-results/scoring-legacy-14.tres"

func run() -> void:
 if "--reopen-scoring" in OS.get_cmdline_user_args():
  var reopened := ActData.load_document(SCORING_PATH)
  quit(0 if reopened.document != null and reopened.document.fingerprint() == OS.get_cmdline_user_args()[-1] else 1)
  return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 root.size = Vector2i(1440, 1000)
 root.gui_embed_subwindows = true
 editor = EditorScene.instantiate()
 root.add_child(editor)
 await process_frame
 check(editor.document.score_target == 0 and not editor.score_target_enabled.button_pressed, "New Acts keep Free Play exits until a target is enabled")
 editor.score_target_enabled.button_pressed = true
 editor.score_target_field.value = 3456
 check(editor.document.score_target == 3456, "Act Markers checkbox and integer field author the target")
 editor.undo()
 check(editor.document.score_target == 3000, "Target tuning supports undo")
 editor.redo()
 check(editor.document.copy_document().score_target == 3456, "Redo and snapshots retain the Act target")
 editor.set_ring_trail(-1, {"start": Vector2(100, 300), "end": Vector2(200, 300), "spacing": 20.0})
 editor.canvas.select_ring(0)
 var id: String = editor.document.ring_trails[0].pattern_id
 check(not Rings.scoring_settings(editor.document.ring_trails[0]).bonus_rack, "Ordinary patterns start without rack bonuses")
 editor.ring_bonus_field.button_pressed = true
 editor._change_ring_scoring("completion_bonus", 750)
 editor._change_ring_scoring("timeout", 12.123456789012345)
 editor._change_ring_scoring("respawn_delay", 1.123456789012345)
 check(editor.document.ring_trails[0].bonus_rack and editor.document.ring_trails[0].completion_bonus == 750, "Selected pattern exposes optional rack rewards")
 editor.duplicate_selected()
 check(editor.document.ring_trails[1].pattern_id != id and editor.document.ring_trails[1].completion_bonus == 750, "Duplicate retains settings with an independent rack identity")
 editor.undo()
 editor.redo()
 var invalid: Resource = editor.document.copy_document()
 invalid.ring_trails[1].pattern_id = id
 check(not invalid.validation_errors().is_empty(), "Duplicate rack IDs cannot merge independent scoring objectives")
 for bad: Variant in [-1, 1.5, true, "3000", ActData.MAX_SCORE_TARGET + 1]:
  invalid = editor.document.copy_document()
  invalid.score_target = bad
  check(not invalid.validation_errors().is_empty(), "Malformed targets are rejected without numeric coercion")
 editor.choose_gameplay("spinner")
 pointer(Vector2(300, 250), true)
 pointer(Vector2(300, 250), false)
 editor.canvas.select_gameplay(0)
 editor.set_gameplay_property("target_ticks", 12.0)
 editor.set_gameplay_property("completion_bonus", 450.0)
 editor.set_gameplay_property("completion_enabled", false)
 var spinner: Dictionary = editor.document.gameplay_objects[0]
 check(spinner.properties.target_ticks == 12.0 and not spinner.properties.completion_enabled, "Spinner inspector accepts goal fields and disabling")
 editor.set_gameplay_property("target_ticks", 2.5)
 check(spinner.properties.target_ticks == 12.0, "Spinner target ticks must be integral")
 for type: String in ["switch_target", "wall_switch"]:
  editor.choose_gameplay(type)
  pointer(Vector2(150 + 100 * editor.document.gameplay_objects.size(), 400), true)
  pointer(Vector2(150 + 100 * (editor.document.gameplay_objects.size() - 1), 400), false)
 var members: Array[int] = [1, 2]
 editor.canvas.set_gameplay_selection(members)
 editor.create_switch_bank()
 check(editor.document.switch_banks[0].completion_bonus == 500.0 and editor.document.switch_banks[0].reset_delay == 0.75, "New banks award 500 and rearm after 0.75 seconds")
 check(Objects.properties(editor.document.gameplay_objects[1]).score_reward == 0 and Objects.properties(editor.document.gameplay_objects[2]).score_reward == 0, "New floor and wall switches share zero-point defaults")
 var fingerprint: String = editor.document.fingerprint()
 check(editor.save_to(SCORING_PATH), "Scoring settings save through the real Act Editor")
 check(editor.load_from(SCORING_PATH) and editor.document.fingerprint() == fingerprint, "Reload preserves exact target, rack timers, identities, spinner and bank settings")
 var output: Array = []
 var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/scoring_authoring_regression.gd", "--", "--reopen-scoring", fingerprint], output, true)
 check(code == 0, "Fresh Godot process preserves scoring settings and timer bits")
 var legacy := ActData.new()
 legacy.format_version = 14
 legacy.gameplay_objects = [
  {"type": "switch_target", "position": Vector2(100, 100), "rotation_degrees": 0.0, "object_id": "old_switch", "properties": {"score_reward": 25.0}},
  {"type": "spinner", "position": Vector2(200, 100), "rotation_degrees": 0.0, "object_id": "old_spinner", "properties": {"tick_score": 7.0}}
 ]
 legacy.switch_banks = [{"bank_id": "old_bank", "label": "Legacy", "members": ["old_switch"], "gates": [], "completion_bonus": 123.0, "reset_delay": 0.0}]
 legacy.ring_trails = [{"start": Vector2(100, 200), "end": Vector2(100, 200), "spacing": 20.0}]
 check(ResourceSaver.save(legacy, LEGACY_PATH) == OK, "Legacy format fixture saves")
 var original := FileAccess.get_file_as_bytes(LEGACY_PATH)
 var loaded := ActData.load_document(LEGACY_PATH)
 check(loaded.document != null, "Format 14 migrates in memory")
 if loaded.document != null:
  check(loaded.document.score_target == 0 and not Rings.scoring_settings(loaded.document.ring_trails[0]).bonus_rack, "Old Acts stay ungated and single rings do not gain rack bonuses")
  check(loaded.document.gameplay_objects[0].properties.score_reward == 25.0 and loaded.document.gameplay_objects[1].properties.tick_score == 7.0, "Migration preserves explicit legacy switch and spinner rewards")
  check(loaded.document.switch_banks[0].completion_bonus == 123.0 and loaded.document.switch_banks[0].reset_delay == 0.0, "Migration preserves explicit legacy bank rewards and one-shot reset settings")
 check(FileAccess.get_file_as_bytes(LEGACY_PATH) == original, "Migration does not rewrite authored source files")
 var world := Node2D.new()
 root.add_child(world)
 var tuning := PhysicsTuning.new()
 world.add_child(tuning)
 var controls := PlaygroundInput.new()
 world.add_child(controls)
 var ball := PlaygroundBall.new()
 ball.tuning = tuning
 ball.controls = controls
 world.add_child(ball)
 for example: String in ["classic_pinball", "switch_spinner", "speedway_lane"]:
  var sample := ActData.load_document("res://data/acts/scoring/%s.tres" % example)
  check(sample.document != null, "Scoring example loads: " + example)
  if sample.document == null: continue
  var compiled := preload("res://scripts/authored_act/act_runtime_compiler.gd").compile(sample.document, tuning, controls, ball)
  check(compiled.root != null and compiled.error.is_empty(), "Real physics compiler accepts scoring example: " + example + " " + compiled.error)
  if compiled.root != null:
   world.add_child(compiled.root)
   compiled.root.free()
 world.free()
 if DisplayServer.get_name() != "headless":
  for tab: int in [2, 4]:
   editor.palette_tabs.current_tab = tab
   editor._change_palette_tab(tab)
   if tab == 4: editor.canvas.select_ring(0)
   editor._refresh()
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/scoring-authoring-%d.png" % tab)
 editor.free()
 print("RESULT | Scoring authoring | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
