extends SceneTree
const Run = preload("res://scripts/endless/endless_game.gd")
const Act = preload("res://scripts/endless/streamed_act.gd")
var checks := 0
var failures := 0

class ProbeLibrary extends Node:
 var busy := false
 var available := false
 var can_trim := true
 var themes := {"green_hill":true}
 var protected: Array = []
 var reserve := Vector2i.ZERO
 var requests: Array = []
 func has_variant(_theme: String, _id: int) -> bool: return available
 func trim(entries: Array, variants: int, theme_count: int) -> bool:
  protected = entries.duplicate()
  reserve = Vector2i(variants,theme_count)
  return can_trim
 func request(theme: String, id: int) -> void: requests.append([theme,id])

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error("FAIL | " + label)

func run() -> void:
 var game := Run.new()
 var library := ProbeLibrary.new()
 game.library = library
 var act := Act.new()
 act.plan = {"theme":"green_hill","id":2,"sequence":1}
 act.phase = 2
 act._finish_phase = 1
 game.building = act
 game.pending.assign([{"theme":"green_hill","id":3,"sequence":2}])
 var resident := Act.new()
 resident.plan = {"theme":"green_hill","id":1,"sequence":0}
 game.resident.append(resident)
 game.backgrounds[0] = {"theme":"green_hill"}
 game._background_zone = 0
 game._prefetch_pending_variant()
 check(library.requests.is_empty(),"Startup keeps its original two-Act preparation limit")
 game.started = true
 for phase in [0,1,3,4]:
  act.phase = phase
  game._prefetch_pending_variant()
  check(library.requests.is_empty(),"No overlap outside material attachment: %d" % phase)
 act.phase = 2
 for stage in [0,3]:
  act._finish_phase = stage
  game._prefetch_pending_variant()
  check(library.requests.is_empty(),"No overlap during animation binding or bounds: %d" % stage)
 act._finish_phase = 1
 for control in ["_whole_material_attachment","_atomic_attachment"]:
  act.set(control,true)
  game._prefetch_pending_variant()
  check(library.requests.is_empty(),"Diagnostic control keeps the original request order: " + control)
  act.set(control,false)
 game.pending[0].sequence = 6
 game._prefetch_pending_variant()
 check(library.requests.is_empty(),"Lookahead cannot extend beyond the existing five-Act window")
 game.pending[0].sequence = 2
 library.busy = true
 game._prefetch_pending_variant()
 check(library.requests.is_empty() and library.protected.is_empty(),"Busy worker cannot start another request or evict its inputs")
 library.busy = false
 library.available = true
 game._prefetch_pending_variant()
 check(library.requests.is_empty(),"A cached pending variant needs no new preparation")
 library.available = false
 library.can_trim = false
 game._prefetch_pending_variant()
 check(library.requests.is_empty(),"Cache pressure defers preparation until reservation succeeds")
 library.can_trim = true
 game._prefetch_pending_variant()
 check(library.requests == [["green_hill",3]] and game.pending.size() == 1,"Only the immediate pending variant starts; normal activation keeps ownership of the queue")
 check(act.plan in library.protected and resident.plan in library.protected and game.pending[0] in library.protected,"In-progress, resident and requested Act resources all stay pinned")
 check(library.reserve == Vector2i(1,0),"Existing theme reserves one bounded variant slot")
 game.pending[0].theme = "rooftop_run"
 game._prefetch_pending_variant()
 check(library.reserve == Vector2i(1,1),"New theme must reserve both bounded cache slots")
 game.building = null
 game.resident.clear()
 act.root.free()
 act.visual.free()
 resident.root.free()
 resident.visual.free()
 library.free()
 game.free()
 print("MATERIAL_PREFETCH_REGRESSION | checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
