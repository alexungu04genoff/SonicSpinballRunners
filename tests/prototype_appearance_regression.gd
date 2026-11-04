extends SceneTree
## Small authority/freshness guard. Source-lab regressions remain independent.
const Fixture = preload("res://tests/prototype_appearance_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
 Engine.time_scale = 0.0
 run.call_deferred()

func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)

func run() -> void:
 root.size = Vector2i(1440, 1000)
 var act := Fixture.DEFAULT_ACT
 var manifest: Dictionary = {}
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--act="): act = argument.trim_prefix("--act=")
  if argument.begins_with("--verify-manifest="):
   var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--verify-manifest=")))
   if not parsed is Dictionary or not parsed.get("complete", false) or parsed.get("captures", []).size() != Fixture.Registry.IDS.size():
    check(false, "Incomplete capture manifest")
    quit(1)
    return
   for receipt: Dictionary in parsed.captures: manifest[receipt.theme] = receipt
 for path: String in ["all_theme_texture_scene.gd", "theme_capture.gd"]:
  var source := FileAccess.get_file_as_string("res://tests/" + path)
  check(source.begins_with('extends "res://tests/prototype_appearance_capture.gd"'), path + " delegates to the canonical capture")
 var stale_path := "res://test-results/prototype-appearance-stale/act.tres"
 DirAccess.make_dir_recursive_absolute(stale_path.get_base_dir())
 var stale_document: Resource = Fixture.Document.load_document(act).document
 if stale_document == null:
  check(false, "Cannot read the source Act")
  quit(1)
  return
 stale_document = stale_document.copy_document()
 check(stale_document.save_document(stale_path) == OK, "Save isolated negative fixture")
 var stale := Fixture.Bake.new()
 stale.theme_id = "green_hill"
 stale.source_fingerprint = stale_document.fingerprint()
 stale.pipeline_fingerprint = "deliberately-stale-pipeline"
 var stale_bake := Fixture.Bake.path_for(stale_path, "green_hill")
 DirAccess.make_dir_recursive_absolute(stale_bake.get_base_dir())
 check(ResourceSaver.save(stale, stale_bake) == OK, "Save isolated stale receipt")
 var rejected := Fixture.new()
 check(not await rejected.open(self, stale_path, "green_hill", stale_path.get_base_dir()) and rejected.session == null and rejected.error.contains("stale"), "Stale disk input fails before starting a session or falling back to source construction")
 await rejected.close()
 var expected := {}
 for theme: String in Fixture.Registry.IDS:
  var fixture := Fixture.new()
  if not await fixture.open(self, act, theme, "res://test-results/prototype-appearance-regression"):
   check(false, fixture.error)
   await fixture.close()
   break
  check(fixture.authority_error().is_empty(), "Real Prototype session, Goal and disk library: " + theme)
  var state := fixture.state()
  if expected.is_empty(): expected = state
  check(state == expected, "Matched state and camera: " + theme)
  check(fixture.still_current(), "Current Act, scenery, material pipeline and disk receipts: " + theme)
  if not manifest.is_empty():
   check(manifest.has(theme), "Manifest includes " + theme)
   if manifest.has(theme):
    for key: String in ["source_sha256", "pipeline_fingerprint", "scenery_fingerprint", "act_bake_sha256", "theme_bake_sha256", "atmosphere"]:
     # JSON stores Color/Vector values as strings and numeric values as floats.
     var serialized: Variant = JSON.parse_string(JSON.stringify(fixture.receipt[key]))
     check(manifest[theme][key] == serialized, "Whole comparison still current: " + theme + " / " + key)
  var baked: Resource = load(fixture.receipt.act_bake)
  check(not baked.matches(fixture.game.active.document, theme, "deliberately-stale-pipeline"), "Reject stale pipeline: " + theme)
  var copy: Resource = fixture.game.active.document.copy_document()
  copy.spawn_position += Vector2.ONE
  check(not baked.matches(copy, theme, fixture.receipt.pipeline_fingerprint), "Reject stale Act: " + theme)
  check(fixture.game._uses_authoring_builder() == false, "Baked fixture cannot silently build source art")
  fixture.game.run_configuration.single_act_use_bakes = false
  check(fixture.game._uses_authoring_builder(), "Ordinary editor Act tests still use their source builder")
  fixture.game.run_configuration.single_act_use_bakes = true
  check(not FileAccess.file_exists(fixture.session.settings_path), "No player preferences written")
  await fixture.close()
 check(Fixture.Registry.IDS.size() == 8, "All eight registered themes covered")
 print("RESULT | Prototype appearance regression | %d checks | %d failures" % [checks, failures])
 quit(1 if failures else 0)
