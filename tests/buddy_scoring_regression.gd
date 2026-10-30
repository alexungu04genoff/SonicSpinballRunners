extends SceneTree
const Buddies = preload("res://scripts/prototype/buddies.gd")
var failures := 0
var checks := 0
var virtual_rings := 0

func check(value: bool, label: String) -> void:
 checks += 1
 if value: print("PASS | ", label)
 else: failures += 1; push_error("FAIL | " + label)

func _initialize() -> void:
 var build := Buddies.new()
 var same := Buddies.new()
 build.run_seed = 487
 same.run_seed = 487
 for draft in 8:
  var offers := build.offers()
  check(offers == same.offers() and offers == build.offers(), "Seeded draft %d is reproducible and cannot reroll on refresh" % draft)
  var ids: Array = offers.map(func(offer): return offer.id)
  var unique := {}
  for id: String in ids: unique[id] = true
  check(ids.size() <= 3 and ids.size() == unique.size(), "Draft has at most three distinct cards")
  if offers.is_empty(): break
  var selected: String = offers[0].id
  check(build.choose(selected) and same.choose(selected), "Offered acquisition advances matching draft state")
 var fresh := Buddies.new()
 check(fresh.offers().size() == 3 and not fresh.choose("unknown"), "Fresh run offers exactly three valid entries")
 check(Buddies.CATALOG.size() == 11 and not Buddies.CATALOG.has("ring_scout"), "Only the eleven Adventure Buddies form the gameplay catalogue")
 for id: String in Buddies.CATALOG:
  var definition := Buddies.Catalog.definition(id)
  check(definition.source_game == "Sonic Runners Adventure" and load(definition.art_path) is Texture2D and not definition.source_art_url.is_empty(), "Local Adventure art and source metadata: " + id)
 build = Buddies.new()
 for id: String in ["hero_chaos", "dark_chaos", "knuckles_omochao"]: build.choose(id)
 var scoring := Scorecraft.new()
 scoring.config = ScorecraftConfig.new()
 var bumper := Node.new()
 scoring.award_bonuses = build.modifiers()
 scoring.chain = 2
 scoring.multiplier = 2
 scoring.has_ring_link = true
 check(scoring.award_bumper(bumper) == 405 and scoring.last_award.normal_total == 300, "300 normal + 6 Hero + 24 Dark + 75 Knuckles = 405")
 check(scoring.last_award.buddy_bonuses == {"hero_chaos": 6, "dark_chaos": 24, "knuckles_omochao": 75}, "Every percentage contribution is independently attributable")
 build.record_score(scoring.last_award)
 check(scoring.last_award.total == scoring.last_award.normal_total + Buddies.total(build.contributions), "Results reconcile normal and Buddy totals")
 check(scoring._award("switch_bank", 2000000, 1, 0, false) == 2200000, "Percentage rewards remain exact for large normal awards")
 check(build.choose("dark_chaos") and not build.choose("dark_chaos"), "Duplicate upgrades stop at max level")
 check(build.begin_act(3, false, 0) == 2 and build.begin_act(1, false, 1) == 1 and build.begin_act(3, true, 1) == 3, "Dark Chaos level two still costs only one starting Ball; minimum and Practice work")
 check(build.contributions.size() == 3 and build.act_contributions.is_empty(), "Act changes preserve run contributions and reset the Act ledger")
 build = Buddies.new()
 build.choose("wizard_chao")
 scoring.award_bonuses = build.modifiers()
 for kind: String in ["ring_rack", "switch_bank", "spinner_goal", "lane_set"]:
  check(scoring.award_mechanic(kind, "feature", 300) == 375, "Wizard applies only to typed completion: " + kind)
 for kind: String in ["spinner_tick", "switch", "gate", "ring", "enemy"]:
  check(scoring.award_mechanic(kind, "ordinary", 20) == 20, "Wizard excludes ordinary event: " + kind)
 check(scoring.award_mechanic(&"ring_rack", "silent", 0) == 0, "A zero-point source cannot manufacture a Buddy award")
 build.choose("dark_chao")
 build.virtual_rings_awarded.connect(func(amount, _id): virtual_rings += amount)
 scoring.award_bonuses = build.modifiers()
 var chain := scoring.chain
 var remaining := scoring.remaining
 check(scoring.award_mechanic(&"enemy", "badnik", 100) == 125 and scoring.chain == chain and scoring.remaining == remaining, "Dark Chao enemy score is fixed; no combo advancement or refresh")
 build.enemy_destroyed(&"future_badnik", "enemy_id", &"ability")
 check(virtual_rings == 1, "Dark Chao reacts to generic enemy types and sources")
 build.choose("dark_chao")
 scoring.award_bonuses = build.modifiers()
 check(scoring.award_mechanic(&"enemy", "badnik2", 100) == 150, "Dark Chao level two grants +50% enemy score")
 build.enemy_destroyed(&"buzz_bomber", "enemy2", &"contact")
 check(virtual_rings == 3, "Dark Chao level two grants two virtual Rings")
 build.choose("rc_ufo")
 for i in 3: build.physical_ring_collected()
 build.begin_act(3, false, 1)
 build.physical_ring_collected()
 check(virtual_rings == 4 and build.cadence.rc_ufo == 0, "RC UFO carries physical progress across Acts; virtual awards cannot recurse")
 build.choose("rc_ufo")
 for i in 4: build.physical_ring_collected()
 check(virtual_rings == 6 and build.run_counters.physical_rings == 8, "RC UFO upgrade awards two virtual Rings per four real pickups")
 build = Buddies.new()
 for id: String in ["chip", "sonic_omochao", "tails_omochao", "yacker", "hero_chaos"]: build.choose(id)
 check(build.persistent_slots() == 5 and not build.choose("dark_chao") and build.choose("yacker"), "Five unique persistent slots: upgrades use no extra slot")
 check(build.choose("rc_tornado") and build.persistent_slots() == 5 and not build.choose("rc_tornado"), "RC Tornado is a one-shot acquisition with no slot or upgrade")
 check(build.begin_act(3, false, 0) == 4 and build.begin_act(3, false, 0) == 3, "RC Tornado adds exactly one Ball to the upcoming Act only")
 check(build.rescue() and not build.rescue(), "Chip rescues only once")
 build.begin_act(3, false, 1)
 check(not build.rescue() and build.summary().contains("rescue used"), "Chip stays consumed across Act and Zone boundaries")
 var tuning := PhysicsTuning.new()
 tuning.set_temporary("run_buddies", build.physics_modifier())
 check(is_equal_approx(tuning.effective.rolling_acceleration, tuning.base.rolling_acceleration * 1.10) and is_equal_approx(tuning.effective.gravity_scale, tuning.base.gravity_scale * 0.92) and is_equal_approx(tuning.effective.ring_magnet_radius, tuning.base.ring_magnet_radius * 1.50), "Speed, Float and Magnet use centralized PhysicsModifier resolution")
 build.choose("sonic_omochao")
 build.choose("tails_omochao")
 tuning.set_temporary("run_buddies", build.physics_modifier())
 check(is_equal_approx(tuning.effective.rolling_acceleration, tuning.base.rolling_acceleration * 1.20) and is_equal_approx(tuning.effective.max_downward_speed, tuning.base.max_downward_speed * 1.04 * 0.88), "Level two replaces the earlier physics contribution")
 tuning.clear_temporary("run_buddies")
 check(tuning.effective == tuning.base.as_values(), "Clearing the run modifier restores baseline physics")
 build.choose("hero_chaos")
 check(build.offers().is_empty(), "Maxed persistent slots and consumed rewards leave no invalid offers")
 var last := Buddies.new()
 for id: String in ["chip", "sonic_omochao", "tails_omochao", "yacker", "hero_chaos"]:
  last.choose(id)
  if id != "chip": last.choose(id)
 check(last.offers().size() == 1 and last.offers()[0].id == "rc_tornado", "Fewer than three valid entries shows every valid entry")
 tuning.free()
 scoring.free()
 bumper.free()
 print("RESULT | Adventure Buddies | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
