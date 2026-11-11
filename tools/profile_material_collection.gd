extends SceneTree
## Warm CPU comparison on real baked materials; excludes node creation and restore.
const Bake = preload("res://scripts/endless/geometry_bake.gd")
const Document = preload("res://scripts/act_editor/act_geometry.gd")
const Registry = preload("res://scripts/themes/theme_registry.gd")
const Runtime = preload("res://scripts/atmosphere/runtime.gd")
const ACT := "res://data/acts/Authored/RampMania.tres"

func _initialize() -> void: run.call_deferred()

func run() -> void:
 var themes := PackedStringArray(["green_hill", "rooftop_run", "chemical_plant"])
 var iterations := 150
 var output := "res://test-results/material-collection-cpu.json"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--themes="): themes = argument.trim_prefix("--themes=").split(",")
  if argument.begins_with("--iterations="): iterations = int(argument.trim_prefix("--iterations="))
  if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
 if themes.is_empty() or iterations < 10 or iterations > 1000:
  push_error("Choose at least one theme and 10–1000 iterations.")
  quit(1)
  return
 var document: Resource = Document.load_document(ACT).document
 var report := {"engine": Engine.get_version_info().string, "headless": DisplayServer.get_name() == "headless",
  "scope": "Warm foreground + scenery Runtime.attach elapsed time; excludes loading, node creation, restore, GPU frames and Windows FPS.",
  "act": ACT, "iterations": iterations, "warmup_iterations": 5, "trials": [],
  "bindings_sha256": FileAccess.get_sha256("res://scripts/atmosphere/material_bindings.gd")}
 for theme: String in themes:
  if theme not in Registry.IDS:
   push_error("Unknown theme: " + theme)
   quit(1)
   return
  var baked: Resource = load(Bake.path_for(ACT, theme))
  var theme_bake: Resource = load(Bake.theme_path(theme))
  var fingerprint := Bake.pipeline_hash(theme)
  if not baked is Bake or document == null or not baked.matches(document, theme, fingerprint) or not theme_bake is Bake or not theme_bake.matches_pipeline(theme, fingerprint):
   push_error("Current production Act and scenery bakes required: " + theme)
   quit(1)
   return
  var foreground := Node3D.new()
  var scenery := Node3D.new()
  foreground.process_mode = Node.PROCESS_MODE_DISABLED
  scenery.process_mode = Node.PROCESS_MODE_DISABLED
  root.add_child(foreground)
  root.add_child(scenery)
  var nodes: Array[Node] = []
  for index in baked.visual_recipe.records.size():
   baked.visual_recipe.instantiate_one(index, nodes, scenery if baked.visual_recipe.records[index].get("background", false) else foreground)
  var runtime := Runtime.new()
  var sun := DirectionalLight3D.new()
  root.add_child(sun)
  runtime.configure(theme, {}, theme_bake.environment, sun)
  for warm in 5:
   runtime.bindings.restore()
   runtime.attach(foreground)
   runtime.attach(scenery, false, true)
  for cached: bool in [false, true, true, false]:
   runtime.bindings._cache_uniforms = cached
   var samples: Array[float] = []
   for iteration in iterations:
    runtime.bindings.restore()
    var began := Time.get_ticks_usec()
    runtime.attach(foreground)
    runtime.attach(scenery, false, true)
    samples.append((Time.get_ticks_usec() - began) / 1000.0)
   samples.sort()
   var total := 0.0
   for sample: float in samples: total += sample
   var trial := {"theme": theme, "cached": cached, "mean_ms": total / samples.size(),
    "median_ms": samples[samples.size() / 2], "p95_ms": samples[ceili(samples.size() * 0.95) - 1],
    "pipeline_fingerprint": fingerprint, "act_bake_sha256": FileAccess.get_sha256(Bake.path_for(ACT, theme)),
    "theme_bake_sha256": FileAccess.get_sha256(Bake.theme_path(theme))}
   report.trials.append(trial)
   print("MATERIAL_COLLECTION_CPU | ", JSON.stringify(trial))
  runtime.bindings.restore()
  foreground.free()
  scenery.free()
  sun.free()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
 var file := FileAccess.open(output, FileAccess.WRITE)
 if file == null:
  push_error("Cannot write material profile: " + error_string(FileAccess.get_open_error()))
  quit(1)
  return
 file.store_string(JSON.stringify(report, "  "))
 quit()
