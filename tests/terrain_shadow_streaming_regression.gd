extends SceneTree
## Follow production Clean 8 through Act retirement and a live Zone crossfade.
const Course = preload("res://scripts/diagnostics/grounding_endless.gd")
const Review = preload("res://scripts/diagnostics/shadow_review.gd")
const TerrainShadows = preload("res://scripts/rendering/terrain_shadows.gd")
var failures := PackedStringArray()

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
 if not ok:
  failures.append(label)
  push_error(label)

func run() -> void:
 Review.position_review_window(root)
 Review.Options.settings_path = "user://terrain-streaming-test.cfg"
 Review.Options.update_quality(Review.profile("quality"),false)
 var game := Course.new()
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 180000
 while not game.started and game.library.error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
 check(game.started,"Endless loads the first disk Act")
 if game.started:
  var policy: Node
  for child in game.get_children():
   if child is TerrainShadows: policy = child
  check(policy != null and policy.bands == null,"Native shadows allocate no receiver overlays")
  game.toggle_tour()
  game.tour_speed = 0.0
  Review.Options.update_quality({"clean_eight_shadows":true},false)
  deadline = Time.get_ticks_msec() + 180000
  while not (game._zone_ready(1) and game.resident.any(func(a): return a.ready and a.plan.sequence == 3)) and Time.get_ticks_msec() < deadline: await process_frame
  var boundary_act: RefCounted
  for act: RefCounted in game.resident:
   if act.plan.sequence == 2: boundary_act = act
  check(boundary_act != null and game._zone_ready(1),"Second Zone prepared")
  if boundary_act and game._zone_ready(1):
   game._activate(boundary_act)
   game.presentation.tour_focus = Vector2(boundary_act.bounds().get_center().x,game.backgrounds[1].entrance_y + 260.0)
   game.tour_speed = 180.0
   var overlap := false
   deadline = Time.get_ticks_msec() + 40000
   while game._background_zone < 1 and Time.get_ticks_msec() < deadline:
    await process_frame
    overlap = overlap or game.background_blend > 0.01
   await RenderingServer.frame_post_draw
   check(overlap and game._background_zone >= 1 and game.library.fallback_builds == 0,"Disk-only crossfade with Clean 8 active")
   check(game.retro_filter.selected_effects == game.retro_filter.settings.default_effects and not game.retro_filter.selected_effects.is_empty(),"Full Retro across Zone boundary")
   var ready_ids := game.resident.filter(func(a): return a.ready).map(func(a): return a.get_instance_id())
   var owners: Dictionary = policy.bands.owners
   check(owners.size() == ready_ids.size() and owners.keys().all(func(id): return id in ready_ids),"Clean 8 follows ready resident Acts and retires old owners")
   check(policy.bands.stats().receivers > 0,"New Zone has eligible Clean 8 receivers")
   Review.Options.update_quality({"clean_eight_shadows":false},false)
   await RenderingServer.frame_post_draw
   check(policy.bands.stats().receivers == 0,"Native restore removes streamed overlays")
   for owner: Dictionary in owners.values():
    for slot: Dictionary in owner.slots:
     var node: GeometryInstance3D = slot.node.get_ref()
     if node: check(node.material_overlay == null,"Resident material overlay restored")
 await game.prepare_to_close()
 game.free()
 print("TERRAIN_ENDLESS | failures=",failures)
 quit(0 if failures.is_empty() else 1)
