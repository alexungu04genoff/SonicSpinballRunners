extends SceneTree
## Cross-theme composition checks and an optional matched landmark contact sheet.
const Themes = preload("res://scripts/themes/theme_registry.gd")
const Presentation = preload("res://scripts/themes/themed_presentation.gd")
const OUTPUT := "res://test-results/landmark-themes.png"
var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)

func collect_bounds(node: Node3D, boxes: Array[AABB], parent := Transform3D.IDENTITY) -> bool:
 if node is CollisionObject3D or node is CollisionShape3D: return false
 var transform := parent * node.transform
 if not transform.is_finite(): return false
 if node is MeshInstance3D:
  if node.mesh == null: return false
  boxes.append(transform * node.mesh.get_aabb())
 for child: Node in node.get_children():
  if not child is Node3D or not collect_bounds(child, boxes, transform): return false
 return true

func run() -> void:
 var expected := {"green_hill": ["turf_loop", "rope_bridge", "palm_island"], "chemical_plant": ["fluid_reactor", "pipe_arch", "reactor_island"], "rooftop_run": ["clock_tower", "aqueduct", "festival_balloons"], "casino_night": ["jackpot_palace", "star_gateway", "roulette_pavilion"], "sky_sanctuary": ["sanctuary_belfry", "sky_aqueduct", "astral_dais"]}
 expected["ice_cap"] = ["glacier_crown", "frozen_bridge", "aurora_basin"]
 expected["lava_reef"] = ["rift_crown", "mine_viaduct", "caldera_seal"]
 for id: String in Themes.IDS:
  var p := Presentation.new()
  p.set_theme_definition(Themes.create(id))
  var skin: RefCounted = p.decor_skin
  for hint: String in ["surface", "edge", "either"]:
   var slot := {"slot_id": "long-island", "slot_type": "landmark", "placement_hint": hint, "variant_mode": "fixed", "variant_index": 0}
   check(skin.variants_for(slot) == expected[id], id + " retains published fixed indices: " + hint)
   for index in expected[id].size():
    slot.variant_index = index
    var visual: Node3D = skin.instantiate_slot("layout", slot)
    var boxes: Array[AABB] = []
    check(collect_bounds(visual, boxes) and not boxes.is_empty(), id + " landmark is finite and collisionless")
    var bounds := boxes[0]
    for box: AABB in boxes: bounds = bounds.merge(box)
    if index == 2:
     check(bounds.size.x >= 1.55 and bounds.size.x <= 1.70 and bounds.size.z >= 1.55 and bounds.size.z <= 1.70, id + " circular landmark keeps the shared round footprint: " + str(bounds))
    else:
     check(bounds.size.x >= 2.90 and bounds.size.x <= 3.10 and bounds.size.z >= 0.80 and bounds.size.z <= 1.10, id + " long landmark keeps a roughly 3 by 1 cell footprint: " + str(bounds))
    check(absf(bounds.get_center().x) < 0.06 and absf(bounds.get_center().z) < 0.10, id + " landmark stays centered on the authored anchor")
    if index == 1: check(bounds.size.y <= (1.8 if id == "chemical_plant" else 1.5), id + " span or gateway stays within its height envelope")
    check(visual.get_meta("decor_variant") == expected[id][index], id + " fixed selection is unchanged")
    visual.free()
   slot.variant_mode = "auto"
   var coherent := true
   var seen: Dictionary = {}
   for sample in 64:
    slot.slot_id = "sample-%d" % sample
    var before := var_to_bytes(slot)
    var legacy_digest := JSON.stringify(["layout", slot.slot_id, "green_hill"]).sha256_text()
    var role := legacy_digest.left(8).hex_to_int() % 2
    var choice: String = skin.resolve("layout", slot)
    coherent = coherent and choice == expected[id][role] and before == var_to_bytes(slot)
    seen[role] = true
    slot.variant_mode = "fixed"
    slot.variant_index = 99
    coherent = coherent and skin.resolve("layout", slot) == choice and not skin.variant_warning(slot).is_empty()
    slot.variant_mode = "auto"
   check(coherent and seen.size() == 2, id + " Auto and missing-index fallback retain the original Green Hill role without Act mutation")
   slot.slot_type = "small"
   var pool: Array = skin.variants_for(slot)
   var digest := JSON.stringify(["layout", slot.slot_id, id]).sha256_text()
   check(skin.resolve("layout", slot) == pool[digest.left(8).hex_to_int() % pool.size()], id + " non-landmark variation is unchanged")
  if id == "green_hill":
   var small := {"slot_id": "tuft", "slot_type": "small", "placement_hint": "either", "variant_mode": "fixed", "variant_index": 2}
   check(skin.variants_for(small) == ["flower", "small_rock", "grass_tuft"], "Grass tuft appends without reordering existing small variants")
   var tuft: Node3D = skin.instantiate_slot("layout", small)
   var tuft_boxes: Array[AABB] = []
   check(collect_bounds(tuft, tuft_boxes) and tuft_boxes.size() == 7, "Grass tuft has seven finite collisionless leaf blades")
   var tuft_bounds := tuft_boxes[0]
   for box: AABB in tuft_boxes: tuft_bounds = tuft_bounds.merge(box)
   check(tuft_bounds.size.x < 0.5 and tuft_bounds.size.z < 0.5 and tuft_bounds.size.y < 0.5, "Grass tuft remains a small prop")
   tuft.free()
  p.free()
 if DisplayServer.get_name() != "headless": await capture()
 print("RESULT | Landmark themes | %d checks | %d failures" % [checks, failures])
 quit(0 if failures == 0 else 1)

func label(parent: Node, text: String, at: Vector2, size: int) -> void:
 var caption := Label.new()
 caption.text = text
 caption.position = at
 caption.add_theme_font_size_override("font_size", size)
 caption.add_theme_color_override("font_color", Color("fff0cc"))
 parent.add_child(caption)

func capture() -> void:
 root.size = Vector2i(30 + Themes.IDS.size() * 490, 1345)
 root.content_scale_size = root.size
 var canvas := CanvasLayer.new()
 root.add_child(canvas)
 var background := ColorRect.new()
 background.size = Vector2(root.size)
 background.color = Color("162c38")
 canvas.add_child(background)
 label(canvas, "SAME SLOT / MATCHED LANDMARK FOOTPRINTS", Vector2(35, 20), 30)
 label(canvas, "Long: about 3 x 1 cells   /   Circular: about 1.6 cells across   /   Same anchor and scale", Vector2(35, 64), 21)
 for column in Themes.IDS.size():
  for row in 3:
   var at := Vector2(35 + column * 490, 125 + row * 395)
   var container := SubViewportContainer.new()
   container.position = at
   container.size = Vector2(460, 310)
   canvas.add_child(container)
   var viewport := SubViewport.new()
   viewport.size = Vector2i(460, 310)
   viewport.own_world_3d = true
   viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
   container.add_child(viewport)
   var p := Presentation.new()
   p.set_theme_definition(Themes.create(Themes.IDS[column]))
   viewport.add_child(p)
   p._world_environment = WorldEnvironment.new()
   p._world_environment.environment = Environment.new()
   p.add_child(p._world_environment)
   p._key_light = DirectionalLight3D.new()
   p.add_child(p._key_light)
   p.theme_definition.configure_environment(p)
   p._world_environment.environment.background_mode = Environment.BG_COLOR
   p._world_environment.environment.background_color = Color("294451")
   var slot := {"slot_id": "comparison", "slot_type": "landmark", "placement_hint": "either", "variant_mode": "fixed", "variant_index": row}
   var prop: Node3D = p.decor_skin.instantiate_slot("comparison", slot)
   p.add_child(prop)
   var camera := Camera3D.new()
   camera.projection = Camera3D.PROJECTION_ORTHOGONAL
   camera.keep_aspect = Camera3D.KEEP_WIDTH
   camera.size = 4.3
   camera.position = Vector3(1.4, 3.2, 6.0)
   p.add_child(camera)
   camera.look_at(Vector3(0, 0.9, 0))
   camera.current = true
   label(canvas, p.theme_definition.display_name + " / " + ["Upright", "Span / Gateway", "Circular"][row], at + Vector2(0, 317), 22)
   label(canvas, str(prop.get_meta("decor_variant")).capitalize(), at + Vector2(0, 350), 20)
 for frame in 12: await process_frame
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
 check(root.get_texture().get_image().save_png(OUTPUT) == OK, "Matched footprint sheet renders")
 canvas.free()
