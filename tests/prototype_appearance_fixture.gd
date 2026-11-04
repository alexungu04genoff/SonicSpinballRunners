extends RefCounted
## Canonical production appearance fixture. Owns a real Prototype session and
## requires the same disk library as normal runs. No source-theme construction.
const SCENE = preload("res://scenes/prototype_run.tscn")
const Library = preload("res://scripts/endless/template_library.gd")
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
const Report = preload("res://tests/render_profile_support.gd")
const DEFAULT_ACT := "res://data/acts/Authored/First Try Smooth Decor.tres"
var session: Control
var game: Node
var error := ""
var receipt := {}

func open(tree: SceneTree, path: String, theme: String, output: String) -> bool:
 error = ""
 var source := Document.load_document(path)
 if source.document == null or theme not in Registry.IDS:
  error = "Invalid Act or theme: " + path + " / " + theme
  return false
 var fingerprint := Bake.pipeline_hash(theme)
 var act_bake: Resource = load(Bake.path_for(path, theme)) if ResourceLoader.exists(Bake.path_for(path, theme)) else null
 var theme_bake: Resource = load(Bake.theme_path(theme)) if ResourceLoader.exists(Bake.theme_path(theme)) else null
 if not act_bake is Bake or not act_bake.matches(source.document, theme, fingerprint) or not theme_bake is Bake or not theme_bake.matches_pipeline(theme, fingerprint):
  error = "Missing/stale production bake: " + theme + ". Bake this Act with scenes/act_baker.tscn first."
  return false
 seed(18)
 session = SCENE.instantiate()
 session.settings_path = output.path_join("isolated-settings.cfg")
 session.archive_directory = output.path_join("isolated-telemetry")
 session.configure_act_test(path)
 session.run_configuration.single_act_use_bakes = true
 session.run_configuration.atmosphere_overrides = {theme: "default"}
 session.run_configuration.selected_theme_ids = [theme]
 session.selected_character = "sonic"
 session.sound_enabled = false
 tree.root.add_child(session)
 await session.start_run()
 game = session.game
 var deadline := Time.get_ticks_msec() + 180000
 while is_instance_valid(game) and not game.started and Time.get_ticks_msec() < deadline:
  if not game.last_source_error.is_empty() or (is_instance_valid(game.library) and not game.library.error.is_empty()): break
  await tree.process_frame
 if not is_instance_valid(game) or not game.started:
  error = "Prototype did not start: " + (str(game.last_source_error) if is_instance_valid(game) else "no run")
  return false
 # Keep the play HUD visible while holding simulation; the session's ordinary
 # pause observer would otherwise cover the evidence with the pause menu.
 session.set_process(false)
 session.overlay_root.hide()
 tree.paused = true
 Report.disable_native_input(session)
 game.controls.input_blocked = true
 game.set_physics_process(false)
 game.ball.freeze = true
 game.auto_launch_time = -1.0
 game.retro_filter.set_preset(0)
 # Startup FPS is not a performance sample and makes otherwise matched frames noisy.
 game.fps_label.hide()
 game.presentation.reset_camera(game.ball.position)
 # Let the real compositor/atmosphere copy the settled camera, without game time.
 game._process(0.0)
 receipt = {"authority": "Prototype", "scene": SCENE.resource_path,
  "act": path, "act_fingerprint": source.document.fingerprint(),
  "source_sha256": FileAccess.get_sha256(path), "theme": theme,
  "pipeline_fingerprint": fingerprint, "scenery_fingerprint": act_bake.scenery_fingerprint,
  "act_bake": Bake.path_for(path, theme), "act_bake_sha256": FileAccess.get_sha256(Bake.path_for(path, theme)),
  "theme_bake": Bake.theme_path(theme), "theme_bake_sha256": FileAccess.get_sha256(Bake.theme_path(theme)),
  "atmosphere": game.active.plan.atmosphere.duplicate(true),
  "library": game.library.get_script().resource_path, "disk_acts": game.library.visual_bake_hits,
  "disk_themes": game.library.theme_bake_hits, "fallback_builds": game.library.fallback_builds,
  "surface_detail": act_bake.surface_detail, "seed": game.run_seed,
  "fps_counter_hidden": true, "renderer": Report.metadata()}
 error = authority_error()
 return error.is_empty()

func authority_error() -> String:
 if not is_instance_valid(session) or session.get_script() != preload("res://scripts/prototype/session.gd"):
  return "Appearance evidence must own the real Prototype session."
 if game.get_script() != preload("res://scripts/prototype/zone_run.gd") or game.library.get_script() != Library:
  return "Appearance evidence must use Prototype and its production disk library."
 if game.library.fallback_builds != 0 or game.library.visual_bake_hits != 1 or game.library.theme_bake_hits != 1:
  return "Expected one disk Act and theme, without runtime rebuilds."
 if game.active.plan.theme != receipt.theme or game.run_plan.size() != 1 or game.resident.size() != 1:
  return "Wrong theme or Act count."
 if not is_instance_valid(game.active.runtime.goal_ring) or not game.active.runtime.goal_ring.is_visible_in_tree():
  return "Prototype Goal presentation is missing."
 return ""

func state() -> Dictionary:
 var camera: Camera3D = game.presentation.camera
 return {"document": game.active.document.fingerprint(), "ball": str(game.ball.position),
  "velocity": str(game.ball.linear_velocity), "score": game.score, "act_score": game.act_score,
  "rings": game.rings_collected, "serve_pending": game.ball.serve_pending,
  "goal_unlocked": game.active.runtime.goal_ring.unlocked,
  "camera_transform": str(camera.global_transform), "camera_fov": camera.fov,
  "camera_size": camera.size, "camera_projection": camera.projection,
  "camera_settings": game.presentation.camera_settings.duplicate(true)}

func still_current() -> bool:
 var document: Resource = Document.load_document(receipt.act).document
 return document != null and document.fingerprint() == receipt.act_fingerprint \
  and FileAccess.get_sha256(receipt.act) == receipt.source_sha256 \
  and Bake.pipeline_hash(receipt.theme) == receipt.pipeline_fingerprint \
  and Bake.ScenerySettings.signature(receipt.act, receipt.theme) == receipt.scenery_fingerprint \
  and FileAccess.get_sha256(receipt.act_bake) == receipt.act_bake_sha256 \
  and FileAccess.get_sha256(receipt.theme_bake) == receipt.theme_bake_sha256

static func image_digest(image: Image) -> String:
 if image == null or image.is_empty(): return ""
 image = image.duplicate()
 if image.is_compressed():
  if image.decompress() != OK: return ""
 image.clear_mipmaps()
 image.convert(Image.FORMAT_RGBA8)
 var hash := HashingContext.new()
 hash.start(HashingContext.HASH_SHA256)
 hash.update(var_to_bytes(image.get_size()))
 hash.update(image.get_data())
 return hash.finish().hex_encode()

static func png_paths(directory: String) -> Array[String]:
 var paths: Array[String] = []
 for file: String in DirAccess.get_files_at(directory):
  if file.ends_with(".png"): paths.append(directory.path_join(file))
 for child: String in DirAccess.get_directories_at(directory): paths.append_array(png_paths(directory.path_join(child)))
 return paths

func texture_evidence() -> Array[Dictionary]:
 # Inspect the resources actually loaded by the runtime, not a second theme.
 var baked: Resource = game.library._act_bakes[game.library.key(receipt.theme, 0)]
 var textures := {}
 for resource: Resource in baked.retirement_dependencies:
  if resource is Texture2D:
   var digest := image_digest(resource.get_image())
   if not digest.is_empty(): textures[digest] = resource.resource_path
   # Imported PNGs can retain old .godot pixels after a source edit even when
   # the bake's source hash is fresh. Fail instead of blessing that cache state.
   if resource.resource_path.begins_with("res://assets/") and resource.resource_path.ends_with(".png"):
    var source_digest := image_digest(Image.load_from_file(ProjectSettings.globalize_path(resource.resource_path)))
    if source_digest != digest: error = "Imported texture pixels differ from current source; reimport before baking: " + resource.resource_path
 var matches: Array[Dictionary] = []
 var directory: String = "res://assets/textures/" + receipt.theme
 # Selected/approved artwork supersedes the original generated material set.
 for subdirectory: String in ["selected", "approved"]:
  if DirAccess.dir_exists_absolute(directory.path_join(subdirectory)):
   directory = directory.path_join(subdirectory)
   break
 for path: String in png_paths(directory):
  var digest := image_digest(Image.load_from_file(ProjectSettings.globalize_path(path)))
  if textures.has(digest):
   matches.append({"source": path, "source_sha256": FileAccess.get_sha256(path),
    "runtime_texture": textures[digest], "rgba8_sha256": digest})
 return matches

func close() -> void:
 if is_instance_valid(session):
  # Verification is not a played run: do not archive it or write player records.
  session.archive_attempted = true
  await session._close_run("appearance_verification")
  session.free()
 session = null
 game = null
