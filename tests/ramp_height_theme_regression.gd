extends "res://tests/pinball_mechanics_regression.gd"
const Compiler = preload("res://scripts/authored_act/act_runtime_compiler.gd")
const Themes = preload("res://scripts/themes/theme_registry.gd")

func straight_document(height: float, crossing := false) -> Resource:
 var act := ActData.new()
 act.grid_size = Vector2i(12, 12)
 act.cell_size = 50.0
 act.spawn_position = Vector2(250, 550)
 act.gameplay_objects = [object("elevated_rail", Vector2(250, 500), {
  "height": height, "points": PackedVector2Array([Vector2.ZERO, Vector2(0, -400)])})]
 if crossing:
  act.placements = [{"shape_id": "wall_1x2", "base_size": Vector2i(1, 2), "anchor": Vector2i(4, 5), "quarter_turns": 1, "flip_h": false, "flip_v": false}]
 return act

func compile_check(act: Resource, accepted: bool, label: String) -> void:
 var result := Compiler.compile(act, game.tuning, game.controls, game.ball)
 check(result.error.is_empty() == accepted, label, result.error)
 if is_instance_valid(result.root): result.root.free()

func run() -> void:
 root.gui_embed_subwindows = true
 root.size = Vector2i(1280, 900)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
 var act := fixture()
 var path := "res://test-results/ramp-theme.tres"
 act.save_document(path)
 game = ObservedGame.new()
 game.authored_act_path = path
 root.add_child(game)
 await frames(6)
 check(game.level_source == "authored", "Existing sandbox still loads with deck clearance checks", game.last_source_error)
 if game.level_source != "authored": game.queue_free(); quit(1); return
 check(Objects.make_placement("elevated_rail").properties.height == 40.0, "New rails default to a gentler 40-pixel peak")
 for height in [20.0, 30.0, 40.0]:
  var low := straight_document(height)
  check(low.validation_errors().is_empty(), "Height %s remains valid authored data" % height)
  compile_check(low, true, "Height %s works above clear table space" % height)
  low.save_document("res://test-results/low-ramp.tres")
  var restored := ActData.load_document("res://test-results/low-ramp.tres")
  check(restored.document != null and restored.document.gameplay_objects[0].properties.height == height, "Height %s survives Save and Load exactly" % height)
  compile_check(straight_document(height, true), height == 40.0, "Height %s respects the actual 32.5-pixel terrain plus deck and air gap" % height)
 var bumper := straight_document(20.0)
 bumper.gameplay_objects.append(object("round_bumper", Vector2(250, 300)))
 compile_check(bumper, true, "20-pixel rail clears a small authored bumper")
 bumper.gameplay_objects[0].properties.height = 10.0
 compile_check(bumper, false, "Low rail cannot visually cut through a bumper")
 # Pause and rebuild only visuals; the existing ball and path remain authoritative.
 await process_frame
 paused = true
 game.presentation.set_camera_follow(false)
 game.retro_filter.set_preset(0)
 var identity: int = game.ball.get_instance_id()
 var manager: Node = game.ball.mechanics
 var stored_path: Dictionary = manager.items[2].path.duplicate(true)
 for theme: String in Themes.IDS:
  check(game.set_theme(theme), "Ramp selects theme " + theme)
  var visual: Node = game.presentation.get_node("AuthoredPinballVisuals/ElevatedRail_sandbox_elevated_rail")
  var deck: MeshInstance3D = visual.get_node("Deck")
  check(deck.material_override != null and visual.has_node("Fascia") and visual.has_node("EntryArrow"), "Ramp has themed deck, edge thickness and restrained entry marker: " + theme)
  check(game.ball.get_instance_id() == identity and game.ball.mechanics == manager and manager.items[2].path == stored_path, "Theme switch preserves ball, mechanics and exact rail route: " + theme)
  check(visual.find_children("*", "CollisionObject3D", true, false).is_empty(), "Ramp theme remains collisionless: " + theme)
  check(visual.has_node("SidePipes") == (theme == "chemical_plant"), "Side pipes belong only to Chemical Plant: " + theme)
  var counts := {}
  var border_uvs := true
  for child: Node in visual.get_children():
   if not child.has_meta("rail_surface"): continue
   var role: String = child.get_meta("rail_surface")
   counts[role] = counts.get(role, 0) + 1
   if role == "EdgeCap":
    var uv: PackedVector2Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
    var low := INF
    var high := -INF
    for point: Vector2 in uv:
     low = minf(low, point.x)
     high = maxf(high, point.x)
     border_uvs = border_uvs and point.is_finite() and point.y in [0.0, 1.0]
    border_uvs = border_uvs and high - low > 1.0 and child.material_override is ShaderMaterial
  check(counts.get("Deck", 0) == 1 and counts.get("EdgeCap", 0) == 2 and counts.get("Fascia", 0) == 2 and counts.get("InnerEdge", 0) == 2 and counts.get("Underside", 0) == 1, "Both ramp ledges, both fascia faces and underside exist: " + theme)
  check(border_uvs, "Both textured ramp borders span width and follow route distance: " + theme)
  var definition: RefCounted = game.presentation.theme_definition
  check(definition.floor_border_material != null and definition.top_border_material != null and definition.floor_border_width > 0 and definition.top_border_width > 0, "Floor and wall ledge borders are enabled: " + theme)
  check(not game.presentation.terrain_root.find_children("TopSurfaceBorder", "MeshInstance3D", true, false).is_empty() and not game.presentation.terrain_root.find_children("FloorPathBorder", "MeshInstance3D", true, false).is_empty(), "Authored walls and floor contain rendered border meshes: " + theme)
  if theme == "chemical_plant":
   check(deck.material_override is ShaderMaterial and deck.material_override.get_shader_parameter("albedo_texture").resource_path == "res://assets/textures/chemical_plant/ramp.png", "Chemical ramp uses the editable yellow, gray and pale inset panel image")
   var pipes: Node = visual.get_node("SidePipes")
   check(pipes.get_child_count() == 8 and pipes.has_node("BluePipeLeft") and pipes.has_node("BluePipeRight") and pipes.has_node("CouplingsLeft"), "Both blue pipes, metal couplings and yellow/cyan details use eight batched meshes")
  if DisplayServer.get_name() != "headless":
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://test-results/ramp-" + theme + ".png")
 if DisplayServer.get_name() != "headless":
  game.set_theme("chemical_plant")
  game.presentation.overview_zoom = 2.2
  game.presentation.overview_focus = Vector2(370, 385)
  game.presentation.reset_camera()
  await process_frame
  await RenderingServer.frame_post_draw
  game.view.get_texture().get_image().save_png("res://test-results/chemical-ramp-pipes.png")
 await process_frame
 paused = false
 game.queue_free()
 await frames(3)
 print("RESULT | Ramp height and themes | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
