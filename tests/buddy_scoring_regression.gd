extends SceneTree
const Buddies = preload("res://scripts/prototype/buddies.gd")
var failures := 0
var checks := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func _initialize() -> void:
 var build := Buddies.new()
 var scoring := Scorecraft.new()
 var bumper := Node.new()
 check(build.offers().size() == 3 and build.modifiers().is_empty(), "Fresh builds have three offers and no passive bonuses")
 check(not build.choose("unknown") and build.choose("ring_scout"), "Only a known Buddy can be acquired")
 scoring.award_bonuses = build.modifiers()
 check(scoring.award_ring() == 35 and scoring.last_award.normal_total == 25 and scoring.last_award.buddy_bonuses.ring_scout == 10, "Ring Scout pays one attributable flat bonus")
 scoring.multiplier = 3
 check(scoring.award_ring() == 85, "Combo multiplication happens before the flat Buddy bonus")
 check(scoring.award_area("ring", "chaos_blast", 2) == 60, "Area collection also pays one flat bonus, without multiplying it")
 check(build.choose("ring_scout") and not build.choose("ring_scout"), "A duplicate upgrades to level two, with a bounded level cap")
 scoring.award_bonuses = build.modifiers()
 scoring.reset("Drain")
 check(scoring.award_ring() == 45 and scoring.chain == 0, "Drains clear the combo but preserve the acquired Buddy")
 build = Buddies.new()
 build.choose("bumper_coach")
 build.choose("feature_fox")
 scoring.award_bonuses = build.modifiers()
 check(scoring.award_bumper(bumper, 5) == 575 and scoring.chain == 0, "Bumper bonus is added once after the existing special award")
 check(scoring.award_mechanic(&"ring_rack", "rack", 500) == 750 and scoring.chain == 0, "Feature bonus stays fixed and does not create a combo")
 check(scoring.award_mechanic(&"spinner_tick", "spinner", 5) == 5, "Spinner ticks do not receive completion bonuses")
 check(scoring.award_mechanic(&"switch_bank", "silent", 0) == 0, "A zero-point source cannot manufacture a Buddy award")
 check(scoring.last_award.total == scoring.last_award.normal_total + Buddies.total(scoring.last_award.buddy_bonuses), "Award attribution reconciles exactly to its total")
 scoring.award_bonuses.clear()
 check(scoring.award_mechanic(&"ring_rack", "rack", 500) == 500, "Removing the run's bonuses restores baseline scoring")
 scoring.free()
 bumper.free()
 print("RESULT | Buddy scoring | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
