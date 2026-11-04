extends ScrollContainer
## Editor-only UI. Checklist state never enters the Act document or validation.
signal difficulty_changed(value: int)
signal thesis_changed(value: String)
signal thesis_edit_started
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Review = preload("res://scripts/act_editor/act_review.gd")
const DIFFICULTY_HELP := [
 "Very forgiving: broad useful shots, strong recovery and low drain pressure.",
 "Some danger exists, but mistakes commonly return to useful play.",
 "Normal SSR expectation: meaningful misses and drain risk, deliberate shots, broadly approachable.",
 "Precision and routing matter substantially. Bad shots regularly threaten the Ball; important routes require control.",
 "Intentionally demanding: mastery of the table, Ball control and character mechanics is expected.",
]
const CHECKLIST := {
 "Identity": [
  "I can describe this Act in one sentence.",
  "The terrain silhouette is recognizable without gameplay objects.",
  "This Act contributes something meaningfully different from the other production Acts."],
 "Routes": [
  "There is at least one safe/repeatable scoring route.",
  "There is at least one deliberate risk/reward route.",
  "Important shots can be deliberately attacked from the main flippers.",
  "Missed shots usually lead somewhere understandable."],
 "Objects": [
  "Bumpers have intentional routing/scoring roles rather than filling empty space.",
  "Springs redirect toward useful areas.",
  "Slingshot orientation clearly communicates its rebound direction.",
  "Buzz Bombers occupy meaningful attack positions.",
  "Rings teach/reward routes rather than merely fill empty space."],
 "Featured mechanics": [
  "Roughly 2–3 featured mechanic families define the Act.",
  "Featured mechanics meaningfully interact with terrain/routing.",
  "Their state changes are visually understandable where applicable."],
 "Goal": [
  "Reaching the score target does not turn into waiting for random physics.",
  "The Goal has at least one readable/repeatable attack angle."],
 "Feel": [
  "The Act avoids long purposeless Ball travel.",
  "Most table regions contain either a meaningful interaction or a meaningful trajectory.",
  "I would want to replay this Act for a better score."],
}
var difficulty: OptionButton
var thesis: LineEdit
var difficulty_help: Label
var foundation: Label
var featured: Label
var hints: Label
var shot_scale: Label
var checkboxes: Array[CheckBox] = []
var _fingerprint := ""
var facts := {}

func _init() -> void:
 name = "Act Review"
 horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 var stack := VBoxContainer.new()
 stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 stack.add_theme_constant_override("separation", 8)
 add_child(stack)
 _label(stack, "ACT REVIEW")
 _label(stack, "Facts inform review. You judge design. Nothing here gates Save, Bake or Play.")
 _label(stack, "Difficulty · authored")
 difficulty = OptionButton.new()
 for i in Document.DIFFICULTY_LABELS.size(): difficulty.add_item("%d · %s" % [i + 1, Document.DIFFICULTY_LABELS[i]], i + 1)
 difficulty.item_selected.connect(func(index: int): difficulty_changed.emit(index + 1))
 stack.add_child(difficulty)
 difficulty_help = _label(stack, "")
 _label(stack, "Design Thesis · optional, 240 characters")
 thesis = LineEdit.new()
 thesis.max_length = Document.MAX_DESIGN_THESIS_LENGTH
 thesis.placeholder_text = "What is this Act trying to be?"
 thesis.focus_entered.connect(func(): thesis_edit_started.emit())
 thesis.text_changed.connect(func(value: String): thesis_changed.emit(value))
 stack.add_child(thesis)
 foundation = _label(_section(stack, "AUTOMATIC · Foundation", true), "")
 foundation.tooltip_text = "Counts include all authored flippers. The Act format does not mark which flippers are main. Rings include generated patterns and elevated rail rings."
 featured = _label(stack, "")
 hints = _label(_section(stack, "REVIEW HINTS", true), "")
 hints.add_theme_color_override("font_color", Color("ffd38b"))
 shot_scale = _label(_section(stack, "SHOT SCALE"), "")
 _label(stack, "DESIGN REVIEW · human judgment")
 _label(stack, "Session only. Checks clear after any document edit, Undo/Redo, New or Load.")
 for heading: String in CHECKLIST:
  var section := _section(stack, heading)
  for prompt: String in CHECKLIST[heading]:
   var row := HBoxContainer.new()
   section.add_child(row)
   var check := CheckBox.new()
   check.tooltip_text = prompt
   check.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
   row.add_child(check)
   var label := _label(row, prompt)
   label.mouse_filter = Control.MOUSE_FILTER_STOP
   label.gui_input.connect(func(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
     check.button_pressed = not check.button_pressed
     label.accept_event())
   checkboxes.append(check)
 _label(stack, "PLAYTEST EVIDENCE")
 _label(stack, "Prototype telemetry records authored difficulty and Act fingerprint. Playtest comparisons are a future review aid.")

func _label(parent: Node, value: String) -> Label:
 var label := Label.new()
 label.text = value
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 parent.add_child(label)
 return label

func _section(parent: Node, title: String, expanded := false) -> VBoxContainer:
 var toggle := Button.new()
 toggle.text = ("▾ " if expanded else "▸ ") + title
 toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
 toggle.toggle_mode = true
 toggle.button_pressed = expanded
 parent.add_child(toggle)
 var content := VBoxContainer.new()
 content.visible = expanded
 parent.add_child(content)
 toggle.toggled.connect(func(value: bool):
  content.visible = value
  toggle.text = ("▾ " if value else "▸ ") + title)
 return content

func reset_checklist() -> void:
 for check: CheckBox in checkboxes: check.set_pressed_no_signal(false)

func refresh(document: Resource, editing_enabled: bool) -> void:
 difficulty.disabled = not editing_enabled
 thesis.editable = editing_enabled
 difficulty.select(document.authored_difficulty - 1)
 difficulty_help.text = DIFFICULTY_HELP[document.authored_difficulty - 1]
 if thesis.text != document.design_thesis: thesis.text = document.design_thesis
 thesis.tooltip_text = document.design_thesis
 var fingerprint: String = document.fingerprint()
 if fingerprint == _fingerprint: return
 _fingerprint = fingerprint
 reset_checklist()
 facts = Review.summarize(document)
 var count: Dictionary = facts.counts
 foundation.text = "Flippers (all): %d L / %d R\nSlingshots: %d · Springs: %d\nRings: %d (%d pattern + %d rail)\nBuzz Bombers: %d\nBumpers: %d round / %d triangle\nGoal: %s\nSpawn: %s" % [count.left_flipper, count.right_flipper, count.slingshot, count.spring, facts.rings, facts.pattern_rings, facts.rail_rings, count.buzz_bomber, count.round_bumper, count.triangle_bumper, facts.goal, "Authored" if facts.spawn else "Unset"]
 featured.text = "FEATURED · %d\n%s" % [facts.families.size(), " · ".join(facts.families) if not facts.families.is_empty() else "None authored"]
 hints.text = "No hints from the current checks. This does not establish design quality." if facts.hints.is_empty() else "• " + "\n\n• ".join(facts.hints)
 var scales := PackedStringArray(["Base Ball diameter: %.1f px" % facts.ball_diameter,
  Review.scale_text("Goal diameter", PackedFloat64Array([facts.goal_diameter]), facts.ball_diameter)])
 if not facts.gate_widths.is_empty(): scales.append(Review.scale_text("Gate span", facts.gate_widths, facts.ball_diameter))
 if not facts.target_spacings.is_empty(): scales.append(Review.scale_text("Drop Target center spacing", facts.target_spacings, facts.ball_diameter))
 scales.append("Ranges cover all authored instances. Base Ball uses shared Act proportions; character/session modifiers may differ. Gate span is not a free opening.")
 shot_scale.text = "\n".join(scales)
