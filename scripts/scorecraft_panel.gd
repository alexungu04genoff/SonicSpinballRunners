class_name ScorecraftPanel
extends VBoxContainer
## Compact shared HUD; baseline comparison always starts a fresh Act run.
var game: Node
var title: Label
var next_action: Label
var clock_bar: ProgressBar
var award: Label
var toggle: CheckButton

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 add_child(HSeparator.new())
 title = _label(17)
 clock_bar = ProgressBar.new()
 clock_bar.show_percentage = false
 clock_bar.custom_minimum_size.y = 7
 add_child(clock_bar)
 next_action = _label(13)
 award = _label(13)
 toggle = CheckButton.new()
 toggle.text = "Scorecraft combos"
 toggle.add_theme_font_size_override("font_size", 13)
 toggle.tooltip_text = "Compare against baseline scoring. Switch at serve or while paused; restarts this Act and clears score."
 toggle.toggled.connect(func(value: bool):
  game.request_replay({"combos": value})
  toggle.release_focus()
 )
 add_child(toggle)

func _label(size: int) -> Label:
 var label := Label.new()
 label.custom_minimum_size.x = 225
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size", size)
 add_child(label)
 return label

func _process(_delta: float) -> void:
 var combo: Scorecraft = game.scorecraft
 title.text = "COMBO ×%d · %d links" % [combo.multiplier, combo.chain] if combo.chain > 0 else "SCORECRAFT · ×1"
 title.modulate = Color("ffe27a") if combo.multiplier > 1 else Color("b7c6ce")
 if not combo.enabled:
  title.text = "BASELINE SCORING"
  next_action.text = "Combos off · original point values"
 elif combo.chain == 0:
  next_action.text = "Hit a bumper to start · %.1fs window" % combo.config.combo_window
 elif combo.ring_link_available:
  next_action.text = "%.1fs · Rings %d/%d%s" % [combo.remaining, combo.ring_progress, combo.config.rings_per_link, " for ×3" if combo.multiplier == 2 and not combo.has_ring_link else " or a new bumper"]
 else:
  next_action.text = "%.1fs · Find a new bumper" % combo.remaining
 if not combo.protected_rail.is_empty() and combo.rail_protection_remaining > 0.0:
  next_action.text = "Rail protection %.1fs · combo %.1fs" % [combo.rail_protection_remaining, combo.remaining]
 clock_bar.max_value = maxf(0.5, combo.config.combo_window)
 clock_bar.value = combo.remaining
 award.text = "Repeated bumpers: ×1, no refresh"
 if combo.feedback_remaining > 0 and not combo.last_award.is_empty():
  var info: Dictionary = combo.last_award
  if info.special_bonus > 0:
   award.text = "HOMING +%d · %d×%d + %d finish" % [info.total, info.base, info.multiplier, info.special_bonus]
  elif info.kind == "bumper" and combo.enabled and not info.fresh_bumper and String(info.get("ability", "")).is_empty():
   award.text = "Repeat bumper +%d · no refresh" % info.total
  else:
   award.text = game.scoring_feedback_text()
 if combo.support_feedback_remaining > 0.0: award.text = "COMBO EXTENDED"
 toggle.set_pressed_no_signal(combo.enabled)
 toggle.disabled = not game.can_reload_act()
