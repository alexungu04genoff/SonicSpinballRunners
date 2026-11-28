extends SceneTree
## Exercise the production HUD through shared streaming without constructing a level.
class Fixture extends "res://scripts/prototype/zone_run.gd":
 var breakdown_calls := 0
 func _ready() -> void: add_child(terrain_shadows)
 func _physics_process(_delta: float) -> void: pass
 func _prefetch_next_theme() -> void: pass
 func _update_backgrounds() -> void: pass
 func _retire_behind() -> void: pass
 func progress_text() -> String: return "ACT TEST"
 func act_title(_act: RefCounted) -> String: return "HUD fixture"
 func scoring_breakdown_text() -> String:
  breakdown_calls += 1
  return super.scoring_breakdown_text()

class GoalOverlay extends "res://scripts/prototype/score_overlay.gd":
 var pointer := Vector2.ZERO
 var caption := ""
 func _draw_goal_pointer(direction: Vector2) -> void: pointer = direction
 func _text(value: String, _at: Vector2, _font_size: int, _tint: Color) -> void: caption = value

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
 game.scorecraft = Scorecraft.new()
 game.specials = CharacterSpecials.new()
 game.ball = PlaygroundBall.new()
 game._build_hud()
 game.library = game.Library.new()
 game.add_child(game.library)
 game.library_ready = true
 game.started = true
 game.active_sequence = 0
 game.run_plan.assign([{}, {}, {}])
 game.act_score_target = 1000
 game.exit_unlocked = false
 game.diagnostics.text = "hidden"
 game._process(0.01)
 check(game.heading.text == "000" and game.player_hud.lives.text == "× 3" and game.detail.text.contains("ACT 1 / 3"), "Shared processing dispatches the icon HUD without needing Endless title data")
 check(game.diagnostics.text == "hidden" and game.breakdown_calls == 0, "Hidden diagnostics do no formatting work")
 var original := game.detail.text
 game._process(0.01)
 check(game.detail.text == original, "Unchanged game state preserves the HUD")
 game.act_score = 150
 game.score = 250
 game.special_meter = 99.9
 game._process(0.01)
 check(game.player_hud.score.text == "250" and game.detail.text.contains("150 / 1000") and is_equal_approx(game.player_hud.charge, 0.999), "Run score, Act score and gauge changes appear in the same update")
 game.score = 260
 game._process(0.01)
 check(game.player_hud.score.text == "260", "A run score change alone refreshes the counter")
 game.special_meter = 100.0
 game.balls_remaining = 2
 game._process(0.01)
 check("SPACE / A" in game.player_hud.ready_label.text and game.player_hud.lives.text == "× 2", "Full Special shows the input prompt alongside remaining Balls")
 check(is_equal_approx(game.player_hud.target_progress, 0.15), "The target bar shows Act points independently of run score")
 game.character_id = "tails"
 game._process(0.01)
 check(game.player_hud.special_name.text == "FLIGHT", "Changing character alone updates the Special label")
 game.practice_mode = true
 game.exit_unlocked = true
 game._process(0.01)
 check(game.player_hud.lives.text.contains("∞") and game.detail.text.contains("GOAL READY"), "Practice and Goal readiness invalidate cached text")
 check(game.player_hud.target_progress == 1.0, "An unlocked goal fills the Act target bar")
 game.buddies.choose("chip")
 game._process(0.01)
 check(not game.detail.text.contains("rescue ready"), "Buddy details stay out of the compact HUD")
 game.buddies.rescue()
 game._process(0.01)
 check(not game.detail.text.contains("rescue used"), "Rescue details remain in the Buddy and Results screens")
 game.scorecraft.combo_feedback = "COMBO ×2"
 game.scorecraft.combo_feedback_remaining = 1.0
 game._process(0.01)
 check(not game.detail.text.contains("COMBO ×2"), "The on-ball combo display owns temporary combo feedback")
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
 check_goal_pointer(game)
 game.specials.free()
 game.scorecraft.free()
 game.ball.free()
 game.free()
 print("HUD_UPDATE_REGRESSION | ", checks, " checks | ", failures, " failures")
 quit(1 if failures else 0)

func check_goal_pointer(game: Fixture) -> void:
 game.view = SubViewport.new()
 game.view.size = Vector2i(640, 450)
 game.add_child(game.view)
 game.presentation = TablePresentation.new()
 game.view.add_child(game.presentation)
 game.presentation.camera = Camera3D.new()
 game.presentation.add_child(game.presentation.camera)
 var spy := GoalOverlay.new()
 spy.game = game
 game.hud.add_child(spy)
 var goal := preload("res://scripts/prototype/goal_ring.gd").new()
 game.presentation.add_child(goal)
 for projection: int in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
  game.presentation.camera.projection = projection
  goal.center = Vector2(5000, -200)
  goal.position = TablePresentation.map_point(goal.center)
  goal.set_unlocked(false)
  spy.pointer = Vector2.ZERO
  spy.caption = ""
  spy._draw_goal(goal)
  check(spy.pointer == Vector2.ZERO and spy.caption.is_empty(), "Locked offscreen Goal stays quiet")
  goal.set_unlocked(true)
  spy._draw_goal(goal)
  check(spy.pointer.is_equal_approx(Vector2.RIGHT), "Unlocked offscreen Goal points toward its camera edge")
  goal.center = Vector2(-5000, 200)
  goal.position = TablePresentation.map_point(goal.center)
  spy._draw_goal(goal)
  check(spy.pointer.is_equal_approx(Vector2.LEFT), "A Goal behind the camera keeps its left/right bearing")
  goal.center = Vector2(0, -200)
  goal.position = TablePresentation.map_point(goal.center)
  spy.pointer = Vector2.ZERO
  spy._draw_goal(goal)
  check(spy.pointer == Vector2.ZERO and spy.caption == "GOAL", "The in-view Goal owns its label when it returns")
