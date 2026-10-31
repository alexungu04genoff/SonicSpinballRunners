extends SceneTree
## Deterministic authoring, gameplay isolation, bounded local scenery and receipts.
const Settings := preload("res://scripts/themes/scenery_settings.gd")
const Layout := preload("res://scripts/themes/scenery_layout.gd")
const Bake := preload("res://scripts/endless/geometry_bake.gd")
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func frames(count := 3) -> void:
 for frame in count: await process_frame

func run() -> void:
 var path := "res://test-results/scenery-authoring/fixture.tres"
 var original := "res://data/acts/Authored/Reverse C Spring.tres"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 DirAccess.copy_absolute(ProjectSettings.globalize_path(original), ProjectSettings.globalize_path(path))
 if FileAccess.file_exists(Settings.path_for(path)): DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path_for(path)))
 var hash := FileAccess.get_sha256(path)
 var default_signature := Settings.signature(path, "green_hill")
 check(Settings.read(path, "green_hill").seed == 0, "Missing settings use authored seed zero")
 check(Settings.save(path, "ice_cap", {"seed": 19, "density": 0.75}) == OK, "Save first theme")
 var other := Settings.signature(path, "ice_cap")
 check(Settings.save(path, "green_hill", {"seed": 183742, "density": 1.5}) == OK, "Save selected theme")
 check(Settings.read(path, "green_hill").seed == 183742, "Round trip seed")
 check(Settings.signature(path, "ice_cap") == other, "Other theme settings preserved")
 check(Settings.signature(path, "green_hill") != default_signature, "Selected theme receipt changes")
 check(Settings.signature(original, "green_hill") == default_signature, "Other Act receipt unchanged")
 check(FileAccess.get_sha256(path) == hash, "Saving scenery never changes Act bytes")
 for values: Dictionary in [{"seed": -1, "density": 1.0}, {"seed": 4.2, "density": 1.0}, {"seed": 1, "density": 1.51}, {"seed": 1, "density": NAN}, {"seed": 1, "density": 0.49}]:
  check(Settings.save(path, "green_hill", values) == ERR_INVALID_DATA, "Invalid input rejected")
 var document: Resource = preload("res://scripts/act_editor/act_geometry.gd").load_document(original).document
 var bake := Bake.new()
 bake.theme_id = "green_hill"
 bake.source_fingerprint = document.fingerprint()
 bake.scenery_fingerprint = default_signature
 bake.pipeline_fingerprint = "test-pipeline"
 check(bake.matches(document, "green_hill", "test-pipeline"), "Original receipt valid")
 document = preload("res://scripts/act_editor/act_geometry.gd").load_document(path).document
 check(not bake.matches(document, "green_hill", "test-pipeline"), "Only changed scenery receipt is stale")
 check(bake.matches_geometry(document, "green_hill", "test-pipeline"), "Scenery leaves collision receipt valid")
 var malformed := FileAccess.open(Settings.path_for(path), FileAccess.WRITE)
 malformed.store_string("[format]\nversion=1\n[green_hill]\nseed=\"bad\"\ndensity=1.0\n")
 malformed.close()
 check(Settings.signature(path, "green_hill").is_empty(), "Malformed authored values cannot validate a bake")
 for density: float in [0.5, 0.75, 1.0, 1.25, 1.5]:
  var layout := Layout.new({"seed": 183742, "density": density}, "green_hill")
  check(layout.plans([{"side": -1, "at": 0.8}, {"side": 1, "at": 0.24}]).size() <= 3, "Bounded group candidates")
  check(is_finite(layout.fit(Rect2(0, 0, 600, 1800), -1, 100, 80)), "First footprint fits")
  check(not is_finite(layout.fit(Rect2(0, 0, 600, 1800), -1, 110, 80)), "Overlapping footprint rejected")
  check(not is_finite(layout.fit(Rect2(0, 0, 600, 100), 1, 50, 80)), "Oversized footprint rejected")
 game = load("res://experiments/lighting_lab/lighting_lab.tscn").instantiate()
 game.authored_act_path = original
 root.add_child(game)
 paused = true
 root.gui_disable_input = true
 await frames()
 var panel = game.lighting_controls
 for theme: String in Settings.THEMES:
  game.set_theme(theme)
  await frames()
  var p: Node3D = game.presentation
  var terrain: int = p.terrain_root.get_instance_id()
  var runtime: int = game.playfield.authored_runtime.root.get_instance_id()
  var document_hash: String = game.playfield.document.fingerprint()
  var ball_state := [game.ball.get_instance_id(), game.ball.position, game.ball.linear_velocity]
  var camera: Transform3D = p.camera.transform
  var far_ids := []
  for child: Node in p.scenery_root.get_children():
   if child.get_meta("atmosphere_scenery", "") == "far": far_ids.append(child.get_instance_id())
  panel.set_value("env/tonemap_exposure", 0.83)
  var palette: Dictionary = panel.values.duplicate(true)
  var signatures := []
  for seed_value: int in [0, 183742, 9127]:
   for density: float in [0.5, 1.0, 1.5]:
    var selected := {"seed": seed_value, "density": density}
    seed(8723)
    var expected := [randi(), randi(), randi()]
    seed(8723)
    panel.scenery.change(selected)
    check([randi(), randi(), randi()] == expected, theme + " scenery consumes no gameplay RNG")
    await frames()
    var first := signature(p.scenery_root)
    panel.scenery.change(selected)
    await frames()
    check(first == signature(p.scenery_root), theme + " exact repeated mesh/transform composition")
    if density == 1.0:
     signatures.append(first)
     print("SCENERY_CASE | ", theme, " seed=", seed_value, " groups=", p.scenery_group_count, " hash=", first.substr(0, 12))
    var maximum := 5 if theme in ["green_hill", "ice_cap"] else 3
    check(p.scenery_group_count <= maximum, theme + " sensible group cap")
    check(p.camera.transform == camera, "Preview preserves camera")
    check([game.ball.get_instance_id(), game.ball.position, game.ball.linear_velocity] == ball_state, "Preview preserves ball")
    check(game.playfield.authored_runtime.root.get_instance_id() == runtime and p.terrain_root.get_instance_id() == terrain, "Preview preserves gameplay and terrain identity")
    check(game.playfield.document.fingerprint() == document_hash, "Preview preserves authored gameplay")
    check(panel.values == palette, "Preview preserves atmosphere draft")
    for id: int in far_ids: check(is_instance_id_valid(id), "Shared far scenery survives regeneration")
  check(signatures[0] != signatures[1] and signatures[1] != signatures[2], theme + " seeds change composition")
  panel.scenery.frame_edge(-1)
  check(is_equal_approx(p.camera.fov, 52.0) and not p.camera_follow_enabled, "Approved inspection camera")
  panel.scenery.frame_edge(1)
  check([game.ball.get_instance_id(), game.ball.position, game.ball.linear_velocity] == ball_state, "Inspection does not move ball")
 # Exercise the actual controls against the disposable fixture, including a
 # typed seed whose line edit has not lost focus when Save is clicked.
 DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path_for(path)))
 panel.scenery.act_path = path
 panel.scenery.change({"seed": 11, "density": 0.75})
 panel.scenery.seed_field.get_line_edit().text = "183742"
 panel.scenery.save()
 check(Settings.read(path, game.theme_id).seed == 183742, "Save commits typed seed")
 panel.scenery.change({"seed": 99, "density": 1.5})
 panel.scenery.reload()
 check(panel.scenery.values == {"seed": 183742, "density": 0.75}, "UI reload restores authored inputs")
 check(FileAccess.get_sha256(path) == hash, "UI saves leave gameplay Act untouched")
 game.free()
 print("SCENERY_REGRESSION | checks=%d failures=%d" % [checks, failures])
 quit(1 if failures else 0)

func signature(root_node: Node) -> String:
 var data := []
 for child: Node in root_node.get_children():
  if child.get_meta("atmosphere_scenery", "") != "local": continue
  var pending: Array[Node] = [child]
  while not pending.is_empty():
   var node: Node = pending.pop_back()
   pending.append_array(node.get_children())
   check(not node is Light3D, "Local scenery adds no light")
   if node is GeometryInstance3D:
    check(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Local scenery remains shadowless")
   var mesh: Mesh
   if node is MeshInstance3D:
    mesh = node.mesh
    data.append(node.global_transform)
   elif node is MultiMeshInstance3D:
    mesh = node.multimesh.mesh
    data.append(node.global_transform)
    data.append(node.multimesh.get_meta("offline_transforms", node.multimesh.buffer))
   if mesh != null:
    for surface in mesh.get_surface_count(): data.append(mesh.surface_get_arrays(surface))
 return var_to_bytes(data).hex_encode().sha256_text()
