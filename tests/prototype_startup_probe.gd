extends SceneTree
const Run = preload("res://scripts/prototype/zone_run.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
 var started_at := Time.get_ticks_msec()
 var game := Run.new()
 root.add_child(game)
 while not game.started and Time.get_ticks_msec() - started_at < 180000:
  if not game.last_source_error.is_empty() or (is_instance_valid(game.library) and not game.library.error.is_empty()): break
  await process_frame
 print("STARTUP_RESULT | ready=", game.started, " ms=", Time.get_ticks_msec() - started_at, " warm_frames=", game.library.last_warm_frames)
 var ready: bool = game.started
 await game.prepare_to_close()
 game.free()
 quit(0 if ready else 1)
