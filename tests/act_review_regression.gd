extends SceneTree
## Focused metadata, factual evidence and editor-only review regression.
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Objects = preload("res://scripts/act_editor/gameplay_objects.gd")
const Review = preload("res://scripts/act_editor/act_review.gd")
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const EditorScene = preload("res://scenes/act_geometry_editor.tscn")
const PATH := "user://act-review-regression.tres"
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func run() -> void:
 var document := Document.new()
 check(document.authored_difficulty == 3 and document.difficulty_label() == "Standard" and document.design_thesis == "", "New Acts default to Standard and optional empty thesis")
 var original := document.fingerprint()
 document.authored_difficulty = 4
 var rated := document.fingerprint()
 document.design_thesis = "Two orbits feed the upper route. · A human judgment."
 check(original != rated and rated != document.fingerprint(), "Both authored fields participate in document fingerprint")
 check(document.copy_document().fingerprint() == document.fingerprint(), "Undo snapshots preserve metadata exactly")
 check(document.save_document(PATH) == OK, "Save metadata using ordinary Act persistence")
 var loaded: Resource = Document.load_document(PATH).document
 check(loaded != null and loaded.authored_difficulty == 4 and loaded.design_thesis == document.design_thesis and loaded.fingerprint() == document.fingerprint(), "Difficulty, Unicode thesis and fingerprint survive save/load")
 var bake := Bake.new()
 bake.theme_id = "green_hill"
 bake.pipeline_fingerprint = "fixture"
 bake.source_fingerprint = document.fingerprint()
 check(bake.matches_geometry(document, "green_hill", "fixture"), "Bake accepts matching document fingerprint")
 document.authored_difficulty = 5
 check(not bake.matches_geometry(document, "green_hill", "fixture"), "Metadata edit invalidates the existing full-document bake receipt")
 document = Document.new()
 document.save_document(PATH)
 var text := FileAccess.get_file_as_string(PATH)
 for version in [2, 15, 16, 17]:
  var legacy := text.replace("format_version = 18", "format_version = %d" % version)
  var file := FileAccess.open(PATH, FileAccess.WRITE)
  file.store_string(legacy)
  file.close()
  loaded = Document.load_document(PATH).document
  check(loaded != null and loaded.format_version == 18 and loaded.authored_difficulty == 3 and loaded.design_thesis == "", "Legacy v%d migrates to Standard without a thesis" % version)
  check(FileAccess.get_file_as_string(PATH) == legacy, "Legacy v%d migration does not rewrite source" % version)
 document.authored_difficulty = true
 check(not document.validation_errors().is_empty(), "Malformed difficulty is rejected without silently coercing it")
 document.authored_difficulty = 3
 document.design_thesis = "x".repeat(241)
 check(not document.validation_errors().is_empty(), "Thesis length has a bounded data contract")
 document.design_thesis = ""
 var baseline := ["left_flipper", "right_flipper", "slingshot", "spring", "buzz_bomber", "round_bumper", "triangle_bumper"]
 for type: String in baseline: document.gameplay_objects.append(Objects.make_placement(type))
 document.ring_trails = [{"start": Vector2(100, 100), "end": Vector2(200, 100), "spacing": 25.0}]
 var facts := Review.summarize(document)
 check(facts.rings == 5 and facts.families.is_empty() and facts.counts.left_flipper == 1 and facts.counts.right_flipper == 1, "Baseline vocabulary contributes factual counts but no featured families")
 for type: String in ["switch_target", "wall_switch", "drop_target_bank", "drop_target_bank", "one_way_gate", "elevated_rail", "diverter", "spinner", "dash_panel"]:
  document.gameplay_objects.append(Objects.make_placement(type))
 document.switch_banks = [{"bank_id": "bank", "label": "Bank", "members": [document.gameplay_objects[7].object_id], "gates": []}]
 document.ring_trails.append({"kind": "ellipse", "start": Vector2(100, 100), "end": Vector2(250, 200), "spacing": 25.0, "fill": false, "rotation_degrees": 0.0})
 facts = Review.summarize(document)
 check(facts.families.size() == 7 and facts.families.count("Switch") == 1 and facts.families.count("Drop Targets") == 1, "Switch targets/banks and repeated Drop Banks share conceptual families")
 check(facts.rings == RingField.document_records(document, "review").size() and facts.rail_rings > 0, "Pattern, ellipse and rail ring counts match runtime pickup generation")
 var prior := document.fingerprint()
 Review.summarize(document)
 check(document.fingerprint() == prior and document.authored_difficulty == 3, "Facts and hints never mutate the Act or its rating")
 document.ring_trails.clear()
 document.gameplay_objects.clear()
 document.switch_banks.clear()
 facts = Review.summarize(document)
 check(facts.rings == 0 and facts.families.is_empty() and facts.hints.size() == 3, "Removing objects and rings removes counts and updates only advisory hints")
 check(document.validation_errors().is_empty() and document.save_document(PATH) == OK, "An empty draft with review hints remains valid and saveable")
 document.goal_diameter_cells = 0.25
 for type: String in ["spinner", "one_way_gate", "drop_target_bank", "dash_panel"]:
  document.gameplay_objects.append(Objects.make_placement(type))
 facts = Review.summarize(document)
 check(facts.hints.size() == 5 and is_equal_approx(facts.goal_diameter / facts.ball_diameter, 0.25 / 0.28), "Five bounded hints use featured-family count and shared physical Goal scale")
 root.size = Vector2i(1280, 900)
 var editor: Control = EditorScene.instantiate()
 root.add_child(editor)
 await process_frame
 var panel: ScrollContainer = editor.review_panel
 var clean: String = editor.document.fingerprint()
 panel.checkboxes[0].button_pressed = true
 editor._refresh()
 check(panel.checkboxes[0].button_pressed and editor.document.fingerprint() == clean and not editor.is_dirty(), "Checklist survives selection refresh without touching document or dirty state")
 panel.difficulty.select(1)
 panel.difficulty.item_selected.emit(1)
 check(editor.document.authored_difficulty == 2 and editor.is_dirty() and not panel.checkboxes[0].button_pressed, "Difficulty UI records an undoable authored edit and clears checklist")
 panel.thesis.text = "A deliberate orbit."
 panel.thesis.text_changed.emit(panel.thesis.text)
 check(editor.document.design_thesis == "A deliberate orbit.", "Thesis UI edits authored metadata")
 editor.undo()
 check(editor.document.design_thesis == "" and panel.thesis.text == "", "Undo restores thesis and UI")
 editor.undo()
 check(editor.document.authored_difficulty == 3 and panel.difficulty.get_selected_id() == 3, "Undo restores difficulty and UI")
 editor.redo()
 check(editor.document.authored_difficulty == 2, "Redo restores authored rating")
 editor.set_ring_trail(-1, {"start": Vector2(100, 100), "end": Vector2(200, 100), "spacing": 25.0})
 check(panel.facts.rings == 5, "Editor ring gesture refreshes review counts")
 editor.undo()
 check(panel.facts.rings == 0, "Undo refreshes counts after ring removal")
 editor.add_gameplay_placement(Objects.make_placement("buzz_bomber"))
 check(panel.facts.counts.buzz_bomber == 1, "Object addition refreshes review counts")
 editor.canvas.select_gameplay(0)
 editor.delete_selected()
 check(panel.facts.counts.buzz_bomber == 0, "Object deletion refreshes review counts")
 var report_before: Dictionary = editor.verification_report()
 panel.checkboxes[0].button_pressed = true
 check(editor.verification_report() == report_before and editor.save_to(PATH), "Checklist does not change verification or block Save")
 editor.load_from(PATH)
 check(not panel.checkboxes[0].button_pressed, "Load clears stale session checks")
 if DisplayServer.get_name() != "headless":
  editor.load_from("res://data/acts/Experiments/Lockbox.tres")
  editor.review_panel.get_parent().current_tab = 1
  for frame in 5: await process_frame
  check(Rect2(Vector2.ZERO, root.size).encloses(editor.canvas.get_global_rect()), "Review tab keeps canvas within viewport")
  await RenderingServer.frame_post_draw
  DirAccess.make_dir_recursive_absolute("res://test-results")
  root.get_texture().get_image().save_png("res://test-results/act-review.png")
  for child: Node in panel.get_child(0).get_children():
   if child is Button and (child.text.ends_with("Identity") or child.text.ends_with("SHOT SCALE")): child.button_pressed = true
  for frame in 5: await process_frame
  panel.scroll_vertical = 560
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/act-review-checklist.png")
 editor.free()
 DirAccess.remove_absolute(PATH)
 print("RESULT | Act review | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
