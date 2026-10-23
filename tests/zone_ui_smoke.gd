extends "res://tests/score_attack_regression.gd"
## UI state fixtures, not a traversal witness. Run graphically for review captures;
## add -- --green-hill to exercise the integrated presentation.

func capture(label: String) -> void:
 if DisplayServer.get_name() == "headless":
  return
 await create_timer(0.25).timeout
 await RenderingServer.frame_post_draw
 var filename := "res://test-results/zone-ui-%s-%s.png" % ["green-hill" if green_hill else "playground", label]
 check(root.get_texture().get_image().save_png(filename) == OK, "Rendered " + label)

func run() -> void:
 green_hill = OS.get_cmdline_user_args().has("--green-hill")
 var scene := "res://experiments/visual_lab/visual_lab.tscn" if green_hill else "res://scenes/playground.tscn"
 game = load(scene).instantiate()
 game.zone_enabled = true
 game.generation_seed = 18
 root.add_child(game)
 await frames(5)
 var panel: ZonePanel = game.debug_panel.challenge_panel.zone_panel
 check(panel.visible and panel.hud.visible and not panel.modal.visible, "Zone HUD visible before launch, draft hidden")
 check(panel.heading.text.contains("ACT 1 / 3"), "Zone HUD identifies initial Act")
 game.score = game.zone.targets[0]
 game.zone.observe_score(game.score)
 await frames(2)
 check(panel.exit_label.text.contains("UNLOCKED"), "HUD reflects Act unlock")
 await capture("hud")
 game.zone.completed_acts = 1
 game.zone.state = ZoneRun.State.DRAFT
 paused = true
 game.zone.changed.emit()
 await frames(3)
 check(panel.modal.visible and panel.draft.visible, "Draft modal appears while paused")
 check(panel.modal.size == root.get_visible_rect().size, "Draft modal covers viewport")
 check(root.get_visible_rect().encloses(panel.draft.get_global_rect()), "Draft cards fit viewport")
 var selector: OptionButton = game.debug_panel.challenge_panel.mode_selector
 var click := InputEventMouseButton.new()
 click.position = selector.get_global_rect().get_center()
 click.button_index = MOUSE_BUTTON_LEFT
 click.pressed = true
 Input.parse_input_event(click)
 click = click.duplicate()
 click.pressed = false
 Input.parse_input_event(click)
 await frames(2)
 check(not selector.get_popup().visible, "Draft blocks pointer access to underlying mode controls")
 var focus := InputEventAction.new()
 focus.action = "ui_focus_next"
 focus.pressed = true
 Input.parse_input_event(focus)
 focus = focus.duplicate()
 focus.pressed = false
 Input.parse_input_event(focus)
 await frames(2)
 check(root.gui_get_focus_owner() in [panel.cards.ice.button, panel.cards.spring.button, panel.cards.magnet.button], "Keyboard focus stays inside draft")
 check(not panel.cards.ice.button.disabled and panel.cards.ice.stats.text.contains("220.0 → 330.0"), "First Ice preview shows effective steering increase")
 await capture("first-draft")
 panel.choose("ice")
 await frames(3)
 check(game.zone.active_act == 1 and not panel.modal.visible and not paused, "Choice resumes next Act with modal removed")
 game.zone.active_act = 2
 game.zone.completed_acts = 3
 game.zone.acquired.assign(["ice", "ice"])
 game.zone.act_score = game.zone.targets[2]
 game.score = game.zone.targets[0] + game.zone.targets[1] + game.zone.targets[2]
 game.zone.exit_unlocked = true
 game.tuning.equip_build(game.zone.acquired)
 game.zone.state = ZoneRun.State.DRAFT
 paused = true
 game.zone.changed.emit()
 await frames(3)
 check(panel.cards.ice.button.disabled and not panel.cards.magnet.button.disabled, "Duplicate limit disables only full species")
 check(panel.draft_heading.text.contains("FINAL CHAO"), "Final reward identified")
 await capture("final-draft")
 panel.choose("magnet")
 await frames(3)
 check(panel.completion.visible and not panel.draft.visible and paused, "Final pick reveals mandatory completion summary")
 check(panel.result_label.text.contains("Ice ×2") and panel.result_label.text.contains("Magnet ×1"), "Completion includes final build")
 await capture("complete")
 panel.replay_button.pressed.emit()
 await frames(8)
 check(game.zone.active_act == 0 and game.zone.acquired.is_empty() and not panel.modal.visible, "Replay clears draft and build")
 check(game.request_generation(18, -1, -1, {"zone": false, "enabled": false}), "Can exit Zone into Free Play")
 await frames(8)
 check(not panel.visible and not panel.modal.visible, "Free Play hides all Zone UI")
 print("RESULT | ", checks, " checks | ", failures, " failures")
 game.free()
 quit(failures)
