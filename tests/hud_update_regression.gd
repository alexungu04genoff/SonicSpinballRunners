extends SceneTree
## Exercise the production HUD through shared streaming without constructing a level.
class Fixture extends "res://scripts/prototype/zone_run.gd":
 var breakdown_calls := 0
 func _ready() -> void: pass
 func _physics_process(_delta: float) -> void: pass
 func _prefetch_next_theme() -> void: pass
 func _update_backgrounds() -> void: pass
 func _retire_behind() -> void: pass
 func progress_text() -> String: return "ACT TEST"
 func act_title(_act: RefCounted) -> String: return "HUD fixture"
 func scoring_breakdown_text() -> String:
  breakdown_calls += 1
  return super.scoring_breakdown_text()

var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func run() -> void:
 var game := Fixture.new()
 root.add_child(game)
 game.set_process(false)
 game._build_hud()
 game.scorecraft = Scorecraft.new()
 game.specials = CharacterSpecials.new()
 game.library = game.Library.new()
 game.add_child(game.library)
 game.library_ready = true
 game.started = true
 game.act_score_target = 1000
 game.exit_unlocked = false
 game.diagnostics.text = "hidden"
 game._process(0.01)
 check(game.heading.text == "ACT TEST\nHUD fixture" and game.detail.text.contains("BALLS   3 / 3"), "Shared processing dispatches the Prototype HUD without needing Endless title data")
 check(game.diagnostics.text == "hidden" and game.breakdown_calls == 0, "Hidden diagnostics do no formatting work")
 var original := game.detail.text
 game._process(0.01)
 check(game.detail.text == original, "Unchanged game state preserves the HUD")
 game.act_score = 150
 game.score = 250
 game.special_meter = 99.9
 game._process(0.01)
 check(game.detail.text.contains("150 / 1000") and game.detail.text.contains("TOTAL   250") and game.detail.text.contains("SPECIAL   99%"), "Score and meter changes appear in the same update")
 game.special_meter = 100.0
 game.balls_remaining = 2
 game._process(0.01)
 check(game.detail.text.contains("SPECIAL   READY") and game.detail.text.contains("BALLS   2 / 3"), "Special readiness and Ball changes invalidate cached text")
 game.practice_mode = true
 game.exit_unlocked = true
 game._process(0.01)
 check(game.detail.text.contains("Unlimited") and game.detail.text.contains("GOAL READY"), "Practice and Goal readiness invalidate cached text")
 game.buddies.choose("chip")
 game._process(0.01)
 check(game.detail.text.contains("rescue ready"), "Acquiring a Buddy updates its summary")
 game.buddies.rescue()
 game._process(0.01)
 check(game.detail.text.contains("rescue used") and not game.detail.text.contains("rescue ready"), "Using a rescue updates the summary without changing Buddy levels")
 game.scorecraft.combo_feedback = "COMBO ×2"
 game.scorecraft.combo_feedback_remaining = 1.0
 game._process(0.01)
 check(game.detail.text.contains("COMBO ×2"), "Temporary combo feedback appears")
 game.scorecraft.combo_feedback_remaining = 0.0
 game._process(0.01)
 check(not game.detail.text.contains("COMBO ×2"), "Expired feedback disappears without a score change")
 game.respawn_time = 0.5
 game._process(0.01)
 check(game.hint.visible and game.hint.text == "BALL LOST · Retrying…", "Drain hint updates independently of cached score text")
 game.respawn_time = -1.0
 game._process(0.01)
 check(not game.hint.visible and game.hint.text.is_empty(), "Resolved drain clears the hint")
 game.diagnostics.show()
 game._process(0.01)
 var diagnostics := game.diagnostics.text
 check(game.breakdown_calls == 1 and diagnostics.contains("Seed 18"), "Opening diagnostics refreshes immediately")
 game.run_seed = 44
 game._process(0.01)
 check(game.breakdown_calls == 1 and game.diagnostics.text == diagnostics, "Visible diagnostics are throttled")
 game._process(0.3)
 check(game.breakdown_calls == 2 and game.diagnostics.text.contains("Seed 44"), "Visible diagnostics refresh after the interval")
 game.diagnostics.hide()
 game._process(0.01)
 game.run_seed = 99
 game.diagnostics.show()
 game._process(0.01)
 check(game.breakdown_calls == 3 and game.diagnostics.text.contains("Seed 99"), "Reopening diagnostics refreshes immediately")
 game.specials.free()
 game.scorecraft.free()
 game.free()
 print("HUD_UPDATE_REGRESSION | ", checks, " checks | ", failures, " failures")
 quit(1 if failures else 0)
