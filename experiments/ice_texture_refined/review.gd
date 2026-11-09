extends SceneTree
## Current Ice Cap inspection of the actual Prototype disk-bake path.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
const Materials = preload("res://scripts/themes/ice_selected_materials.gd")
const Controls = preload("res://experiments/ice_texture_refined/live_controls.gd")
const OUTPUT := "res://experiments/ice_texture_refined/review"
const IDS := ["1A", "2B", "3A", "5A", "6A", "7B", "9A", "11A", "12B"]
var found := {}
var material_slots: Array[Dictionary] = []
var expected := {}
var expected_response := {}
var found_response := {}
var texture_digests := {}
var snow_guard_slots: Array[Dictionary] = []
var expected_normal := {}
var found_normal := {}
var detail_materials := {}

func library_receipt() -> Dictionary:
 var fingerprint := Fixture.Bake.pipeline_hash("ice_cap")
 var paths: Array = preload("res://scripts/prototype/run_plan.gd").source_paths()
 paths.append_array(preload("res://scripts/endless/endless_plan.gd").PATHS)
 var result := {"complete": true, "pipeline": fingerprint, "acts": []}
 for path: String in paths:
  var document: Resource = Fixture.Document.load_document(path).document
  var baked: Resource = load(Fixture.Bake.path_for(path, "ice_cap"))
  var current: bool = baked is Fixture.Bake and baked.matches(document, "ice_cap", fingerprint) and baked.surface_detail == "selected_relief"
  result.complete = result.complete and current
  result.acts.append({"source": path, "current": current})
 var theme: Resource = load(Fixture.Bake.theme_path("ice_cap"))
 result.theme_current = theme is Fixture.Bake and theme.matches_pipeline("ice_cap", fingerprint) and theme.surface_detail == "selected_relief"
 result.complete = result.complete and result.theme_current
 return result

class ControlHost extends Node:
 var theme_id := "ice_cap"
 var presentation: Node

func _initialize() -> void:
 Engine.time_scale = 0.0
 run.call_deferred()

func inspect_material(material: Material, location: String) -> void:
 if material == null: return
 if material.get_meta("ice_selected", false): detail_materials[material] = true
 if material.get_meta("ice_cap_snow_railguard", false):
  snow_guard_slots.append({"node": location, "material": material.resource_name,
   "roughness": material.roughness if material is BaseMaterial3D else material.get_shader_parameter("roughness"),
   "specular": material.metallic_specular if material is BaseMaterial3D else material.get_shader_parameter("specular")})
 var textures := {}
 if material is ShaderMaterial:
  for uniform: Dictionary in material.shader.get_shader_uniform_list():
   var value = material.get_shader_parameter(uniform.name)
   if value is Texture2D: textures[str(uniform.name)] = value
 elif material is BaseMaterial3D and material.albedo_texture != null:
  textures["albedo_texture"] = material.albedo_texture
 for parameter: String in textures:
  var texture: Texture2D = textures[parameter]
  var texture_id := texture.get_instance_id()
  if not texture_digests.has(texture_id): texture_digests[texture_id] = Fixture.image_digest(texture.get_image())
  var digest: String = texture_digests[texture_id]
  if expected_response.has(digest): found_response[expected_response[digest]] = true
  if expected_normal.has(digest): found_normal[expected_normal[digest]] = true
  if not expected.has(digest): continue
  var id: String = expected[digest]
  found[id] = true
  material_slots.append({"id": id, "node": location, "parameter": parameter,
   "material": material.resource_name, "runtime_texture": texture.resource_path,
   "mapping": material.get_shader_parameter("mapping") if material is ShaderMaterial else "mesh UV",
   "normal_strength": material.get_shader_parameter("relief_strength") if material is ShaderMaterial else null,
   "repeat_size": str(material.get_shader_parameter("repeat_size")) if material is ShaderMaterial else str(material.uv1_scale)})

func run() -> void:
 if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
  push_error("Use the graphical Forward+ renderer for this review.")
  quit(1)
  return
 root.size = Vector2i(1440, 1000)
 root.gui_disable_input = true
 preload("res://scripts/rendering_options.gd").settings_path = OUTPUT.path_join("isolated-graphics.cfg")
 for id: String in IDS:
  var path := "res://assets/textures/ice_cap/selected/" + id + ".png"
  expected[Fixture.image_digest(Image.load_from_file(path))] = id
  expected_normal[Fixture.image_digest(Image.load_from_file(path.replace(".png", "-normal.png")))] = id
  if id != "11A":
   expected_response[Fixture.image_digest(Image.load_from_file(path.replace(".png", "-response.png")))] = id
 var act := Fixture.DEFAULT_ACT
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--act="): act = argument.trim_prefix("--act=")
 var fixture := Fixture.new()
 if not await fixture.open(self, act, "ice_cap", OUTPUT):
  var current := Fixture.Bake.pipeline_hash("ice_cap")
  var document: Resource = Fixture.Document.load_document(act).document
  for baked_path: String in [Fixture.Bake.path_for(act, "ice_cap"), Fixture.Bake.theme_path("ice_cap")]:
   var baked: Resource = load(baked_path)
   print("ICE_REVIEW_SOURCE | ", JSON.stringify({"path": baked_path, "current_pipeline": current,
    "saved_pipeline": baked.pipeline_fingerprint, "current_document": document.fingerprint(),
    "saved_document": baked.source_fingerprint, "saved_scenery": baked.scenery_fingerprint,
    "current_scenery": Fixture.Bake.ScenerySettings.signature(act, "ice_cap"), "kind": baked.kind,
    "version": baked.version, "expected_version": Fixture.Bake.VERSION}))
  push_error(fixture.error)
  await fixture.close()
  quit(1)
  return
 # The production fixture owns the normal scene, camera, lighting and disk library.
 # Hide only UI in this isolated run; no user settings or editor state are changed.
 fixture.game.hud.hide()
 # Requested wider framing uses the production camera controls only in this run.
 var presentation: Node3D = fixture.game.presentation
 var camera_target: Vector2 = fixture.game.ball.position
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--camera-target="):
   var coordinates := argument.trim_prefix("--camera-target=").split(",")
   camera_target = Vector2(float(coordinates[0]), float(coordinates[1]))
  if argument.begins_with("--review-zoom="):
   presentation.set_camera_value("zoom", float(argument.trim_prefix("--review-zoom=")))
 if "--review-overview" in OS.get_cmdline_user_args(): presentation.set_camera_follow(false)
 presentation.reset_camera(camera_target)
 fixture.game._process(0.0)
 var detail_enabled := "--albedo-only" not in OS.get_cmdline_user_args()
 var normal_strength := 1.0
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--normal-strength="): normal_strength = clampf(float(argument.trim_prefix("--normal-strength=")), 0.0, 2.0)
 # Canonical captures keep the loaded defaults; only an explicit diagnostic changes them.
 if not detail_enabled or normal_strength != 1.0: Materials.set_detail(fixture.game, detail_enabled, normal_strength)
 var required: Array = IDS.duplicate()
 var has_ramp := false
 for item: Dictionary in fixture.game.active.document.gameplay_objects:
  if item.type == "elevated_rail": has_ramp = true
 if not has_ramp:
  required.erase("7B")
 for node: Node in fixture.game.find_children("*", "GeometryInstance3D", true, false):
  if node.material_override != null:
   inspect_material(node.material_override, str(node.get_path()))
  elif node is MeshInstance3D and node.mesh != null:
   for surface in node.mesh.get_surface_count():
    inspect_material(node.get_active_material(surface), str(node.get_path()) + "/surface" + str(surface))
  elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
   for surface in node.multimesh.mesh.get_surface_count():
    inspect_material(node.multimesh.mesh.surface_get_material(surface), str(node.get_path()) + "/surface" + str(surface))
 var before := fixture.state()
 for frame in 12: await process_frame
 await RenderingServer.frame_post_draw
 var complete := fixture.still_current() and fixture.authority_error().is_empty() and fixture.state() == before
 complete = complete and fixture.receipt.surface_detail == "selected_relief"
 if has_ramp:
  complete = complete and not snow_guard_slots.is_empty()
  for slot: Dictionary in snow_guard_slots:
   complete = complete and slot.roughness != null and float(slot.roughness) >= 0.9 and slot.specular != null and float(slot.specular) <= 0.2
 for id: String in required: complete = complete and found.has(id)
 for id: String in required: complete = complete and found_normal.has(id)
 for id: String in required:
  if id != "11A": complete = complete and found_response.has(id)
 var suffix := "gameplay"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--review-label="): suffix = argument.trim_prefix("--review-label=")
 var image := root.get_texture().get_image()
 var image_error := image.save_png(OUTPUT.path_join(suffix + ".png"))
 complete = complete and image_error == OK
 var controls_checked := false
 var detail_difference := 0.0
 if "--check-detail" in OS.get_cmdline_user_args():
  var host := ControlHost.new()
  host.presentation = fixture.game
  root.add_child(host)
  var controls := Controls.new()
  host.add_child(controls)
  controls.install(host)
  controls.detail.button_pressed = false
  controls_checked = not detail_materials.is_empty()
  for material: ShaderMaterial in detail_materials:
   controls_checked = controls_checked and is_zero_approx(float(material.get_shader_parameter("relief_strength")))
  for frame in 12: await process_frame
  await RenderingServer.frame_post_draw
  var flat := root.get_texture().get_image()
  detail_difference = image.compute_image_metrics(flat, false).get("mean", 0.0)
  controls.detail.button_pressed = true
  controls.strength.value = .5
  for material: ShaderMaterial in detail_materials:
   controls_checked = controls_checked and is_equal_approx(float(material.get_shader_parameter("relief_strength")), float(material.get_meta("normal_strength")) * .5)
  controls.strength.value = 1.0
  for material: ShaderMaterial in detail_materials:
   controls_checked = controls_checked and is_equal_approx(float(material.get_shader_parameter("relief_strength")), float(material.get_meta("normal_strength")))
  host.free()
  complete = complete and controls_checked and detail_difference > 0.0
 var receipt: Dictionary = fixture.receipt.duplicate(true)
 if "--check-library" in OS.get_cmdline_user_args():
  receipt.library = library_receipt()
  complete = complete and receipt.library.complete
 receipt.merge({"complete": complete, "hud_hidden": true, "state": before,
  "selected_ids_bound": found.keys(), "required_ids_for_act": required, "active_material_slots": material_slots,
  "structural_response_ids_bound": found_response.keys(), "reflection_source": "existing environment sky",
  "structural_normal_ids_bound": found_normal.keys(), "detail_enabled": detail_enabled,
  "normal_strength_multiplier": normal_strength, "material_controls_checked": controls_checked,
  "detail_image_mean_difference": detail_difference,
  "snow_guard_slots": snow_guard_slots,
  "review_camera": {"follow": presentation.camera_follow_enabled, "overview_zoom": presentation.overview_zoom, "follow_zoom": presentation.camera_settings.zoom},
  "current_act_texture_matches": fixture.texture_evidence(), "generated_relief": true})
 var file := FileAccess.open(OUTPUT.path_join(suffix + ".json"), FileAccess.WRITE)
 file.store_string(JSON.stringify(receipt, "  "))
 print("ICE_MATERIAL_REVIEW | complete=", complete, " | selected bindings=", found.keys(), " | source current=", fixture.still_current())
 await fixture.close()
 quit(0 if complete else 1)
