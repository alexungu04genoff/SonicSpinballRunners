extends SceneTree
## Optional laptop diagnostic: real Prototype contact, callbacks, HUD and audio.
const Run = preload("res://scripts/prototype/zone_run.gd")
const Model = preload("res://scripts/enemies/buzz_bomber_model.gd")
const FIXTURE := "res://data/acts/buzz_bomber_test.tres"
var game: Node
var frame_samples: Array[float] = []
var cpu_samples: Array[Dictionary] = []
var measuring := false
var previous_frame := 0

func _initialize() -> void:
 process_frame.connect(_sample_frame)
 call_deferred("run")

func _sample_frame() -> void:
 var now := Time.get_ticks_usec()
 if measuring and previous_frame > 0: frame_samples.append((now - previous_frame) / 1000.0)
 previous_frame = now

func pipelines() -> Dictionary:
 var values := {}
 # Monitor names vary across Godot versions; report only the available counters.
 for name: String in ClassDB.class_get_integer_constant_list("Performance"):
  if name.begins_with("PIPELINE_COMPILATIONS_"):
   values[name] = Performance.get_monitor(ClassDB.class_get_integer_constant("Performance", name))
 return values

func shoot(id: String, at: Vector2) -> Dictionary:
 game.ball.freeze = false
 game.ball.teleport_to(at, Vector2(0, 260), false)
 var enemy: Dictionary = game.active.runtime.mechanics.enemies.by_id[id]
 frame_samples.clear()
 cpu_samples.clear()
 var before := pipelines()
 var score_before: int = game.score
 var deadline := Time.get_ticks_msec() + 5000
 previous_frame = 0
 measuring = true
 while enemy.alive and Time.get_ticks_msec() < deadline:
  await physics_frame
  await process_frame
 var killed: bool = not enemy.alive
 # Keep the authoritative mechanics clock running so the complete effect plays.
 # Park away from other targets; the overview camera still sees the killed enemy.
 game.ball.teleport_to(Vector2(550, 820), Vector2.ZERO, false)
 # Observe the visibility/transparent transition and asynchronous render work.
 var until := Time.get_ticks_msec() + 800
 while Time.get_ticks_msec() < until: await process_frame
 game.ball.freeze = true
 measuring = false
 var after := pipelines()
 for key: String in after: after[key] -= float(before.get(key, 0))
 var maximum := 0.0
 for value: float in frame_samples: maximum = maxf(maximum, value)
 var result := {"target": id, "killed": killed, "score_delta": game.score - score_before,
  "max_frame_interval_ms": maximum, "frames": frame_samples.size(),
  "cpu": cpu_samples.duplicate(true), "pipeline_compilation_delta": after}
 print("BUZZ_DEATH_SAMPLE | ", JSON.stringify(result))
 return result

func run() -> void:
 game = Run.new()
 game.character_id = "sonic"
 game.run_configuration = Run.RunPlan.Configuration.new([FIXTURE])
 game.run_configuration.single_act_test = true
 game.run_configuration.zone_count = 1
 game.run_configuration.selected_theme_ids = ["green_hill"]
 root.add_child(game)
 var deadline := Time.get_ticks_msec() + 60000
 while not game.started and game.last_source_error.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
 if not game.started:
  push_error("Buzz diagnostic startup failed: " + game.last_source_error)
  await game.prepare_to_close()
  game.free()
  quit(1)
  return
 game.set_physics_process(false)
 game.ring_field.set_physics_process(false)
 game.ball.freeze = true
 game.controls.virtual_enabled = true
 game.presentation.set_camera_follow(false)
 game.buddies.choose("dark_chao")
 game.scorecraft.award_bonuses = game.buddies.modifiers()
 var sounds := preload("res://scripts/prototype/score_sounds.gd").new()
 sounds.game = game
 game.add_child(sounds)
 var enemies: RefCounted = game.active.runtime.mechanics.enemies
 enemies.profile_deaths = true
 enemies.death_profiled.connect(func(sample: Dictionary): cpu_samples.append(sample))
 # Let startup uploads/normal presentation settle; do not show the death flash.
 await create_timer(2.0).timeout
 var results: Array[Dictionary] = []
 results.append(await shoot("easy_top", Vector2(180, 330)))
 await create_timer(0.5).timeout
 results.append(await shoot("side_target", Vector2(420, 480)))
 var report := {"effect": Model.death_effect, "renderer": RenderingServer.get_current_rendering_method(),
  "device": RenderingServer.get_video_adapter_name(), "godot": Engine.get_version_info().string,
  "note": "CPU callbacks and wall-clock frame intervals; not isolated GPU timings. Driver caches are retained.", "samples": results}
 var directory := "user://diagnostics"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
 var path := directory.path_join("buzz-death-%s-%d.json" % [Model.death_effect, int(Time.get_unix_time_from_system())])
 var file := FileAccess.open(path, FileAccess.WRITE)
 if file != null:
  file.store_string(JSON.stringify(report, "  "))
  file.close()
  print("BUZZ_DEATH_REPORT | ", ProjectSettings.globalize_path(path))
 else: push_error("Cannot save Buzz diagnostic report: " + error_string(FileAccess.get_open_error()))
 var passed: bool = results.all(func(sample): return sample.killed and sample.cpu.size() == 1)
 await game.prepare_to_close()
 game.free()
 await process_frame
 quit(0 if passed and file != null else 1)
