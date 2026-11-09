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
 check(game.playfield.source == "authored", "Existing sandbox still loads with deck clearance checks", game.last_source_error)
 if game.playfield.source != "authored": game.queue_free(); quit(1); return
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
  var border_materials := true
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
    border_uvs = border_uvs and high - low > 1.0
    var material: Material = child.material_override
    if theme == "ice_cap":
     # The approved Ice guards use plain matte snow, while retaining the same route chart.
     border_materials = border_materials and material is StandardMaterial3D and material.get_meta("ice_cap_snow_railguard", false)
     if material is StandardMaterial3D:
      border_materials = border_materials and material.albedo_texture == null
    else:
     border_materials = border_materials and material is ShaderMaterial
  check(counts.get("Deck", 0) == 1 and counts.get("EdgeCap", 0) == 2 and counts.get("Fascia", 0) == 2 and counts.get("InnerEdge", 0) == 2 and counts.get("Underside", 0) == 1, "Both ramp ledges, both fascia faces and underside exist: " + theme)
  check(border_uvs, "Both ramp border charts span width and follow route distance: " + theme)
  check(border_materials, "Ramp guards retain the approved plain-snow or textured material: " + theme)
  var definition: RefCounted = game.presentation.theme_definition
  check(definition.floor_border_material != null and definition.top_border_material != null and definition.floor_border_width > 0 and definition.top_border_width > 0, "Floor and wall ledge borders are enabled: " + theme)
  check(not game.presentation.terrain_root.find_children("TopSurfaceBorder", "MeshInstance3D", true, false).is_empty() and not game.presentation.terrain_root.find_children("FloorPathBorder", "MeshInstance3D", true, false).is_empty(), "Authored walls and floor contain rendered border meshes: " + theme)
  if theme == "chemical_plant":
   var source: ShaderMaterial = definition.ramp_materials().deck
   var material: ShaderMaterial = deck.material_override
   check(definition.theme_id == "chemical_plant" and material != source and material.shader == source.shader and material.get_meta("atmosphere_hue", "") == "ramps", "Chemical ramp owns a separate material using the current theme shader and ramp atmosphere category")
   var actual_texture: Texture2D = material.get_shader_parameter("albedo_texture")
   var source_texture: Texture2D = source.get_shader_parameter("albedo_texture")
   check(actual_texture != null and actual_texture == source_texture, "Chemical ramp retains the authoritative theme deck texture")
   # Selected art is read as an ImageTexture in editor builds, with no resource path.
   # Compare decoded pixels with the intentional source, not an old texture name/hash.
   var selected := "res://assets/textures/chemical_plant/selected/7C-yellow.png"
   var source_path: String = selected if FileAccess.file_exists(selected) else "res://assets/textures/chemical_plant/ramp.png"
   var expected := Image.load_from_file(ProjectSettings.globalize_path(source_path))
   var actual := actual_texture.get_image()
   actual.convert(Image.FORMAT_RGBA8)
   expected.convert(Image.FORMAT_RGBA8)
   actual.clear_mipmaps()
   expected.clear_mipmaps()
   check(actual.get_size() == expected.get_size() and actual.get_data() == expected.get_data(), "Chemical ramp texture matches current selected artwork (or the shipped base artwork when no selection exists)")
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
